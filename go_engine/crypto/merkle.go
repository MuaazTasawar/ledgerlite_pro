package crypto

import (
	"errors"
)

// Chain represents an ordered sequence of SignedEntries.
// It is the in-memory representation of the full ledger for verification.
type Chain struct {
	Entries []SignedEntry
}

// NewChain creates an empty chain.
func NewChain() *Chain {
	return &Chain{Entries: []SignedEntry{}}
}

// Append adds a new SignedEntry to the chain.
// It validates that the entry's PrevHash correctly references the last entry's ChainHash.
// Returns an error if the chain link is broken before appending.
func (c *Chain) Append(entry SignedEntry) error {
	if len(c.Entries) == 0 {
		// First entry — PrevHash must be the genesis sentinel
		if entry.PrevHash != GenesisHash {
			return errors.New("merkle: first entry must reference GENESIS hash")
		}
	} else {
		lastEntry := c.Entries[len(c.Entries)-1]
		if entry.PrevHash != lastEntry.ChainHash {
			return errors.New("merkle: chain link broken — PrevHash does not match last ChainHash")
		}
	}
	c.Entries = append(c.Entries, entry)
	return nil
}

// GenesisHash is the sentinel string used as PrevHash for the very first entry.
// Using a fixed known string rather than an empty string makes genesis detection explicit.
const GenesisHash = "GENESIS"

// MerkleRoot computes the root hash of all ChainHash values in the chain.
// This is a simple binary Merkle tree — pairs of hashes are combined with SHA-256
// until a single root hash remains. Odd counts duplicate the last node.
// The root hash is what gets anchored to OpenTimestamps.
func (c *Chain) MerkleRoot() (string, error) {
	if len(c.Entries) == 0 {
		return "", errors.New("merkle: cannot compute root of empty chain")
	}

	// Collect all chain hashes as the leaf layer
	layer := make([]string, len(c.Entries))
	for i, e := range c.Entries {
		layer[i] = e.ChainHash
	}

	// Iteratively combine pairs until one root remains
	for len(layer) > 1 {
		var next []string
		for i := 0; i < len(layer); i += 2 {
			left := layer[i]
			right := left // duplicate last node if odd count
			if i+1 < len(layer) {
				right = layer[i+1]
			}
			combined := ComputeChainHash(left, right)
			next = append(next, combined)
		}
		layer = next
	}

	return layer[0], nil
}

// HeadHash returns the ChainHash of the most recent entry.
// This is what new entries use as their PrevHash.
// Returns GenesisHash if the chain is empty.
func (c *Chain) HeadHash() string {
	if len(c.Entries) == 0 {
		return GenesisHash
	}
	return c.Entries[len(c.Entries)-1].ChainHash
}

// Len returns the number of entries in the chain.
func (c *Chain) Len() int {
	return len(c.Entries)
}
