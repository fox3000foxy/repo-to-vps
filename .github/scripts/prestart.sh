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

# Ensure the remote session has a consistent shell environment.
# The core prompt/aliases are stored in a separate file (remote_bashrc) so updates
# can be made without editing this hook.
if ! grep -q "Custom prompt and aliases for remote sessions" "$HOME/.bashrc" 2>/dev/null; then
  cp .github/scripts/remote_bashrc "$HOME/.bashrc" 2>/dev/null || true
fi

source "$HOME/.bashrc"

# Keep root's bashrc in sync for convenience when using sudo.
sudo cp "$HOME/.bashrc" /root/.bashrc 2>/dev/null || true

# Optional: show which home is used
echo "[prestart] HOME=$HOME, pwd=$(pwd)"
