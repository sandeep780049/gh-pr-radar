#!/usr/bin/env bash
# Test suite for gh-pr-radar. Runs the script against a stubbed gh + jq
# fixture — no network, no auth needed. Exit 0 = all tests pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../gh-pr-radar"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok  - $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }

assert_eq() { # assert_eq <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

assert_contains() {
  case "$3" in *"$2"*) ok "$1" ;; *) fail "$1 (missing [$2] in [${3:0:120}])" ;; esac
}

assert_not_contains() {
  case "$3" in *"$2"*) fail "$1 (unexpected [$2])" ;; *) ok "$1" ;; esac
}

# ---------- fixtures ----------
mkdir -p "$TMP/bin"
# Resolve the REAL jq *before* the stub dir is prepended to PATH, so the stub
# works on any platform (Linux CI, macOS, Windows Git Bash) where /usr/bin/jq
# may not exist. GH_PR_RADAR_JQ points at the stub; the stub execs REAL_JQ.
REAL_JQ="$(command -v jq)" || { echo "run_tests.sh: jq is required" >&2; exit 1; }
cat > "$TMP/bin/jq" <<STUB
#!/usr/bin/env bash
exec "$REAL_JQ" "\$@"
STUB
chmod +x "$TMP/bin/jq"

cat > "$TMP/gh.json" <<'JSON'
[
  {"repository":{"nameWithOwner":"acme/api"},"number":101,"title":"feat: thing","updatedAt":"2026-10-01T10:00:00Z","headRefName":"feat/thing","url":"https://github.com/acme/api/pull/101"},
  {"repository":{"nameWithOwner":"acme/api"},"number":102,"title":"fix: other","updatedAt":"2026-09-15T10:00:00Z","headRefName":"fix/other","url":"https://github.com/acme/api/pull/102"}
]
JSON

# Stub gh: search returns fixture; pr view returns per-PR detail.
cat > "$TMP/bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"auth status"*) exit 0 ;;
  search\ prs*) cat "$TMP/gh.json" ;;
  pr\ view\ 101*) cat "$TMP/detail-101.json" 2>/dev/null || echo '{}' ;;
  pr\ view\ 102*) cat "$TMP/detail-102.json" 2>/dev/null || echo '{}' ;;
  *) echo "unexpected gh call: \$*" >&2; exit 1 ;;
esac
STUB
chmod +x "$TMP/bin/gh"

# detail 101: failing CI, changes requested, DIRTY — should rank prio 0
cat > "$TMP/detail-101.json" <<JSON
{"title":"feat: thing","url":"https://github.com/acme/api/pull/101","updatedAt":"2026-10-01T10:00:00Z","isDraft":false,
 "statusCheckRollup":[{"__typename":"CheckRun","conclusion":"FAILURE","name":"test"},{"__typename":"CheckRun","conclusion":"SUCCESS","name":"lint"}],
 "reviews":[{"state":"CHANGES_REQUESTED","author":{"login":"amy"}}],
 "reviewRequests":[],"mergeStateStatus":"DIRTY","mergeable":"CONFLICTING"}
JSON

# detail 102: passing CI, no reviews, CLEAN, older — should rank prio 5-ish
cat > "$TMP/detail-102.json" <<JSON
{"title":"fix: other","url":"https://github.com/acme/api/pull/102","updatedAt":"2026-09-15T10:00:00Z","isDraft":false,
 "statusCheckRollup":[{"__typename":"CheckRun","conclusion":"SUCCESS","name":"test"}],
 "reviews":[],"reviewRequests":[],"mergeStateStatus":"CLEAN","mergeable":"MERGEABLE"}
JSON

export PATH="$TMP/bin:$PATH"
export NO_COLOR=1
export GH_PR_RADAR_GH="$TMP/bin/gh"
export GH_PR_RADAR_JQ="$TMP/bin/jq"

OUT=$("$BIN" 2>&1)
RC=$?

echo "# core"
assert_eq "exits 0 with PRs present" "0" "$RC"
assert_contains "shows PR 101"        "#101" "$OUT"
assert_contains "shows PR 102"        "#102" "$OUT"
assert_contains "marks failing CI"    "failing" "$OUT"
assert_contains "marks changes-requested" "changes-wanted" "$OUT"
assert_contains "marks conflicts"     "conflicts" "$OUT"
assert_contains "summary line present" "open PR(s)" "$OUT"
assert_contains "table has header row" "REPO" "$OUT"

L101=$(printf '%s\n' "$OUT" | grep -n -o '#101' | head -1 | cut -d: -f1)
L102=$(printf '%s\n' "$OUT" | grep -n -o '#102' | head -1 | cut -d: -f1)
if [ -n "$L101" ] && [ -n "$L102" ] && [ "$L101" -lt "$L102" ]; then
  ok "dirty PR listed before clean PR"
else
  fail "dirty PR listed before clean PR (101 at $L101, 102 at $L102)"
fi

echo "# flags"
JOUT=$("$BIN" --json 2>/dev/null)
assert_contains "json output parses" "acme/api" \
  "$(printf '%s\n' "$JOUT" | jq -r '.repo' | head -1)"
FIRST_PRIO=$(printf '%s\n' "$JOUT" | jq -r '.prio' | head -1)
assert_eq "json prio of worst PR is 0" "0" "$FIRST_PRIO"

ROUT=$("$BIN" --repo kestra 2>&1); RRC=$?
assert_eq "--repo with no match exits 2" "2" "$RRC"
assert_contains "--repo no-match message" "no PRs match" "$ROUT"

echo "# no-prs path"
echo '[]' > "$TMP/gh.json"
NOUT=$("$BIN" 2>&1); NRC=$?
assert_eq "empty result exits 2" "2" "$NRC"
assert_contains "empty message shown" "radar clear" "$NOUT"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
