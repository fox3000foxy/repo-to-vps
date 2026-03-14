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

# Create a consistent bash prompt + useful aliases
cat > "$HOME/.bashrc" <<'BASHRC'
# Custom prompt and aliases for remote sessions (uses params.json values if present)

# Ensure tmate commands use the correct socket (set by start-tmate.sh)
export TMATE_SOCKET="/tmp/tmate.sock"

if [ "$(id -u)" -eq 0 ]; then
  export PS1="\[\e[37;1m\][\[\e[31;1m\]${user_display}\[\e[37;1m\]@\[\e[34;1m\]${host_display}\[\e[0m\] \W\[\e[37;1m\]]\[\e[31;1m\]\$\[\e[0m\] "
else
  export PS1="\[\e[37;1m\][\[\e[32;1m\]${user_display}\[\e[37;1m\]@\[\e[34;1m\]${host_display}\[\e[0m\] \W\[\e[37;1m\]]\[\e[0m\]\$ "
fi

# Provide a helper to detach from the tmate session without exiting the shell.
# Users can run "tmate-detach" instead of "exit" if they want to keep the session alive.
tmate-detach() {
  if command -v tmate >/dev/null 2>&1; then
    tmate detach 2>/dev/null || true
  fi
}

exit() {
    killall -9 -u "$(whoami)" tmate 2>/dev/null || true
    builtin exit "$@"
}

alias ls="ls --color=auto"
alias ll="ls -l"
alias lla="ls -a"
alias rm="rm -i"
BASHRC
source "$HOME/.bashrc"
sudo cp "$HOME/.bashrc" /root/.bashrc 2>/dev/null || true

# Optional: show which home is used
echo "[prestart] HOME=$HOME, pwd=$(pwd)"
