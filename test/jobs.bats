#!/usr/bin/env bats

load test_helper

@test "background transcription starts with verified identity and stops safely" {
  ingest_fixture
  export FAKE_MONKEYS_SLEEP=30

  mkdir -m 700 "$MEETING_DIR/.transcribe-control.lock"
  printf '%s\n' "$$" > "$MEETING_DIR/.transcribe-control.lock/pid"
  run shitshow transcribe:start "$MEETING_ID" --chunk-seconds 3
  [ "$status" -ne 0 ]
  [[ "$output" == *"job control already active"* ]]
  rm -rf "$MEETING_DIR/.transcribe-control.lock"

  run shitshow transcribe:start "$MEETING_ID" --chunk-seconds 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"status: running"* ]]
  pid="$(awk '/^pid:/ {print $2}' <<< "$output")"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]]
  kill -0 "$pid"

  run shitshow status "$MEETING_ID" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.transcription.status' <<< "$output")" = running ]

  run shitshow transcribe:stop "$MEETING_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status: paused"* ]]

  for ((attempt = 0; attempt < 50; attempt++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done
  ! kill -0 "$pid" 2>/dev/null
  [ "$(jq -r '.status' "$MEETING_DIR/transcribe-job.json")" = paused ]
}

@test "stop refuses to signal a stale or mismatched pid" {
  ingest_fixture
  jq -n \
    --arg token "0123456789abcdef0123456789abcdef" \
    --argjson pid "$$" \
    '{
      schema_version: 1,
      status: "running",
      pid: $pid,
      token: $token
    }' \
    > "$MEETING_DIR/transcribe-job.json"
  chmod 600 "$MEETING_DIR/transcribe-job.json"

  run shitshow transcribe:stop "$MEETING_ID"
  [ "$status" -eq 2 ]
  [[ "$output" == *"status: stale"* ]]
  kill -0 "$$"

  run shitshow status "$MEETING_ID" --json
  [ "$status" -eq 4 ]
  [ "$(jq -r '.transcription.status' <<< "$output")" = stale ]
}
