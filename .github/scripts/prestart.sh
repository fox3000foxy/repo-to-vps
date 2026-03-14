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

# Add your prestart commands below.

# Example: ensure node_modules exist (if you use node)
# if [ -f package.json ]; then
#   npm install
# fi
