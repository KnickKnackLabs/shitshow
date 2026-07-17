#!/usr/bin/env bash

# Shared private-workspace and process-state helpers.

ss_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

ss_require_command() {
  command -v "$1" >/dev/null 2>&1 || ss_die "$1 is required"
}

ss_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

ss_random_hex() {
  local bytes="${1:-4}"
  od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
}

ss_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    ss_die "shasum or sha256sum is required"
  fi
}

ss_file_size() {
  stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1"
}

ss_file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

ss_file_uid() {
  stat -f '%u' "$1" 2>/dev/null || stat -c '%u' "$1"
}

ss_assert_private_dir() {
  local dir="$1"
  local label="$2"
  local mode uid

  [ ! -L "$dir" ] || ss_die "$label must not be a symlink: $dir"
  [ -d "$dir" ] || ss_die "$label is not a directory: $dir"
  uid="$(ss_file_uid "$dir")"
  [ "$uid" = "$(id -u)" ] || ss_die "$label is not owned by the current user: $dir"
  mode="$(ss_file_mode "$dir")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || ss_die "cannot determine private mode for $label: $dir"
  (( (8#$mode & 077) == 0 )) || ss_die "$label must not grant group or other access (mode $mode): $dir"
}

ss_data_dir() {
  if [ -n "${SHITSHOW_DATA_DIR:-}" ]; then
    printf '%s\n' "$SHITSHOW_DATA_DIR"
  else
    printf '%s/shitshow\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
  fi
}

ss_meetings_root() {
  local data root created=false
  data="$(ss_data_dir)"

  [ ! -L "$data" ] || ss_die "managed data directory must not be a symlink: $data"
  if [ ! -e "$data" ]; then
    mkdir -p "$data"
    created=true
  fi
  if [ "$created" = true ]; then
    chmod 700 "$data"
  fi
  ss_assert_private_dir "$data" "managed data directory"
  data="$(cd -P "$data" && pwd)"

  root="$data/meetings"
  [ ! -L "$root" ] || ss_die "managed meetings root must not be a symlink: $root"
  if [ ! -e "$root" ]; then
    mkdir -m 700 "$root"
  fi
  ss_assert_private_dir "$root" "managed meetings root"
  cd -P "$root" && pwd
}

ss_validate_meeting_id() {
  [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]] || \
    ss_die "invalid meeting id: $1"
}

ss_new_meeting_id() {
  printf '%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$(ss_random_hex 4)"
}

ss_meeting_path() {
  local id="$1"
  local root
  ss_validate_meeting_id "$id"
  root="$(ss_meetings_root)"
  printf '%s/%s\n' "$root" "$id"
}

ss_require_regular_file() {
  local file="$1"
  local label="$2"
  [ ! -L "$file" ] || ss_die "$label must not be a symlink: $file"
  [ -f "$file" ] || ss_die "$label not found: $file"
}

ss_require_meeting() {
  local id="$1"
  local dir metadata stored_id
  dir="$(ss_meeting_path "$id")"
  ss_assert_private_dir "$dir" "meeting workspace"
  metadata="$dir/meeting.json"
  ss_require_regular_file "$metadata" "meeting metadata"
  stored_id="$(jq -er '.id' "$metadata" 2>/dev/null)" || ss_die "invalid meeting metadata: $metadata"
  [ "$stored_id" = "$id" ] || ss_die "meeting metadata id mismatch: $id"
  printf '%s\n' "$dir"
}

ss_audio_path() {
  local dir="$1"
  local name audio
  name="$(jq -er '.audio_file' "$dir/meeting.json" 2>/dev/null)" || \
    ss_die "meeting metadata has no audio_file"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || ss_die "unsafe managed audio filename: $name"
  audio="$dir/$name"
  ss_require_regular_file "$audio" "managed audio"
  printf '%s\n' "$audio"
}

ss_expected_sha() {
  jq -er '.sha256' "$1/meeting.json" 2>/dev/null || ss_die "meeting metadata has no sha256"
}

ss_verify_recording() {
  local dir="$1"
  local audio expected actual
  audio="$(ss_audio_path "$dir")"
  expected="$(ss_expected_sha "$dir")"
  actual="$(ss_sha256 "$audio")"
  [ "$actual" = "$expected" ] || ss_die "recording checksum mismatch expected=$expected actual=$actual"
  printf '%s\n' "$actual"
}

ss_duration() {
  ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$1"
}

ss_atomic_json_file() {
  local destination="$1"
  local temporary
  shift
  temporary="${destination}.tmp.$$.$(ss_random_hex 2)"
  jq "$@" > "$temporary"
  chmod 600 "$temporary"
  mv "$temporary" "$destination"
}

ss_process_command() {
  local command
  if ! command="$(ps -p "$1" -o command= 2>/dev/null)"; then
    command=""
  fi
  printf '%s\n' "$command"
}

ss_job_pid() {
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
  command="$(ss_process_command "$pid")"
  [[ "$command" == *"transcribe-job"* && "$command" == *"$token"* ]] || return 1
  printf '%s\n' "$pid"
}

ss_job_state() {
  local dir="$1"
  local state="$dir/transcribe-job.json"
  local recorded
  if pid="$(ss_job_pid "$dir")"; then
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
