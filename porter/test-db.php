<?php
/**
 * Connectivity smoke test. Run it from inside the porter-php container:
 *
 *     docker compose exec frankenphp php test-db.php
 *
 * It confirms nitro-porter can reach BOTH databases before you attempt a
 * migration. The cross-stack reach to flarum-db only succeeds once the flarum/
 * stack is up and has joined this stack's network (xenforo2flarum_net).
 *
 * Credentials come from config.php — edit them there, not here.
 */

$configPath = __DIR__ . '/config.php';
if (!file_exists($configPath)) {
    fwrite(STDERR, "  FAIL  config.php not found — copy config.example.php to config.php and fill in passwords.\n");
    exit(1);
}

$config = require $configPath;
$byAlias = [];
foreach ($config['connections'] as $conn) {
    $byAlias[$conn['alias']] = $conn;
}

$tests = [
    'source: xenforo-db' => $byAlias[$config['input_alias']]  ?? null,
    'target: flarum-db'  => $byAlias[$config['output_alias']] ?? null,
];

$failed = false;
foreach ($tests as $label => $c) {
    if (!$c) {
        echo "  SKIP  {$label} — connection alias missing from config.php\n";
        $failed = true;
        continue;
    }
    try {
        new PDO(
            "mysql:host={$c['host']};port={$c['port']};dbname={$c['name']}",
            $c['user'],
            $c['pass']
        );
        echo "  OK    {$label}\n";
    } catch (PDOException $e) {
        echo "  FAIL  {$label} — {$e->getMessage()}\n";
        $failed = true;
    }
}
exit($failed ? 1 : 0);
