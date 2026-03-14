#!/usr/bin/env bash

# prestart.sh
#
# This script is executed after the repository has been checked out and
# the "filesystem" tag has been restored, but before starting tmate.
#
# Use this file to run initialization steps (install tools, prepare files,
# set environment variables, etc.) that need to happen before the remote
# session starts.
#
# Example:
#   echo "Setting up environment..."
#   mkdir -p .cache
#   touch .cache/started

set -euo pipefail

# Resolve username/hostname from params.json (if present), otherwise inherit from main branch (if present), otherwise generate it.
if [ -f params.json ]; then
  echo "[prestart] Using existing params.json"
elif git rev-parse --verify origin/main >/dev/null 2>&1 && git show origin/main:params.json >/dev/null 2>&1; then
  echo "[prestart] Inheriting params.json from origin/main"
  git show origin/main:params.json > params.json
elif git rev-parse --verify main >/dev/null 2>&1 && git show main:params.json >/dev/null 2>&1; then
  echo "[prestart] Inheriting params.json from main"
  git show main:params.json > params.json
else
  username="$(whoami 2>/dev/null || echo "${USER:-runner}")"
  hostname="$(hostname 2>/dev/null || echo "${HOSTNAME:-runnervm}")"
  cat > params.json <<JSON
{
  "username": "${username}",
  "hostname": "${hostname}"
}
JSON
fi

# Load values from params.json (existing or newly created)
username="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["username"])' params.json 2>/dev/null || echo "runner")"
hostname="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hostname"])' params.json 2>/dev/null || echo "runnervm")"

# Export override vars so the prompt uses them
export TMATE_USERNAME="${username}"
export TMATE_HOSTNAME="${hostname}"

# Create a consistent bash prompt + useful aliases
cat > "$HOME/.bashrc" <<'BASHRC'
# Custom prompt and aliases for remote sessions (uses params.json values if present)
user_display="${TMATE_USERNAME:-\u}"
host_display="${TMATE_HOSTNAME:-\h}"

if [ "$(id -u)" -eq 0 ]; then
  export PS1="\[\e[37;1m\][\[\e[31;1m\]${user_display}\[\e[37;1m\]@\[\e[34;1m\]${host_display}\[\e[0m\] \W\[\e[37;1m\]]\[\e[31;1m\]\$\[\e[0m\] "
else
  export PS1="\[\e[37;1m\][\[\e[32;1m\]${user_display}\[\e[37;1m\]@\[\e[34;1m\]${host_display}\[\e[0m\] \W\[\e[37;1m\]]\[\e[0m\]\$ "
fi

alias ls="ls --color=auto"
alias ll="ls -l"
alias lla="ls -a"
alias rm="rm -i"
BASHRC
source "$HOME/.bashrc"
sudo cp "$HOME/.bashrc" /root/.bashrc 2>/dev/null || true

# Optional: show which home is used
echo "[prestart] HOME=$HOME, pwd=$(pwd)"
