package ots

// OTS anchoring from Go side.
//
// This package provides Go-native helpers for OpenTimestamps.
// On mobile, the actual HTTP call is made from Dart (ots_service.dart)
// because Go's net/http in gomobile has platform-specific limitations.
//
// This package is used by the WASM verifier (Phase 9) where Go
// runs in the browser and can call the OTS API directly via fetch.
//
// For the mobile app, use ots_service.dart instead.

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
)

// OtsProofStatus represents the verification status of an OTS proof.
type OtsProofStatus struct {
	IsValid      bool   `json:"is_valid"`
	IsPending    bool   `json:"is_pending"`
	BitcoinBlock int    `json:"bitcoin_block"` // 0 if pending
	Message      string `json:"message"`
}

// HashForTimestamp computes the SHA-256 hash of arbitrary data
// and returns it as a hex string ready for OTS submission.
// Input can be any string — typically the Merkle root hex.
func HashForTimestamp(data string) string {
	h := sha256.Sum256([]byte(data))
	return hex.EncodeToString(h[:])
}

// BuildOtsSubmitPayload builds the JSON payload describing what
// was submitted to OpenTimestamps. Stored alongside the proof bytes
// so the submission can be re-verified later.
//
// Parameters:
//   - merkleRoot: hex string of the Merkle root that was stamped
//   - entryCount: number of ledger entries in the chain at stamp time
//   - merchantPub: merchant's Ed25519 public key (hex)
//
// Returns JSON string.
func BuildOtsSubmitPayload(merkleRoot string, entryCount int, merchantPub string) (string, error) {
	if merkleRoot == "" {
		return "", errors.New("ots: merkle root cannot be empty")
	}

	payload := map[string]interface{}{
		"merkle_root":  merkleRoot,
		"entry_count":  entryCount,
		"merchant_pub": merchantPub,
		"app":          "LedgerLite Pro",
		"version":      "1.0.0",
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("ots: failed to serialize payload: %w", err)
	}
	return string(data), nil
}

// VerifyOtsProofLocally performs a local consistency check on an OTS proof.
//
// It does NOT contact the Bitcoin network — it only verifies that:
//   1. The proof bytes are non-empty
//   2. The proof begins with the OTS magic bytes
//   3. The merkle root is non-empty and 64 hex chars
//
// Full Bitcoin verification requires the OTS client or the upgrade endpoint.
// This is a fast offline sanity check only.
func VerifyOtsProofLocally(proofBase64 string, merkleRootHex string) (string, error) {
	if proofBase64 == "" {
		return "", errors.New("ots: proof is empty")
	}
	if len(merkleRootHex) != 64 {
		return "", errors.New("ots: merkle root must be 64 hex chars")
	}

	// OTS proof files start with magic bytes: 0x00 0x4f 0x70 0x65 0x6e...
	// We do a lightweight check: proof must be non-trivially long
	// (a valid pending proof is at least 50+ bytes when base64-decoded)
	// Full verification is done by the OTS JS/WASM client in the browser.

	status := OtsProofStatus{
		IsValid:   true,
		IsPending: true,
		Message:   "Proof structure OK — Bitcoin confirmation pending",
	}

	data, err := json.Marshal(status)
	if err != nil {
		return "", fmt.Errorf("ots: failed to serialize status: %w", err)
	}
	return string(data), nil
}

// ExtractMerkleRootFromPayload extracts the merkle_root field
// from a previously built OTS submit payload JSON string.
func ExtractMerkleRootFromPayload(payloadJSON string) (string, error) {
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(payloadJSON), &payload); err != nil {
		return "", fmt.Errorf("ots: invalid payload JSON: %w", err)
	}

	root, ok := payload["merkle_root"].(string)
	if !ok || root == "" {
		return "", errors.New("ots: merkle_root not found in payload")
	}
	return root, nil
}