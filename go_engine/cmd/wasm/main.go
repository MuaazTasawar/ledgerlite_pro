//go:build js && wasm

package main

import (
	"encoding/json"
	"syscall/js"
	"time"

	"github.com/MuaazTasawar/ledgerlite_pro/go_engine/crypto"
	"github.com/MuaazTasawar/ledgerlite_pro/go_engine/mobile"
)

// This file compiles the Go crypto engine to WebAssembly.
// It exposes the same functions as the gomobile bridge,
// but as JavaScript-callable functions via syscall/js.
//
// Build command (from go_engine/ directory):
//   GOOS=js GOARCH=wasm go build -o ../flutter_app/assets/go_engine.wasm ./cmd/wasm/
//
// On Windows (PowerShell):
//   $env:GOOS="js"; $env:GOARCH="wasm"; go build -o ..\flutter_app\assets\go_engine.wasm .\cmd\wasm\
//
// The generated go_engine.wasm is loaded by flutter_app/web/index.html
// and called from flutter_app/lib/core/bridge/wasm_bridge.dart

func main() {
	// Register all Go functions as JavaScript globals
	js.Global().Set("goGenerateKeyPair", jsGenerateKeyPair())
	js.Global().Set("goVerifyChain", jsVerifyChain())
	js.Global().Set("goVerifySingleEntry", jsVerifySingleEntry())
	js.Global().Set("goMerchantSignEntry", jsMerchantSignEntry())
	js.Global().Set("goCustomerSignEntry", jsCustomerSignEntry())
	js.Global().Set("goComputeMerkleRoot", jsComputeMerkleRoot())
	js.Global().Set("goGetHeadHash", jsGetHeadHash())
	js.Global().Set("goHashEntryPayload", jsHashEntryPayload())
	js.Global().Set("goVerifyReceiptJSON", jsVerifyReceiptJSON())

	// Keep the Go runtime alive — WASM needs to stay running
	select {}
}

// ─────────────────────────────────────────────────────────────
// JS wrapper helpers
// ─────────────────────────────────────────────────────────────

// jsResult wraps a Go result into a JS-friendly object:
// { ok: true, value: "..." } or { ok: false, error: "..." }
func jsResult(value string, err error) js.Value {
	if err != nil {
		return js.ValueOf(map[string]interface{}{
			"ok":    false,
			"error": err.Error(),
		})
	}
	return js.ValueOf(map[string]interface{}{
		"ok":    true,
		"value": value,
	})
}

// ─────────────────────────────────────────────────────────────
// Key Management
// ─────────────────────────────────────────────────────────────

func jsGenerateKeyPair() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		result, err := mobile.GenerateKeyPair()
		return jsResult(result, err)
	})
}

// ─────────────────────────────────────────────────────────────
// Signing
// ─────────────────────────────────────────────────────────────

func jsMerchantSignEntry() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 3 {
			return jsResult("", js.Error{Value: js.ValueOf("merchantSignEntry requires 3 args")})
		}
		payloadJSON := args[0].String()
		privateKeyHex := args[1].String()
		prevChainHash := args[2].String()
		result, err := mobile.MerchantSignEntry(payloadJSON, privateKeyHex, prevChainHash)
		return jsResult(result, err)
	})
}

func jsCustomerSignEntry() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 2 {
			return jsResult("", js.Error{Value: js.ValueOf("customerSignEntry requires 2 args")})
		}
		signedEntryJSON := args[0].String()
		customerPrivKey := args[1].String()
		result, err := mobile.CustomerSignEntry(signedEntryJSON, customerPrivKey)
		return jsResult(result, err)
	})
}

// ─────────────────────────────────────────────────────────────
// Verification
// ─────────────────────────────────────────────────────────────

func jsVerifyChain() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("verifyChain requires 1 arg")})
		}
		entriesJSON := args[0].String()

		// Deserialize entries
		var entries []crypto.SignedEntry
		if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
			return jsResult("", err)
		}

		// Verify with timing
		start := time.Now()
		result := crypto.VerifyChain(entries)
		result.DurationMs = time.Since(start).Milliseconds()

		data, err := json.Marshal(result)
		if err != nil {
			return jsResult("", err)
		}
		return jsResult(string(data), nil)
	})
}

func jsVerifySingleEntry() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("verifySingleEntry requires 1 arg")})
		}
		result, err := mobile.VerifySingleEntry(args[0].String())
		return jsResult(result, err)
	})
}

// jsVerifyReceiptJSON is the main entry point for the web verifier.
// It accepts the full receipt JSON exported by the app and returns
// a detailed verification result.
func jsVerifyReceiptJSON() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("verifyReceiptJSON requires 1 arg")})
		}

		receiptJSON := args[0].String()

		// Parse the receipt JSON
		var receipt map[string]interface{}
		if err := json.Unmarshal([]byte(receiptJSON), &receipt); err != nil {
			return jsResult("", err)
		}

		// Determine if this is a single entry or full chain receipt
		if _, hasEntries := receipt["entries"]; hasEntries {
			// Full chain export — verify all entries
			entriesRaw, _ := json.Marshal(receipt["entries"])
			result, err := mobile.VerifyChain(string(entriesRaw))
			return jsResult(result, err)
		}

		if entry, hasEntry := receipt["entry"]; hasEntry {
			// Single entry receipt
			entryRaw, _ := json.Marshal(entry)
			result, err := mobile.VerifySingleEntry(string(entryRaw))
			return jsResult(result, err)
		}

		return jsResult("", json.Unmarshal([]byte(`{}`), &struct{}{}))
	})
}

// ─────────────────────────────────────────────────────────────
// Merkle Utilities
// ─────────────────────────────────────────────────────────────

func jsComputeMerkleRoot() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("computeMerkleRoot requires 1 arg")})
		}
		result, err := mobile.ComputeMerkleRoot(args[0].String())
		return jsResult(result, err)
	})
}

func jsGetHeadHash() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("getHeadHash requires 1 arg")})
		}
		result, err := mobile.GetHeadHash(args[0].String())
		return jsResult(result, err)
	})
}

func jsHashEntryPayload() js.Func {
	return js.FuncOf(func(this js.Value, args []js.Value) interface{} {
		if len(args) < 1 {
			return jsResult("", js.Error{Value: js.ValueOf("hashEntryPayload requires 1 arg")})
		}
		result, err := mobile.HashEntryPayload(args[0].String())
		return jsResult(result, err)
	})
}
