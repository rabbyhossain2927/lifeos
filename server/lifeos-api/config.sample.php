<?php
// Copy this file to config.php and fill it in. See docs/SETUP-GUIDE.md, Part 2.
return [
    // cPanel > MySQL Databases (use the FULL names cPanel shows)
    'db_host' => 'localhost',
    'db_name' => 'cpaneluser_lifeos',
    'db_user' => 'cpaneluser_lifeos',
    'db_pass' => 'PUT-THE-DATABASE-PASSWORD-HERE',

    // Firebase console > Project settings > General > Project ID
    'firebase_project_id' => 'your-firebase-project-id',

    // Safety limits
    'max_changes_per_request' => 500,
    'max_doc_bytes' => 1000000, // 1 MB per item
    'page_size' => 1000,

    // Keep this server folder updated from GitHub automatically
    'auto_update' => true,
    'update_repo' => 'rabbyhossain2927/lifeos',
];
