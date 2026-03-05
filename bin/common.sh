#!/usr/bin/env bash
# common.sh — Common functions for browser-fetch scripts

# Ensure daemon is running (with retry on failure)
ensure_daemon() {
  local npm_root
  npm_root="$(npm root -g)"

  # Check if daemon is already running by testing the port
  if nc -z 127.0.0.1 50838 2>/dev/null || (command -v powershell &>/dev/null && powershell -NoProfile -Command "(Test-NetConnection -ComputerName 127.0.0.1 -Port 50838 -WarningAction SilentlyContinue).TcpTestSucceeded" 2>/dev/null | grep -qi true); then
    return 0
  fi

  echo "[daemon] Starting..." >&2
  cd "$npm_root/agent-browser" && node dist/daemon.js &
  sleep 3
}

# Try command with retry on daemon failure
run_with_retry() {
  local output
  local exit_code

  output=$("$@" 2>&1)
  exit_code=$?

  if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "daemon failed"; then
    echo "[daemon] Failed, retrying..." >&2
    ensure_daemon
    sleep 1
    output=$("$@" 2>&1)
    exit_code=$?
  fi

  echo "$output"
  return $exit_code
}
