#!/usr/bin/env bash
# verify.sh — smoke check that a migration run actually moved data into Flarum.
#
# Run from anywhere AFTER the porter + flarum stacks are up and `bin/porter run`
# has completed. It samples the migrated database and the public Flarum API,
# then prints a one-line pass/fail per check.
#
# Usage:   ./verify.sh [path/to/flarum/.env]
# Default: assumes flarum/.env is in the same dir as this script.

set -u

# ------------------------------------------------------------------------------
# 0. Locate flarum/.env so we can pull the DB password without prompting.
# ------------------------------------------------------------------------------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="${1:-$script_dir/flarum/.env}"

if [[ ! -f "$env_file" ]]; then
    echo "verify.sh: cannot find flarum/.env at $env_file" >&2
    echo "           pass the path as the first argument" >&2
    exit 2
fi

# shellcheck disable=SC1090
set -a; source "$env_file"; set +a

if [[ -z "${FLARUM_DB_PASSWORD:-}" ]]; then
    echo "verify.sh: FLARUM_DB_PASSWORD not set in $env_file" >&2
    exit 2
fi

# ------------------------------------------------------------------------------
# 1. Helpers.
# ------------------------------------------------------------------------------
pass=0; fail=0
check() {
    local label="$1" want="$2" got="$3"
    if [[ "$got" == "$want" || ( "$want" == ">0" && "$got" -gt 0 ) ]]; then
        printf '  \033[32m✓\033[0m  %-44s %s\n' "$label" "$got"
        pass=$((pass + 1))
    else
        printf '  \033[31m✗\033[0m  %-44s got=%s want=%s\n' "$label" "$got" "$want"
        fail=$((fail + 1))
    fi
}

query() {
    docker exec flarum-db mariadb -uflarum_user -p"$FLARUM_DB_PASSWORD" flarum \
        -ssNe "$1" 2>/dev/null
}

# ------------------------------------------------------------------------------
# 2. Container/network preconditions.
# ------------------------------------------------------------------------------
echo "==> Preconditions"
for c in flarum flarum-db porter-php xenforo-db porter-db; do
    if docker ps --format '{{.Names}}' | grep -qx "$c"; then
        check "container $c is running" "1" "1"
    else
        check "container $c is running" "1" "0"
    fi
done

# ------------------------------------------------------------------------------
# 3. Migrated data: counts > 0 in each major table.
# ------------------------------------------------------------------------------
echo
echo "==> Migrated table counts"
check "flarum_users    has rows"   ">0" "$(query 'SELECT COUNT(*) FROM flarum_users')"
check "flarum_discussions has rows" ">0" "$(query 'SELECT COUNT(*) FROM flarum_discussions')"
check "flarum_posts    has rows"   ">0" "$(query 'SELECT COUNT(*) FROM flarum_posts')"
check "flarum_groups   has rows"   ">0" "$(query 'SELECT COUNT(*) FROM flarum_groups')"
check "flarum_tags     has rows"   ">0" "$(query 'SELECT COUNT(*) FROM flarum_tags')"

# ------------------------------------------------------------------------------
# 4. The specific bugs we patched — verify each one *upstream* of its symptom.
# ------------------------------------------------------------------------------
echo
echo "==> Patch-specific checks"

# Patch 1 (promoteAdmin): there should be at least one row in flarum_group_user
# with group_id=1 (Flarum's Admin group). Without the patch, the migration
# crashes before reaching this insert and the row is never written.
admin_count=$(query 'SELECT COUNT(*) FROM flarum_group_user WHERE group_id = 1')
check "promoteAdmin wrote at least one admin"  ">0" "$admin_count"

# Patch 2 (is_private default): flarum_discussions row count must be > 0.
# Without the patch the INSERT batch throws 1048 and is silently dropped,
# leaving the table empty even though the migration log claims success.
discussion_count=$(query 'SELECT COUNT(*) FROM flarum_discussions')
check "discussions actually landed (not silently dropped)"  ">0" "$discussion_count"

# Sanity: every post's discussion_id should exist in flarum_discussions.
# Without Patch 2 this would be thousands of orphans.
orphan_posts=$(query 'SELECT COUNT(*) FROM flarum_posts p LEFT JOIN flarum_discussions d ON d.id = p.discussion_id WHERE d.id IS NULL')
check "no orphan posts (every post has a discussion)" "0" "$orphan_posts"

# ------------------------------------------------------------------------------
# 5. Forum is actually serving content.
# ------------------------------------------------------------------------------
echo
echo "==> Public API"
http_code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8084/ 2>/dev/null || echo "000")
check "http://localhost:8084/ responds 200" "200" "$http_code"

api_rows=$(curl -s 'http://localhost:8084/api/discussions?page%5Blimit%5D=1' \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("data",[])))' 2>/dev/null || echo "0")
check "API returns at least one discussion to a guest"  ">0" "$api_rows"

# ------------------------------------------------------------------------------
# 6. Summary.
# ------------------------------------------------------------------------------
echo
if [[ $fail -eq 0 ]]; then
    echo "All $pass checks passed. Migration looks healthy."
    exit 0
else
    echo "$fail check(s) failed out of $((pass + fail)). Inspect the run logs."
    exit 1
fi
