#!/usr/bin/env bash

# Private managed-meeting storage, integrity, and atomic state helpers.

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
  (( (8#$mode & 077) == 0 )) || \
    shitshow_die "$label must not grant group or other access (mode $mode): $dir"
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

  [ -e "$data" ] || shitshow_die "managed data directory not found: $data"
  shitshow_assert_private_dir "$data" "managed data directory"
  data="$(cd -P "$data" && pwd)"
  store="$data/meetings"
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
  stored_id="$(jq -er '.id' "$metadata" 2>/dev/null)" || \
    shitshow_die "invalid meeting metadata: $metadata"
  [ "$stored_id" = "$id" ] || shitshow_die "meeting metadata id mismatch: $id"
  printf '%s\n' "$dir"
}

shitshow_audio_path() {
  local dir="$1"
  local name audio
  name="$(jq -er '.audio_file' "$dir/meeting.json" 2>/dev/null)" || \
    shitshow_die "meeting metadata has no audio_file"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
    shitshow_die "unsafe managed audio filename: $name"
  audio="$dir/$name"
  shitshow_require_regular_file "$audio" "managed audio"
  printf '%s\n' "$audio"
}

shitshow_expected_sha() {
  jq -er '.sha256' "$1/meeting.json" 2>/dev/null || \
    shitshow_die "meeting metadata has no sha256"
}

shitshow_verify_recording() {
  local dir="$1"
  local audio expected actual
  audio="$(shitshow_audio_path "$dir")"
  expected="$(shitshow_expected_sha "$dir")"
  actual="$(shitshow_sha256 "$audio")"
  [ "$actual" = "$expected" ] || \
    shitshow_die "recording checksum mismatch expected=$expected actual=$actual"
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

shitshow_acquire_lock() {
  local lock="$1"
  local label="$2"
  local old_pid

  [ ! -L "$lock" ] || shitshow_die "$label lock must not be a symlink: $lock"
  if mkdir -m 700 "$lock" 2>/dev/null; then
    printf '%s\n' "$$" > "$lock/pid"
    chmod 600 "$lock/pid"
    return 0
  fi

  if ! old_pid="$(cat "$lock/pid" 2>/dev/null)"; then
    old_pid=""
  fi
  if [[ "$old_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$old_pid" 2>/dev/null; then
    shitshow_die "$label already active with pid $old_pid"
  fi

  rm -f "$lock/pid"
  rmdir "$lock" 2>/dev/null || \
    shitshow_die "$label stale lock contains unexpected entries: $lock"
  mkdir -m 700 "$lock"
  printf '%s\n' "$$" > "$lock/pid"
  chmod 600 "$lock/pid"
}

shitshow_release_lock() {
  local lock="$1"
  local owner
  if ! owner="$(cat "$lock/pid" 2>/dev/null)"; then
    owner=""
  fi
  if [ "$owner" = "$$" ]; then
    rm -f "$lock/pid"
    rmdir "$lock" 2>/dev/null || shitshow_die "lock contains unexpected entries: $lock"
  fi
}
