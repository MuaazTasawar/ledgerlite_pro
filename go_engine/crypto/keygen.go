package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"errors"
)

// KeyPair holds a merchant's Ed25519 public/private key pair as hex strings.
// The private key never leaves the device — it is stored in Flutter Secure Storage.
// The public key is shared freely for signature verification.
type KeyPair struct {
	PublicKey  string // hex-encoded 32-byte Ed25519 public key
	PrivateKey string // hex-encoded 64-byte Ed25519 private key (seed + public)
}

// GenerateKeyPair creates a new random Ed25519 key pair.
// Called once on first app launch; result stored in Flutter Secure Storage.
func GenerateKeyPair() (*KeyPair, error) {
	pubBytes, privBytes, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, errors.New("keygen: failed to generate Ed25519 key pair: " + err.Error())
	}

	return &KeyPair{
		PublicKey:  hex.EncodeToString(pubBytes),
		PrivateKey: hex.EncodeToString(privBytes),
	}, nil
}

// PublicKeyFromPrivate derives the public key from a hex-encoded private key.
// Used when the app needs to display or share the merchant's public key
// without re-generating a new pair.
func PublicKeyFromPrivate(privateKeyHex string) (string, error) {
	privBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return "", errors.New("keygen: invalid private key hex: " + err.Error())
	}
	if len(privBytes) != ed25519.PrivateKeySize {
		return "", errors.New("keygen: private key must be 64 bytes")
	}

	privKey := ed25519.PrivateKey(privBytes)
	pubKey := privKey.Public().(ed25519.PublicKey)
	return hex.EncodeToString(pubKey), nil
}

// ValidatePublicKey checks whether a hex string is a valid Ed25519 public key.
// Used when a customer's public key is received via QR scan.
func ValidatePublicKey(publicKeyHex string) error {
	pubBytes, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return errors.New("keygen: invalid public key hex: " + err.Error())
	}
	if len(pubBytes) != ed25519.PublicKeySize {
		return errors.New("keygen: public key must be 32 bytes")
	}
	return nil
}