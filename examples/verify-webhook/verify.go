// Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature
//
//	go run verify.go BODY_FILE TIMESTAMP SIGNATURE     (TIMESTAMP "" when the header was absent)
//	INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_…)
//
// Exits 0 for a genuine delivery, 1 otherwise. Use VerifyInfraNest in your own receiver.
package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"strconv"
	"time"
)

// VerifyInfraNest checks a delivery. timestamp is "" when the header is absent; rawBody is the body as received.
func VerifyInfraNest(rawBody []byte, timestamp, signature, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	if timestamp != "" {
		ts, err := strconv.ParseInt(timestamp, 10, 64)
		if err != nil {
			return false
		}
		if age := time.Now().Unix() - ts; age > 300 || age < -300 {
			return false
		}
		mac.Write([]byte(timestamp + "."))
	}
	mac.Write(rawBody)
	expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signature))
}

func main() {
	body, err := os.ReadFile(os.Args[1])
	if err != nil || !VerifyInfraNest(body, os.Args[2], os.Args[3], os.Getenv("INFRANEST_WEBHOOK_SECRET")) {
		os.Exit(1)
	}
}
