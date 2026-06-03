package crypto

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// EntryPayload is the canonical data structure for a single ledger entry.
// This exact struct is serialized to JSON before signing — both merchant
// and customer sign the same canonical JSON bytes.
type EntryPayload struct {
	ID           string  `json:"id"`            // UUID v4
	CustomerName string  `json:"customer_name"` // Name of the customer
	Description  string  `json:"description"`   // What was sold / nature of credit
	Amount       float64 `json:"amount"`        // Amount in PKR (or local currency)
	Currency     string  `json:"currency"`      // e.g. "PKR"
	Type         string  `json:"type"`          // "credit" (udhaar) or "payment"
	Timestamp    int64   `json:"timestamp"`     // Unix timestamp (seconds)
	MerchantPub  string  `json:"merchant_pub"`  // Merchant's Ed25519 public key (hex)
}

// SignedEntry is an EntryPayload plus both parties' signatures and the entry hash.
type SignedEntry struct {
	Payload           EntryPayload `json:"payload"`
	MerchantSignature string       `json:"merchant_sig"` // hex Ed25519 signature by merchant
	CustomerSignature string       `json:"customer_sig"` // hex Ed25519 signature by customer (empty until customer signs)
	EntryHash         string       `json:"entry_hash"`   // SHA-256 of canonical JSON payload
	PrevHash          string       `json:"prev_hash"`    // SHA-256 of previous entry in chain (or "GENESIS")
	ChainHash         string       `json:"chain_hash"`   // SHA-256(entry_hash + prev_hash) — the link
}

// CanonicalJSON serializes an EntryPayload to deterministic JSON bytes.
// Determinism is critical — both parties must sign exactly the same bytes.
func CanonicalJSON(payload EntryPayload) ([]byte, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("sign: failed to serialize payload: %w", err)
	}
	return data, nil
}

// HashPayload computes the SHA-256 hash of the canonical JSON of an EntryPayload.
func HashPayload(payload EntryPayload) (string, error) {
	data, err := CanonicalJSON(payload)
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:]), nil
}

// ComputeChainHash computes SHA-256(entryHash + prevHash).
// This is the actual Merkle link — it binds each entry to the one before it.
func ComputeChainHash(entryHash, prevHash string) string {
	combined := entryHash + prevHash
	h := sha256.Sum256([]byte(combined))
	return hex.EncodeToString(h[:])
}

// MerchantSign creates a new SignedEntry signed by the merchant.
// The customer signature field is left empty — it will be filled during QR handshake.
// prevHash is the chain_hash of the last entry, or "GENESIS" for the first entry.
func MerchantSign(payload EntryPayload, privateKeyHex string, prevHash string) (*SignedEntry, error) {
	// Validate private key
	privBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return nil, errors.New("sign: invalid private key hex")
	}
	if len(privBytes) != ed25519.PrivateKeySize {
		return nil, errors.New("sign: private key must be 64 bytes")
	}

	// Stamp timestamp
	payload.Timestamp = time.Now().Unix()

	// Derive and embed merchant public key
	privKey := ed25519.PrivateKey(privBytes)
	pubKey := privKey.Public().(ed25519.PublicKey)
	payload.MerchantPub = hex.EncodeToString(pubKey)

	// Compute entry hash from canonical JSON
	entryHash, err := HashPayload(payload)
	if err != nil {
		return nil, err
	}

	// Merchant signs the canonical JSON bytes
	data, err := CanonicalJSON(payload)
	if err != nil {
		return nil, err
	}
	sigBytes := ed25519.Sign(privKey, data)

	// Compute chain hash
	chainHash := ComputeChainHash(entryHash, prevHash)

	return &SignedEntry{
		Payload:           payload,
		MerchantSignature: hex.EncodeToString(sigBytes),
		CustomerSignature: "", // filled during QR handshake
		EntryHash:         entryHash,
		PrevHash:          prevHash,
		ChainHash:         chainHash,
	}, nil
}

// CustomerSign adds the customer's Ed25519 signature to an existing SignedEntry.
// The customer signs the same canonical JSON payload bytes that the merchant signed.
// Called on the customer's phone during the QR handshake (Phase 6).
func CustomerSign(entry *SignedEntry, customerPrivateKeyHex string) (*SignedEntry, error) {
	if entry.MerchantSignature == "" {
		return nil, errors.New("sign: merchant must sign before customer")
	}

	privBytes, err := hex.DecodeString(customerPrivateKeyHex)
	if err != nil {
		return nil, errors.New("sign: invalid customer private key hex")
	}
	if len(privBytes) != ed25519.PrivateKeySize {
		return nil, errors.New("sign: customer private key must be 64 bytes")
	}

	privKey := ed25519.PrivateKey(privBytes)

	data, err := CanonicalJSON(entry.Payload)
	if err != nil {
		return nil, err
	}

	sigBytes := ed25519.Sign(privKey, data)
	entry.CustomerSignature = hex.EncodeToString(sigBytes)
	return entry, nil
}
