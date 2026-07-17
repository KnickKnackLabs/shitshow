#!/usr/bin/env bats

load test_helper

@test "maintained bootstrap surfaces exist" {
  for path in \
    mise.toml \
    README.tsx \
    README.md \
    CONTRIBUTING.md \
    SECURITY.md \
    .mise/tasks/test \
    .mise/tasks/doctor \
    .github/workflows/test.yml \
    lib/workspace.sh \
    lib/transcription.sh \
    lib/transcription-job.sh \
    libexec/ingest \
    libexec/status \
    libexec/review \
    libexec/review-advance \
    libexec/transcribe \
    libexec/transcribe-start \
    libexec/transcribe-stop \
    libexec/transcribe-job
  do
    [ -e "$REPO_DIR/$path" ]
  done
}

@test "README.md is generated from README.tsx" {
  run bash -c 'cd "$REPO_DIR" && readme build --check'
  [ "$status" -eq 0 ]
}

@test "doctor reports optional pre-commit hook state" {
  run shitshow doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre-commit"* ]]
}

@test "public product tasks include installed-command examples" {
  for pair in \
    "ingest|ingest" \
    "transcribe/_default|transcribe" \
    "transcribe/start|transcribe:start" \
    "transcribe/stop|transcribe:stop" \
    "status|status" \
    "review/_default|review" \
    "review/advance|review:advance"
  do
    task_path="${pair%%|*}"
    command="${pair#*|}"
    run grep -E "^#USAGE example \"shitshow ${command}( |\")" \
      "$REPO_DIR/.mise/tasks/$task_path"
    [ "$status" -eq 0 ]
  done
}

@test "public documentation states the private-data boundary" {
  run grep -F "Never commit recordings, transcripts" "$REPO_DIR/README.md"
  [ "$status" -eq 0 ]
  run grep -F "Real recordings" "$REPO_DIR/SECURITY.md"
  [ "$status" -eq 0 ]
}
