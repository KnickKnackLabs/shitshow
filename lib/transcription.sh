#!/usr/bin/env bash

ss_total_seconds() {
  awk -v duration="$1" 'BEGIN { print int(duration + 0.999) }'
}

ss_chunk_count() {
  awk -v total="$1" -v step="$2" 'BEGIN { print int((total + step - 1) / step) }'
}

ss_chunk_duration() {
  local index="$1"
  local total="$2"
  local step="$3"
  local start remaining
  start=$((index * step))
  remaining=$((total - start))
  if [ "$remaining" -lt "$step" ]; then
    printf '%s\n' "$remaining"
  else
    printf '%s\n' "$step"
  fi
}

ss_marker_count() {
  local dir="$1"
  local suffix="$2"
  local count=0 file
  case "$suffix" in
    ok)
      for file in "$dir"/transcripts/chunk-*.ok; do
        [ -f "$file" ] || continue
        count=$((count + 1))
      done
      ;;
    failed)
      for file in "$dir"/transcripts/chunk-*.failed; do
        [ -f "$file" ] || continue
        count=$((count + 1))
      done
      ;;
    *) ss_die "unsupported marker suffix: $suffix" ;;
  esac
  printf '%s\n' "$count"
}

ss_write_progress() {
  local dir="$1"
  local total="$2"
  local step="$3"
  local count="$4"
  local progress_tmp combined_tmp
  local i id start seconds transcript status

  progress_tmp="$dir/.transcribe-progress.tsv.$$.$(ss_random_hex 2)"
  combined_tmp="$dir/.transcript.combined.txt.$$.$(ss_random_hex 2)"
  printf 'chunk\tstart\tseconds\tstatus\ttranscript\n' > "$progress_tmp"
  : > "$combined_tmp"

  for ((i = 0; i < count; i++)); do
    id="$(printf '%03d' "$i")"
    start=$((i * step))
    seconds="$(ss_chunk_duration "$i" "$total" "$step")"
    transcript="$dir/transcripts/chunk-${id}.txt"

    if [ -f "$dir/transcripts/chunk-${id}.ok" ] && [ -f "$transcript" ]; then
      status=ok
    elif [ -f "$dir/transcripts/chunk-${id}.failed" ]; then
      status=failed
    else
      status=pending
    fi

    printf '%s\t%s\t%s\t%s\ttranscripts/chunk-%s.txt\n' \
      "$id" "$start" "$seconds" "$status" "$id" >> "$progress_tmp"

    if [ "$status" = ok ]; then
      {
        printf '\n\n## Chunk %s — start %ss, duration %ss — ok\n\n' \
          "$id" "$start" "$seconds"
        cat "$transcript"
      } >> "$combined_tmp"
    fi
  done

  chmod 600 "$progress_tmp" "$combined_tmp"
  mv "$progress_tmp" "$dir/transcribe-progress.tsv"
  mv "$combined_tmp" "$dir/transcript.combined.txt"
}

ss_read_config() {
  local dir="$1"
  local expression="$2"
  local config="$dir/transcribe-config.json"
  [ ! -L "$config" ] || return 1
  [ -f "$config" ] || return 1
  jq -er "$expression" "$config" 2>/dev/null
}

ss_acquire_lock() {
  local lock="$1"
  local label="$2"
  local old_pid

  [ ! -L "$lock" ] || ss_die "$label lock must not be a symlink: $lock"
  if mkdir -m 700 "$lock" 2>/dev/null; then
    printf '%s\n' "$$" > "$lock/pid"
    chmod 600 "$lock/pid"
    return 0
  fi

  if ! old_pid="$(cat "$lock/pid" 2>/dev/null)"; then
    old_pid=""
  fi
  if [[ "$old_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$old_pid" 2>/dev/null; then
    ss_die "$label already active with pid $old_pid"
  fi

  rm -f "$lock/pid"
  rmdir "$lock" 2>/dev/null || ss_die "$label stale lock contains unexpected entries: $lock"
  mkdir -m 700 "$lock"
  printf '%s\n' "$$" > "$lock/pid"
  chmod 600 "$lock/pid"
}

ss_release_lock() {
  local lock="$1"
  local owner
  if ! owner="$(cat "$lock/pid" 2>/dev/null)"; then
    owner=""
  fi
  if [ "$owner" = "$$" ]; then
    rm -f "$lock/pid"
    rmdir "$lock" 2>/dev/null || ss_die "lock contains unexpected entries: $lock"
  fi
}
