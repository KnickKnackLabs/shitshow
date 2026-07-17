#!/usr/bin/env bats

load test_helper

@test "ingest creates a private checksum-safe managed workspace" {
  run bash -c 'umask 000; shitshow ingest fixture.wav --name "Fictional planning call" --json'
  [ "$status" -eq 0 ]

  meeting_id="$(jq -r '.meeting_id' <<< "$output")"
  meeting_dir="$SHITSHOW_DATA_DIR/meetings/$meeting_id"
  [[ "$meeting_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]]
  [ -f "$meeting_dir/meeting.json" ]
  [ -f "$meeting_dir/recording.wav" ]
  [ -f "$SHITSHOW_CALLER_PWD/fixture.wav" ]
  [ "$(portable_mode "$SHITSHOW_DATA_DIR")" = 700 ]
  [ "$(portable_mode "$meeting_dir")" = 700 ]
  [ "$(portable_mode "$meeting_dir/recording.wav")" = 600 ]
  [ "$(portable_mode "$meeting_dir/meeting.json")" = 600 ]
  [ "$(portable_mode "$meeting_dir/review-state.json")" = 600 ]
  [ "$(jq -r '.source_basename' "$meeting_dir/meeting.json")" = fixture.wav ]
  ! grep -Fq "$SHITSHOW_CALLER_PWD" "$meeting_dir/meeting.json"

  run shitshow status "$meeting_id" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.health' <<< "$output")" = ok ]
  [ "$(jq -r '.transcription.status' <<< "$output")" = not-started ]
  jq -e '
    keys == [
      "health", "meeting_id", "name", "recording",
      "review", "transcription", "workspace"
    ]
    and (.recording | keys) == [
      "actual_sha256", "bytes", "checksum",
      "duration_seconds", "expected_sha256"
    ]
    and (.transcription | keys) == [
      "chunk_count", "chunk_seconds", "chunks_complete",
      "chunks_failed", "model", "status"
    ]
    and (.review | keys) == ["cursor", "total"]
  ' <<< "$output"
}

@test "read-only tasks do not create the managed meetings store" {
  meeting_id=20260716T145938Z-a1b2c3d4
  rm -rf "$SHITSHOW_DATA_DIR"

  run shitshow status "$meeting_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"managed data directory not found"* ]]
  [ ! -e "$SHITSHOW_DATA_DIR" ]

  run shitshow review "$meeting_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"managed data directory not found"* ]]
  [ ! -e "$SHITSHOW_DATA_DIR" ]

  run shitshow transcribe:stop "$meeting_id"
  [ "$status" -ne 0 ]
  [[ "$output" == *"managed data directory not found"* ]]
  [ ! -e "$SHITSHOW_DATA_DIR" ]
}

@test "ingest rejects symlinked or group-readable managed stores" {
  real_root="$BATS_TEST_TMPDIR/real-data"
  mkdir -m 700 "$real_root"
  ln -s "$real_root" "$BATS_TEST_TMPDIR/link-data"
  export SHITSHOW_DATA_DIR="$BATS_TEST_TMPDIR/link-data"

  run shitshow ingest fixture.wav --json
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not be a symlink"* ]]

  rm "$BATS_TEST_TMPDIR/link-data"
  export SHITSHOW_DATA_DIR="$real_root"
  chmod 750 "$real_root"
  run shitshow ingest fixture.wav --json
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not grant group or other access"* ]]
}

@test "status reports checksum mismatch as machine-readable failure" {
  ingest_fixture
  printf 'tamper\n' >> "$MEETING_DIR/recording.wav"

  run shitshow status "$MEETING_ID" --json
  [ "$status" -eq 3 ]
  [ "$(jq -r '.health' <<< "$output")" = error ]
  [ "$(jq -r '.recording.checksum' <<< "$output")" = mismatch ]
}

@test "transcription is resumable and configuration is immutable after artifacts" {
  ingest_fixture

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"status: complete"* ]]
  [ "$(wc -l < "$FAKE_MONKEYS_LOG" | tr -d ' ')" = 3 ]
  grep -q $'000\t0\t3\tok' "$MEETING_DIR/transcribe-progress.tsv"
  grep -q $'002\t6\t1\tok' "$MEETING_DIR/transcribe-progress.tsv"
  [ "$(portable_mode "$MEETING_DIR/chunks")" = 700 ]
  [ "$(portable_mode "$MEETING_DIR/transcripts")" = 700 ]
  [ "$(portable_mode "$MEETING_DIR/transcribe-config.json")" = 600 ]
  [ "$(portable_mode "$MEETING_DIR/transcript.combined.txt")" = 600 ]

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$FAKE_MONKEYS_LOG" | tr -d ' ')" = 3 ]

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 2
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot change chunk size"* ]]

  printf 'Fictional glossary\n' > "$SHITSHOW_CALLER_PWD/prompt.txt"
  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3 --prompt-file prompt.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot change prompt"* ]]
  [ ! -e "$MEETING_DIR/asr-prompt.txt" ]

  run shitshow status "$MEETING_ID" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.transcription.status' <<< "$output")" = complete ]
  [ "$(jq -r '.transcription.chunks_complete' <<< "$output")" = 3 ]
}

@test "transcription imports a private prompt without retaining its source path" {
  ingest_fixture
  printf 'Fictional product and participant names\n' > "$SHITSHOW_CALLER_PWD/prompt.txt"

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3 --prompt-file prompt.txt
  [ "$status" -eq 0 ]
  [ -f "$MEETING_DIR/asr-prompt.txt" ]
  [ "$(portable_mode "$MEETING_DIR/asr-prompt.txt")" = 600 ]
  expected_sha="$(fixture_sha256 "$SHITSHOW_CALLER_PWD/prompt.txt")"
  [ "$(jq -r '.prompt_sha' "$MEETING_DIR/transcribe-config.json")" = "$expected_sha" ]
  ! grep -R -Fq "$SHITSHOW_CALLER_PWD" "$MEETING_DIR"
}

@test "failed ASR chunk is recorded and a rerun resumes" {
  ingest_fixture
  export FAKE_MONKEYS_FAIL_CHUNK=chunk-001.wav

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3
  [ "$status" -eq 17 ]
  [ -f "$MEETING_DIR/transcripts/chunk-000.ok" ]
  [ -f "$MEETING_DIR/transcripts/chunk-001.failed" ]

  run shitshow status "$MEETING_ID" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.transcription.status' <<< "$output")" = failed ]

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$FAKE_MONKEYS_LOG" | tr -d ' ')" = 4 ]
  [ ! -e "$MEETING_DIR/transcripts/chunk-001.failed" ]
}

@test "review output does not move state and advance is locked and audited" {
  ingest_fixture
  shitshow transcribe "$MEETING_ID" --chunk-seconds 3 >/dev/null

  run shitshow review "$MEETING_ID" --count 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Chunk 000"* ]]
  [[ "$output" == *"Chunk 001"* ]]
  [ "$(jq -r '.cursor' "$MEETING_DIR/review-state.json")" = 0 ]

  mkdir -m 700 "$MEETING_DIR/.review.lock"
  printf '%s\n' "$$" > "$MEETING_DIR/.review.lock/pid"
  run shitshow review:advance "$MEETING_ID" --count 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"already active"* ]]
  rm -rf "$MEETING_DIR/.review.lock"

  run shitshow review:advance "$MEETING_ID" --count 2
  [ "$status" -eq 0 ]
  [ "$(jq -r '.cursor' "$MEETING_DIR/review-state.json")" = 2 ]
  [ "$(jq -r '.audit[0].from' "$MEETING_DIR/review-state.json")" = 0 ]
  [ "$(jq -r '.audit[0].to' "$MEETING_DIR/review-state.json")" = 2 ]

  run shitshow review "$MEETING_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Chunk 002"* ]]
}

@test "managed transcript symlinks are rejected" {
  ingest_fixture
  mkdir -m 700 "$MEETING_DIR/chunks" "$MEETING_DIR/transcripts"
  ln -s "$SHITSHOW_CALLER_PWD/fixture.wav" "$MEETING_DIR/transcripts/chunk-000.txt"

  run shitshow transcribe "$MEETING_ID" --chunk-seconds 3
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not be a symlink"* ]]
}
