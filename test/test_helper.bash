#!/usr/bin/env bash
# Shared fixtures for shitshow tests.

# Run a repo task through mise so tests exercise the real task path.
shitshow() {
  cd "$REPO_DIR" && mise run -q "$@"
}
export -f shitshow
