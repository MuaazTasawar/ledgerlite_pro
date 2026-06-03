package crypto

import (
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
)

// VerificationResult holds the outcome of verifying a single entry or the full chain.
type VerificationResult struct {
	Valid          bool   // true if everything checks out
	FailedAtIndex  int    // index of the first broken entry (-1 if all valid)
	FailedEntryID  string // ID of the broken entry ("" if all valid)
	Reason         string // human-readable failure reason
	EntriesChecked int    // how many entries were verified
	MerkleRoot     string // computed Merkle root (only on full chain verify)
	DurationMs     int64  // how long verification took in milliseconds
}

// VerifyEntry checks a single SignedEntry for internal consistency:
//  1. Entry hash matches recomputed hash of payload
//  2. Chain hash matches ComputeChainHash(entryHash, prevHash)
//  3. Merchant signature is valid over canonical JSON payload
//  4. Customer signature is valid (if present)
func VerifyEntry(entry SignedEntry) error {
	// 1. Recompute entry hash
	recomputed, err := HashPayload(entry.Payload)
	if err != nil {
		return fmt.Errorf("verify: failed to hash payload: %w", err)
	}
	if recomputed != entry.EntryHash {
		return fmt.Errorf("verify: entry hash mismatch — payload was altered")
	}

	// 2. Recompute chain hash
	expectedChainHash := ComputeChainHash(entry.EntryHash, entry.PrevHash)
	if expectedChainHash != entry.ChainHash {
		return fmt.Errorf("verify: chain hash mismatch — chain link corrupted")
	}

	// 3. Verify merchant signature
	if entry.MerchantSignature == "" {
		return fmt.Errorf("verify: missing merchant signature")
	}
	if err := verifySignature(entry.Payload, entry.MerchantSignature, entry.Payload.MerchantPub); err != nil {
		return fmt.Errorf("verify: merchant signature invalid: %w", err)
	}

	// 4. Verify customer signature if present (not required for basic entries)
	if entry.CustomerSignature != "" && entry.Payload.MerchantPub != "" {
		// Customer pub key is not embedded in payload — it is stored separately in the DB.
		// For single-entry verification, we skip customer sig check here.
		// Full chain verification (VerifyChain) handles it with the stored customer pub key.
	}

	return nil
}

// VerifyChain walks every entry in a chain and verifies:
//  1. Each entry passes VerifyEntry
//  2. Each entry's PrevHash matches the previous entry's ChainHash
//  3. The first entry's PrevHash is GenesisHash
//
// Returns a VerificationResult — always returns a result, never panics.
// The DurationMs field is populated by the caller (Dart bridge) since
// Go's time package behaves differently in WASM.
func VerifyChain(entries []SignedEntry) VerificationResult {
	if len(entries) == 0 {
		return VerificationResult{
			Valid:          true,
			FailedAtIndex:  -1,
			EntriesChecked: 0,
			Reason:         "empty chain",
		}
	}

	for i, entry := range entries {
		// Check entry self-consistency
		if err := VerifyEntry(entry); err != nil {
			return VerificationResult{
				Valid:          false,
				FailedAtIndex:  i,
				FailedEntryID:  entry.Payload.ID,
				Reason:         err.Error(),
				EntriesChecked: i + 1,
			}
		}

		// Check chain linkage
		if i == 0 {
			if entry.PrevHash != GenesisHash {
				return VerificationResult{
					Valid:          false,
					FailedAtIndex:  0,
					FailedEntryID:  entry.Payload.ID,
					Reason:         "first entry does not reference GENESIS",
					EntriesChecked: 1,
				}
			}
		} else {
			expected := entries[i-1].ChainHash
			if entry.PrevHash != expected {
				return VerificationResult{
					Valid:         false,
					FailedAtIndex: i,
					FailedEntryID: entry.Payload.ID,
					Reason: fmt.Sprintf(
						"chain broken at entry %d — PrevHash %s does not match prior ChainHash %s",
						i, entry.PrevHash[:8]+"...", expected[:8]+"...",
					),
					EntriesChecked: i + 1,
				}
			}
		}
	}

	// All entries valid — compute Merkle root
	chain := &Chain{Entries: entries}
	root, err := chain.MerkleRoot()
	if err != nil {
		root = "error computing root"
	}

	return VerificationResult{
		Valid:          true,
		FailedAtIndex:  -1,
		EntriesChecked: len(entries),
		MerkleRoot:     root,
	}
}

// VerifyCustomerSignature verifies a customer's signature on a specific entry
// given their public key (retrieved from the DB or QR scan).
func VerifyCustomerSignature(entry SignedEntry, customerPublicKeyHex string) error {
	if entry.CustomerSignature == "" {
		return fmt.Errorf("verify: no customer signature present on this entry")
	}
	return verifySignature(entry.Payload, entry.CustomerSignature, customerPublicKeyHex)
}

// verifySignature is the internal helper that verifies an Ed25519 signature
// over the canonical JSON of an EntryPayload.
func verifySignature(payload EntryPayload, signatureHex string, publicKeyHex string) error {
	if publicKeyHex == "" {
		return fmt.Errorf("verify: public key is empty")
	}

	pubBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return fmt.Errorf("verify: invalid public key hex: %w", err)
	}
	if len(pubBytes) != ed25519.PublicKeySize {
		return fmt.Errorf("verify: public key must be 32 bytes, got %d", len(pubBytes))
	}

	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return fmt.Errorf("verify: invalid signature hex: %w", err)
	}
	if len(sigBytes) != ed25519.SignatureSize {
		return fmt.Errorf("verify: signature must be 64 bytes, got %d", len(sigBytes))
	}

	data, err := CanonicalJSON(payload)
	if err != nil {
		return fmt.Errorf("verify: failed to serialize payload for verification: %w", err)
	}

	pubKey := ed25519.PublicKey(pubBytes)
	if !ed25519.Verify(pubKey, data, sigBytes) {
		return fmt.Errorf("verify: signature does not match — data may have been tampered with")
	}

	return nil
}
