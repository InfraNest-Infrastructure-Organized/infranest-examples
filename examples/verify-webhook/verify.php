<?php

// Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature
//
//   php verify.php BODY_FILE TIMESTAMP SIGNATURE     (TIMESTAMP '' when the header was absent)
//   INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_…)
// Exits 0 for a genuine delivery, 1 otherwise. In a receiver:
//   verifyInfraNest(file_get_contents('php://input'), $_SERVER['HTTP_X_INFRANEST_TIMESTAMP'] ?? null,
//                   $_SERVER['HTTP_X_INFRANEST_SIGNATURE'] ?? null, getenv('INFRANEST_WEBHOOK_SECRET'));

function verifyInfraNest(string $rawBody, ?string $timestamp, ?string $signature, string $secret, int $tolerance = 300): bool
{
    $signed = $rawBody;
    if ($timestamp !== null) {
        if (! ctype_digit($timestamp) || abs(time() - (int) $timestamp) > $tolerance) {
            return false;
        }
        $signed = $timestamp.'.'.$rawBody;
    }

    return hash_equals('sha256='.hash_hmac('sha256', $signed, $secret), (string) $signature);
}

if (PHP_SAPI === 'cli' && realpath($argv[0]) === __FILE__) {
    [, $bodyFile, $timestamp, $signature] = $argv;
    exit(verifyInfraNest((string) file_get_contents($bodyFile), $timestamp === '' ? null : $timestamp, $signature, (string) getenv('INFRANEST_WEBHOOK_SECRET')) ? 0 : 1);
}
