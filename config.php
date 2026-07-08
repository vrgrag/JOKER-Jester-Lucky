<?php
/**
 * Jester Lucky — Gray Flow Gateway
 * ─────────────────────────────────
 * Deploy this file to: https://jesterlucky.com/config.php
 *
 * Request  POST application/json
 * Response application/json  { ok, url, expires, message }
 *
 * Fields the app sends (use whichever you need for filtering):
 *   bundle_id        — "com.joker.jesterlucky"
 *   os               — "Android"
 *   af_status        — "Non-organic" | "Organic" (AppsFlyer)
 *   af_channel       — traffic channel
 *   campaign         — campaign name
 *   media_source     — media source
 *   af_id            — AppsFlyer device UID
 *   push_token       — FCM token (present if permission granted)
 *   firebase_project_id — messaging sender id
 *   locale           — device locale, e.g. "en_US"
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ── Read body ────────────────────────────────────────────────────────────────
$raw  = file_get_contents('php://input');
$body = json_decode($raw, true) ?: [];

$bundle = $body['bundle_id'] ?? '';
$os     = $body['os']        ?? '';
$status = $body['af_status'] ?? '';

// ── Validate bundle ──────────────────────────────────────────────────────────
if ($bundle !== 'com.joker.jesterlucky' || $os !== 'Android') {
    echo json_encode(['ok' => false, 'message' => 'invalid-bundle']);
    exit;
}

// ── Block organic (no paid attribution) ─────────────────────────────────────
// Remove or adjust this block if you want ALL users to see the gray content.
if ($status === 'Organic' || $status === '') {
    echo json_encode(['ok' => false, 'message' => 'organic']);
    exit;
}

// ── Return gray URL ──────────────────────────────────────────────────────────
// TODO: replace with your actual affiliate / casino URL
$gray_url = 'https://YOUR_CASINO_AFFILIATE_URL_HERE';

$expires = time() + 30 * 24 * 60 * 60; // cache for 30 days

echo json_encode([
    'ok'      => true,
    'url'     => $gray_url,
    'expires' => $expires,
    'message' => 'granted',
]);
