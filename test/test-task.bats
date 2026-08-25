#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

setup_runner_fixture() {
  RUNNER_BIN="$BATS_TEST_TMPDIR/test-runner-bin"
  BATS_LOG="$BATS_TEST_TMPDIR/bats.log"
  mkdir -p "$RUNNER_BIN"
  export BATS_LOG

  cat > "$RUNNER_BIN/bats" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'jobs=%s\n' "${BATS_NUMBER_OF_PARALLEL_JOBS:-}"
  printf 'runner=%s\n' "${BATS_PARALLEL_BINARY_NAME:-}"
  for argument in "$@"; do
    printf 'arg=%s\n' "$argument"
  done
} > "$BATS_LOG"
SH

  cat > "$RUNNER_BIN/rush" <<'SH'
#!/usr/bin/env bash
exit 0
SH

  chmod +x "$RUNNER_BIN/bats" "$RUNNER_BIN/rush"
  export BATS_COMMAND="$RUNNER_BIN/bats"
  export RUSH_COMMAND="$RUNNER_BIN/rush"
  unset BATS_NUMBER_OF_PARALLEL_JOBS BATS_PARALLEL_BINARY_NAME
}

log_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$BATS_LOG"
}

arg_count() {
  local expected="$1"
  awk -F= -v expected="$expected" '$1 == "arg" && substr($0, 5) == expected { count++ } END { print count + 0 }' "$BATS_LOG"
}

@test "test task defaults to four Rush jobs and resolves a named suite" {
  setup_runner_fixture

  run shitshow test workflow --filter checksum

  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via"* ]]
  [ "$(log_value jobs)" = "4" ]
  [ "$(log_value runner)" = "$RUNNER_BIN/rush" ]
  [ "$(arg_count --filter)" -eq 1 ]
  [ "$(arg_count checksum)" -eq 1 ]
  [ "$(arg_count "$REPO_DIR/test/workflow.bats")" -eq 1 ]
  [ "$(arg_count --no-parallelize-across-files)" -eq 0 ]
}

@test "parallel execution protects whitespace-bearing BATS arguments" {
  setup_runner_fixture
  target_dir="$BATS_TEST_TMPDIR/target with spaces"
  target="$target_dir/probe.bats"
  mkdir -p "$target_dir"
  : > "$target"

  run shitshow test "$target"

  [ "$status" -eq 0 ]
  [[ "$output" == *"whitespace-path fallback"* ]]
  [ "$(arg_count --no-parallelize-across-files)" -eq 1 ]
  [ "$(arg_count "$target")" -eq 1 ]
}

@test "explicit serial execution does not require Rush" {
  setup_runner_fixture
  export RUSH_COMMAND="$RUNNER_BIN/missing-rush"

  run shitshow test --jobs 1 workflow

  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
}

@test "parallel execution fails clearly without the selected runner" {
  setup_runner_fixture
  export RUSH_COMMAND="$RUNNER_BIN/missing-rush"

  run -127 shitshow test workflow

  [ "$status" -eq 127 ]
  [[ "$output" == *"parallel runner '$RUNNER_BIN/missing-rush' is unavailable for 4 jobs"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "invalid job count and missing option values fail before BATS" {
  setup_runner_fixture

  run -2 shitshow test --jobs lots workflow
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be a positive integer"* ]]
  [ ! -e "$BATS_LOG" ]

  run -2 shitshow test --filter
  [ "$status" -eq 2 ]
  [[ "$output" == *"--filter requires a value"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "public Shitshow test path runs tests within one BATS file concurrently" {
  probe_dir="$BATS_TEST_TMPDIR/within-file-probe"
  export PROBE_DIR="$BATS_TEST_TMPDIR/within-file-barrier"
  mkdir -p "$probe_dir" "$PROBE_DIR"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first test observes second test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
    printf '%s\n' "$test_keyword \"second test observes first test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/within-file.bats"

  unset BATS_COMMAND RUSH_COMMAND
  unset BATS_NUMBER_OF_PARALLEL_JOBS BATS_PARALLEL_BINARY_NAME

  run shitshow test "$probe_dir/within-file.bats"

  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via rush"* ]]
}
