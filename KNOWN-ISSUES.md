# Known issues

The kit's job is to be honest about where the rough edges are. This page lists
every upstream snag I've hit running the pipeline end-to-end, what works
around each one, and where the proper fix lives if one exists.

If your run hits something not on this page, please open an issue — the only
way these get found is by people actually running migrations.

---

## 1. nitro-porter — `promoteAdmin` crashes on the postscript phase

**Symptom:** the migration finishes all the `import:` and `build:` steps, then
crashes:

```
Illuminate\Database\QueryException
SQLSTATE[42S02]: Base table or view not found: 1146
Table 'flarum.flarum_User' doesn't exist
(SQL: select * from `flarum_User` where `Admin` > ? limit 1)
```

**Why:** `src/Postscript/Flarum.php` looks up the source-side admin via the
output-prefixed query builder, which resolves to `flarum_User` instead of the
`PORT_User` scratch table that actually holds the data.

**Fix:** patched in
[LinuxJessi/nitro-porter@fix/flarum-postscript-and-discussions](https://github.com/LinuxJessi/nitro-porter/tree/fix/flarum-postscript-and-discussions),
filed against upstream `prosembler/nitro-porter` HEAD. Until upstream merges,
clone from the fork:

```sh
git clone -b fix/flarum-postscript-and-discussions \
  https://github.com/LinuxJessi/nitro-porter.git
```

**Without the fix:** all your data still migrates, but no admin user is
promoted in Flarum. You can manually add the row afterwards:
```sql
INSERT INTO flarum_group_user (group_id, user_id) VALUES (1, <admin-id>);
```

---

## 2. nitro-porter — discussions silently fail to import

**Symptom:** the run completes cleanly. Migration log proudly reports
`import: discussions — N rows`. But `flarum_discussions` is empty, the public
Flarum API returns no threads, and every post in `flarum_posts` references a
discussion_id that doesn't exist.

**Why:** `flarum_discussions.is_private` is `NOT NULL DEFAULT 0`. nitro-porter's
discussion-import structure lists `is_private` (for the fof/byobu PM
extension) but no `$map` entry populates it from the source. The batched
INSERT therefore binds NULL, MariaDB throws 1048, and
`Storage\Database::sendBatch()` swallows the QueryException in a try/catch
that prints to stdout and continues. By that point `stream()` has already
incremented the row counter, so the migration log claims success.

**Fix:** patched in the same fork branch as Issue 1
([LinuxJessi/nitro-porter@fix/flarum-postscript-and-discussions](https://github.com/LinuxJessi/nitro-porter/tree/fix/flarum-postscript-and-discussions)).

**Without the fix:** there's no clean recovery short of patching and re-running.
Don't ship a forum migrated by an unpatched nitro-porter.

---

## 3. nitro-porter — `xf_attachment_data.file_key` missing on older XenForo

**Symptom:** during the EXPORT phase (early in the run), before any `import:`
lines appear:

```
Illuminate\Database\QueryException
SQLSTATE[42S22]: Column not found: 1054 Unknown column 'xf_ad.file_key'
```

**Why:** `src/Source/Xenforo.php::attachments()` references
`xf_attachment_data.file_key` (added in XenForo **2.2**). Older XenForo
versions (2.0/2.1) store the equivalent path key in `file_hash` instead. The
file was "captured in late 2025 from Xenforo v2.3.6" per the source comment,
so nitro-porter only handles XF 2.2+.

**Workaround (no patch yet):** skip attachment migration entirely via
`config.php`:

```php
'option_data_types' => 'users,roles,categories,discussions,comments,privateMessages',
```

This is fine for a database-only migration (no `source_root` / `target_root`
in config). You still get users, threads, posts, tags. You lose attachment
*metadata* — actual files would need to be copied separately.

**Proper fix (not yet upstreamed):** make the attachment query detect the
column at runtime and use `file_hash` as fallback. Filed for a follow-up
issue; not blocking the kit's headline workflow.

---

## 4. nitro-porter — `Storage\Database::sendBatch()` swallows SQL errors

**Symptom:** silent partial migrations. Issue 2 is one manifestation; the same
pattern would hide any future schema-mismatch failure.

**Why:** the catch block in `Storage\Database::sendBatch()` echoes the
`QueryException` message to stdout but does not re-raise. The migration log
keeps reporting success per row because `stream()` increments the row counter
before the batch insert runs.

**Workaround:** none. Carefully read the FULL migration stdout for "Batch
insert error:" lines after every run — they appear inline with the import
progress.

**Proper fix (not in any branch yet):** the catch should at least set an
error flag the controller checks before reporting success, ideally re-raise.
Worth its own upstream PR.

---

## 5. Headless Flarum install — `shinsenter/flarum` has no `FLARUM_*` env vars

**Symptom:** people coming from `mondedie/docker-flarum` or
`crazy-max/docker-flarum` reach for env vars like `FLARUM_ADMIN_USER` /
`FLARUM_ADMIN_PASS` — those don't exist in `shinsenter/flarum`.

**Why:** `shinsenter/flarum`'s `INITIAL_PROJECT=flarum/flarum` only triggers
the generic `composer create-project` flow (it stages the codebase). The
Flarum schema and admin user creation is a separate step.

**The kit's approach:** ship `flarum/install.yml.example` and run Flarum's
own CLI installer non-interactively:

```sh
docker compose exec flarum php flarum install --file=/install.yml
```

**Gotcha:** mount `install.yml` to `/install.yml`, **not**
`/var/www/html/install.yml`. The image's bootstrap hook only stages Flarum
when `/var/www/html` is empty; putting a file there pre-bootstrap skips the
codebase install entirely.

---

## How to report a new issue you hit

Open an issue at the kit's repo with:
1. The output of `docker compose ps` for both stacks
2. The full output of `bin/porter run` (use `tee` so you don't lose the
   middle when scrolling)
3. The output of `./verify.sh`
4. The relevant `config.php` (with passwords redacted)
