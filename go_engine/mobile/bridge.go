package mobile

// This package is the gomobile-exported surface of the Go crypto engine.
// ONLY types and functions in this package are visible to Dart/Flutter.
// Rules for gomobile compatibility:
//   - Functions may only accept/return: string, bool, int, float64, []byte, error
//   - No maps, no slices of structs, no generics
//   - Structs must embed gomobile.Object or use only supported field types
//   - Complex data is passed as JSON strings across the bridge

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/MuaazTasawar/ledgerlite_pro/go_engine/crypto"
)

// ────────────────────────────────────────────────────────────
// SECTION 1 — Key Management
// ────────────────────────────────────────────────────────────

// GenerateKeyPair generates a new Ed25519 key pair.
// Returns a JSON string: {"public_key": "...", "private_key": "..."}
// Called once on first app launch. Store private_key in flutter_secure_storage.
func GenerateKeyPair() (string, error) {
	kp, err := crypto.GenerateKeyPair()
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}
	data, err := json.Marshal(map[string]string{
		"public_key":  kp.PublicKey,
		"private_key": kp.PrivateKey,
	})
	if err != nil {
		return "", fmt.Errorf("bridge: failed to serialize key pair: %w", err)
	}
	return string(data), nil
}

// PublicKeyFromPrivate derives the public key hex from a private key hex.
// Returns the public key as a plain hex string.
func PublicKeyFromPrivate(privateKeyHex string) (string, error) {
	pub, err := crypto.PublicKeyFromPrivate(privateKeyHex)
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}
	return pub, nil
}

// ValidatePublicKey returns nil if the hex string is a valid Ed25519 public key.
// Returns an error string if invalid.
func ValidatePublicKey(publicKeyHex string) error {
	return crypto.ValidatePublicKey(publicKeyHex)
}

// ────────────────────────────────────────────────────────────
// SECTION 2 — Entry Signing
// ────────────────────────────────────────────────────────────

// MerchantSignEntry creates and merchant-signs a new ledger entry.
//
// Parameters:
//   - entryPayloadJSON: JSON of crypto.EntryPayload (without timestamp/merchant_pub — filled here)
//   - privateKeyHex:    merchant's Ed25519 private key (hex)
//   - prevChainHash:    ChainHash of last entry, or "GENESIS" for first entry
//
// Returns JSON of crypto.SignedEntry on success.
func MerchantSignEntry(entryPayloadJSON string, privateKeyHex string, prevChainHash string) (string, error) {
	var payload crypto.EntryPayload
	if err := json.Unmarshal([]byte(entryPayloadJSON), &payload); err != nil {
		return "", fmt.Errorf("bridge: invalid entry payload JSON: %w", err)
	}

	signed, err := crypto.MerchantSign(payload, privateKeyHex, prevChainHash)
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}

	data, err := json.Marshal(signed)
	if err != nil {
		return "", fmt.Errorf("bridge: failed to serialize signed entry: %w", err)
	}
	return string(data), nil
}

// CustomerSignEntry adds the customer's signature to an existing SignedEntry JSON.
//
// Parameters:
//   - signedEntryJSON:      JSON of crypto.SignedEntry (from MerchantSignEntry)
//   - customerPrivateKeyHex: customer's Ed25519 private key (hex)
//
// Returns updated SignedEntry JSON with customer_sig filled.
func CustomerSignEntry(signedEntryJSON string, customerPrivateKeyHex string) (string, error) {
	var entry crypto.SignedEntry
	if err := json.Unmarshal([]byte(signedEntryJSON), &entry); err != nil {
		return "", fmt.Errorf("bridge: invalid signed entry JSON: %w", err)
	}

	updated, err := crypto.CustomerSign(&entry, customerPrivateKeyHex)
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}

	data, err := json.Marshal(updated)
	if err != nil {
		return "", fmt.Errorf("bridge: failed to serialize updated entry: %w", err)
	}
	return string(data), nil
}

// ────────────────────────────────────────────────────────────
// SECTION 3 — Chain Verification
// ────────────────────────────────────────────────────────────

// VerifyChain verifies the full ledger chain from a JSON array of SignedEntries.
//
// Parameters:
//   - entriesJSON: JSON array of crypto.SignedEntry objects
//
// Returns JSON of crypto.VerificationResult.
func VerifyChain(entriesJSON string) (string, error) {
	var entries []crypto.SignedEntry
	if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
		return "", fmt.Errorf("bridge: invalid entries JSON: %w", err)
	}

	start := time.Now()
	result := crypto.VerifyChain(entries)
	result.DurationMs = time.Since(start).Milliseconds()

	data, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("bridge: failed to serialize verification result: %w", err)
	}
	return string(data), nil
}

// VerifySingleEntry verifies one SignedEntry JSON for internal consistency.
// Returns "ok" on success, or an error message string.
func VerifySingleEntry(signedEntryJSON string) (string, error) {
	var entry crypto.SignedEntry
	if err := json.Unmarshal([]byte(signedEntryJSON), &entry); err != nil {
		return "", fmt.Errorf("bridge: invalid signed entry JSON: %w", err)
	}

	if err := crypto.VerifyEntry(entry); err != nil {
		return "", err
	}
	return "ok", nil
}

// VerifyCustomerSig verifies the customer signature on a SignedEntry.
//
// Parameters:
//   - signedEntryJSON:    JSON of crypto.SignedEntry
//   - customerPubKeyHex: customer's Ed25519 public key (hex)
//
// Returns "ok" or error.
func VerifyCustomerSig(signedEntryJSON string, customerPubKeyHex string) (string, error) {
	var entry crypto.SignedEntry
	if err := json.Unmarshal([]byte(signedEntryJSON), &entry); err != nil {
		return "", fmt.Errorf("bridge: invalid signed entry JSON: %w", err)
	}

	if err := crypto.VerifyCustomerSignature(entry, customerPubKeyHex); err != nil {
		return "", err
	}
	return "ok", nil
}

// ────────────────────────────────────────────────────────────
// SECTION 4 — Merkle Utilities
// ────────────────────────────────────────────────────────────

// ComputeMerkleRoot computes the Merkle root from a JSON array of SignedEntries.
// Returns the root hash hex string.
// This is the value that gets sent to OpenTimestamps for anchoring.
func ComputeMerkleRoot(entriesJSON string) (string, error) {
	var entries []crypto.SignedEntry
	if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
		return "", fmt.Errorf("bridge: invalid entries JSON: %w", err)
	}

	chain := &crypto.Chain{Entries: entries}
	root, err := chain.MerkleRoot()
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}
	return root, nil
}

// GetHeadHash returns the ChainHash of the last entry in a JSON entries array.
// Returns "GENESIS" if the array is empty.
// Dart calls this before creating a new entry to get the correct prevHash.
func GetHeadHash(entriesJSON string) (string, error) {
	var entries []crypto.SignedEntry
	if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
		return "", fmt.Errorf("bridge: invalid entries JSON: %w", err)
	}

	chain := &crypto.Chain{Entries: entries}
	return chain.HeadHash(), nil
}

// HashEntryPayload computes the SHA-256 hash of an EntryPayload JSON.
// Used by Dart to display the live hash badge as the user types.
func HashEntryPayload(entryPayloadJSON string) (string, error) {
	var payload crypto.EntryPayload
	if err := json.Unmarshal([]byte(entryPayloadJSON), &payload); err != nil {
		return "", fmt.Errorf("bridge: invalid payload JSON: %w", err)
	}

	hash, err := crypto.HashPayload(payload)
	if err != nil {
		return "", fmt.Errorf("bridge: %w", err)
	}
	return hash, nil
}
