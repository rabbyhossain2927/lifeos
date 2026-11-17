<?php
// POST multipart "file" (JPG/PNG/WebP, up to 8 MB) -> {url}
// Photos for the profile, trips and memories. Each person gets a private folder with
// long random file names; PHP never runs inside the uploads folder.
declare(strict_types=1);
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
$uid = require_user();
register_shutdown_function('maybe_self_update');

$f = $_FILES['file'] ?? null;
if (!is_array($f) || ($f['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) reply(400, ['error' => 'No photo received.']);
if ((int) $f['size'] > 8 * 1024 * 1024) reply(413, ['error' => 'Photo is too big (max 8 MB).']);
$info = @getimagesize((string) $f['tmp_name']);
$types = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
$ext = $types[(string) ($info['mime'] ?? '')] ?? null;
if ($info === false || $ext === null) reply(415, ['error' => 'Only JPG, PNG or WebP photos.']);

$base = __DIR__ . '/uploads';
if (!is_dir($base) && !@mkdir($base, 0755, true)) reply(500, ['error' => 'Could not create the photo folder.']);
if (!is_file("$base/.htaccess")) {
    @file_put_contents("$base/.htaccess", "Options -Indexes\n<FilesMatch \"\\.(php|php\\d|phtml|phar|pl|py|cgi|sh|htaccess)$\">\n  Require all denied\n</FilesMatch>\n");
}
$folder = substr(hash('sha256', 'lifeos:' . $uid), 0, 24);
$dir = "$base/$folder";
if (!is_dir($dir) && !@mkdir($dir, 0755, true)) reply(500, ['error' => 'Could not create the photo folder.']);
$name = bin2hex(random_bytes(16)) . '.' . $ext;
if (!@move_uploaded_file((string) $f['tmp_name'], "$dir/$name")) reply(500, ['error' => 'Could not save the photo.']);

$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
$root = ($https ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . rtrim(str_replace('\\', '/', dirname((string) $_SERVER['SCRIPT_NAME'])), '/');
reply(200, ['url' => "$root/uploads/$folder/$name"]);
