#!/usr/bin/env bash

# Shared private-workspace and process-state helpers.

shitshow_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shitshow_require_command() {
  command -v "$1" >/dev/null 2>&1 || shitshow_die "$1 is required"
}

shitshow_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

shitshow_random_hex() {
  local bytes="${1:-4}"
  od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
}

shitshow_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shitshow_die "shasum or sha256sum is required"
  fi
}

shitshow_file_size() {
  case "$(uname -s)" in
    Darwin) stat -f '%z' "$1" ;;
    *) stat -c '%s' "$1" ;;
  esac
}

shitshow_file_mode() {
  case "$(uname -s)" in
    Darwin) stat -f '%Lp' "$1" ;;
    *) stat -c '%a' "$1" ;;
  esac
}

shitshow_file_uid() {
  case "$(uname -s)" in
    Darwin) stat -f '%u' "$1" ;;
    *) stat -c '%u' "$1" ;;
  esac
}

shitshow_assert_private_dir() {
  local dir="$1"
  local label="$2"
  local mode uid

  [ ! -L "$dir" ] || shitshow_die "$label must not be a symlink: $dir"
  [ -d "$dir" ] || shitshow_die "$label is not a directory: $dir"
  uid="$(shitshow_file_uid "$dir")"
  [ "$uid" = "$(id -u)" ] || shitshow_die "$label is not owned by the current user: $dir"
  mode="$(shitshow_file_mode "$dir")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || shitshow_die "cannot determine private mode for $label: $dir"
  (( (8#$mode & 077) == 0 )) || shitshow_die "$label must not grant group or other access (mode $mode): $dir"
}

shitshow_data_directory() {
  if [ -n "${SHITSHOW_DATA_DIR:-}" ]; then
    printf '%s\n' "$SHITSHOW_DATA_DIR"
  else
    printf '%s/shitshow\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
  fi
}

shitshow_ensure_meetings_store() {
  local data store created=false
  data="$(shitshow_data_directory)"

  [ ! -L "$data" ] || shitshow_die "managed data directory must not be a symlink: $data"
  if [ ! -e "$data" ]; then
    mkdir -p "$data"
    created=true
  fi
  if [ "$created" = true ]; then
    chmod 700 "$data"
  fi
  shitshow_assert_private_dir "$data" "managed data directory"
  data="$(cd -P "$data" && pwd)"

  store="$data/meetings"
  [ ! -L "$store" ] || shitshow_die "managed meetings store must not be a symlink: $store"
  if [ ! -e "$store" ]; then
    mkdir -m 700 "$store"
  fi
  shitshow_assert_private_dir "$store" "managed meetings store"
  cd -P "$store" && pwd
}

shitshow_require_meetings_store() {
  local data store
  data="$(shitshow_data_directory)"

  [ ! -L "$data" ] || shitshow_die "managed data directory must not be a symlink: $data"
  [ -d "$data" ] || shitshow_die "managed data directory not found: $data"
  shitshow_assert_private_dir "$data" "managed data directory"
  data="$(cd -P "$data" && pwd)"

  store="$data/meetings"
  [ ! -L "$store" ] || shitshow_die "managed meetings store must not be a symlink: $store"
  [ -d "$store" ] || shitshow_die "managed meetings store not found: $store"
  shitshow_assert_private_dir "$store" "managed meetings store"
  cd -P "$store" && pwd
}

shitshow_validate_meeting_id() {
  [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]] || \
    shitshow_die "invalid meeting id: $1"
}

shitshow_new_meeting_id() {
  printf '%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$(shitshow_random_hex 4)"
}

shitshow_meeting_path() {
  local id="$1"
  local store
  shitshow_validate_meeting_id "$id"
  store="$(shitshow_require_meetings_store)"
  printf '%s/%s\n' "$store" "$id"
}

shitshow_require_regular_file() {
  local file="$1"
  local label="$2"
  [ ! -L "$file" ] || shitshow_die "$label must not be a symlink: $file"
  [ -f "$file" ] || shitshow_die "$label not found: $file"
}

shitshow_require_meeting() {
  local id="$1"
  local dir metadata stored_id
  dir="$(shitshow_meeting_path "$id")"
  shitshow_assert_private_dir "$dir" "meeting workspace"
  metadata="$dir/meeting.json"
  shitshow_require_regular_file "$metadata" "meeting metadata"
  stored_id="$(jq -er '.id' "$metadata" 2>/dev/null)" || shitshow_die "invalid meeting metadata: $metadata"
  [ "$stored_id" = "$id" ] || shitshow_die "meeting metadata id mismatch: $id"
  printf '%s\n' "$dir"
}

shitshow_audio_path() {
  local dir="$1"
  local name audio
  name="$(jq -er '.audio_file' "$dir/meeting.json" 2>/dev/null)" || \
    shitshow_die "meeting metadata has no audio_file"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || shitshow_die "unsafe managed audio filename: $name"
  audio="$dir/$name"
  shitshow_require_regular_file "$audio" "managed audio"
  printf '%s\n' "$audio"
}

shitshow_expected_sha() {
  jq -er '.sha256' "$1/meeting.json" 2>/dev/null || shitshow_die "meeting metadata has no sha256"
}

shitshow_verify_recording() {
  local dir="$1"
  local audio expected actual
  audio="$(shitshow_audio_path "$dir")"
  expected="$(shitshow_expected_sha "$dir")"
  actual="$(shitshow_sha256 "$audio")"
  [ "$actual" = "$expected" ] || shitshow_die "recording checksum mismatch expected=$expected actual=$actual"
  printf '%s\n' "$actual"
}

shitshow_duration() {
  ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$1"
}

shitshow_atomic_json_file() {
  local destination="$1"
  local temporary
  shift
  temporary="${destination}.tmp.$$.$(shitshow_random_hex 2)"
  jq "$@" > "$temporary"
  chmod 600 "$temporary"
  mv "$temporary" "$destination"
}

shitshow_process_command() {
  local command
  if ! command="$(ps -p "$1" -o command= 2>/dev/null)"; then
    command=""
  fi
  printf '%s\n' "$command"
}

shitshow_job_pid() {
  local dir="$1"
  local state="$dir/transcribe-job.json"
  local pid token command

  [ ! -L "$state" ] || return 1
  [ -f "$state" ] || return 1
  if ! pid="$(jq -er '.pid | select(type == "number")' "$state" 2>/dev/null)"; then
    return 1
  fi
  if ! token="$(jq -er '.token | select(type == "string")' "$state" 2>/dev/null)"; then
    return 1
  fi
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  [[ "$token" =~ ^[0-9a-f]{32}$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  command="$(shitshow_process_command "$pid")"
  [[ "$command" == *"transcribe-job"* && "$command" == *"$token"* ]] || return 1
  printf '%s\n' "$pid"
}

shitshow_job_state() {
  local dir="$1"
  local state="$dir/transcribe-job.json"
  local recorded
  if pid="$(shitshow_job_pid "$dir")"; then
    printf 'running\n'
  elif [ -f "$state" ]; then
    recorded="$(jq -r '.status // "stale"' "$state" 2>/dev/null || printf 'stale')"
    if [ "$recorded" = running ]; then
      printf 'stale\n'
    else
      printf '%s\n' "$recorded"
    fi
  else
    printf 'not-started\n'
  fi
}
