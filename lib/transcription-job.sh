#!/usr/bin/env bash

# Verified background transcription process identity and state.

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
  local recorded pid
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
