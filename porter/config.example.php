<?php
// nitro-porter configuration — XenForo source, Flarum target.
//
// Copy this file to config.php and fill in the real database passwords.
// config.php is gitignored so your credentials never get committed.
// Values here are overridden by any CLI inputs you pass to `bin/porter`.
return [
    // Package names. This kit is built around these two.
    'source' => 'Xenforo',
    'target' => 'Flarum',

    // Database table prefixes. Note the trailing underscore on target_prefix —
    // Flarum's default schema uses tables named `flarum_users`, `flarum_posts`,
    // etc. nitro-porter concatenates this prefix literally, so without the
    // underscore the migration writes to ghost tables Flarum will never read.
    'source_prefix' => 'xf_',
    'target_prefix' => 'flarum_',

    // Paths to local install folders — only needed if you are also transferring
    // media/attachment files. Leave blank for a database-only migration.
    'source_root' => '', // Example: '/var/www/html/xenforo/public_html'
    'target_root' => '', // Example: '/var/www/html/flarum/public'

    // Public web root of the new Flarum install (used to build links).
    'target_webroot' => 'https://your-flarum-site.example.com',

    // Connection aliases — leave these alone if you only edit the two below.
    'input_alias' => 'input',
    'output_alias' => 'output',

    // Data connections.
    'connections' => [
        [
            // SOURCE: the MySQL container holding your imported XenForo data.
            'alias' => 'input',
            'type' => 'database',
            'adapter' => 'mysql',
            'host' => 'xenforo-db',
            'port' => '3306',
            'name' => 'xenforo',
            'user' => 'xenforo',
            'pass' => 'CHANGEME_xenforo_db_password',
            'charset' => 'utf8mb4',
            'options' => [
                PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => false, // Critical for large datasets.
            ],
        ],
        [
            // TARGET: the Flarum database. nitro-porter writes here DIRECTLY,
            // which is why the flarum/ stack joins this stack's network.
            'alias' => 'output',
            'type' => 'database',
            'adapter' => 'mysql',
            'host' => 'flarum-db',
            'port' => '3306',
            'name' => 'flarum',
            'user' => 'flarum_user',
            'pass' => 'CHANGEME_flarum_db_password',
            'charset' => 'utf8mb4',
            'options' => [
                PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => false, // Critical for large datasets.
            ],
        ],
    ],

    // Advanced options.
    'option_cdn_prefix' => '',
    'option_data_types' => '',
    'debug' => false,
    'test_alias' => 'test',
];
