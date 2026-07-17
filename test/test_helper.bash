#!/usr/bin/env bash
# Shared synthetic fixtures for shitshow tests.

shitshow() {
  cd "$REPO_DIR" && \
    SHITSHOW_CALLER_PWD="$SHITSHOW_CALLER_PWD" \
    SHITSHOW_DATA_DIR="$SHITSHOW_DATA_DIR" \
    SHITSHOW_MONKEYS_BIN="$SHITSHOW_MONKEYS_BIN" \
    mise run -q "$@"
}
export -f shitshow

portable_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

fixture_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

make_audio() {
  local destination="$1"
  local seconds="${2:-2}"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "sine=frequency=440:duration=$seconds" \
    -ar 16000 -ac 1 "$destination"
}

ingest_fixture() {
  local source="${1:-fixture.wav}"
  local result
  result="$(shitshow ingest "$source" --name "Fictional planning call" --json)"
  printf '%s\n' "$result" > "$BATS_TEST_TMPDIR/ingest.json"
  MEETING_ID="$(jq -r '.meeting_id' <<< "$result")"
  MEETING_DIR="$SHITSHOW_DATA_DIR/meetings/$MEETING_ID"
  export MEETING_ID MEETING_DIR
}

setup() {
  export SHITSHOW_CALLER_PWD="$BATS_TEST_TMPDIR/caller"
  export SHITSHOW_DATA_DIR="$BATS_TEST_TMPDIR/data"
  export SHITSHOW_MONKEYS_BIN="$BATS_TEST_TMPDIR/bin/fake-monkeys"
  export FAKE_MONKEYS_LOG="$BATS_TEST_TMPDIR/monkeys.log"
  export FAKE_MONKEYS_STATE="$BATS_TEST_TMPDIR/monkeys-state"
  mkdir -m 700 "$SHITSHOW_CALLER_PWD" "$SHITSHOW_DATA_DIR" "$BATS_TEST_TMPDIR/bin"

  cat > "$SHITSHOW_MONKEYS_BIN" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
input="${!#}"
printf '%s\n' "$(basename "$input")" >> "$FAKE_MONKEYS_LOG"
if [ -n "${FAKE_MONKEYS_SLEEP:-}" ]; then
  sleep "$FAKE_MONKEYS_SLEEP"
fi
if [ -n "${FAKE_MONKEYS_FAIL_CHUNK:-}" ] && \
   [ "$(basename "$input")" = "$FAKE_MONKEYS_FAIL_CHUNK" ] && \
   [ ! -e "$FAKE_MONKEYS_STATE" ]; then
  : > "$FAKE_MONKEYS_STATE"
  exit 17
fi
printf 'Synthetic transcript for %s\n' "$(basename "$input" .wav)"
SCRIPT
  chmod +x "$SHITSHOW_MONKEYS_BIN"
  make_audio "$SHITSHOW_CALLER_PWD/fixture.wav" 7
}
