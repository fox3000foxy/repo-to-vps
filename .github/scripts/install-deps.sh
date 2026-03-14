#!/usr/bin/env bash

# install-deps.sh
#
# Installs packages needed for the tmate-based remote session.
# This script assumes that an APT cache directory is available (via actions/cache)
# and uses a custom apt configuration to point to it.

set -euo pipefail

cache_dir="${GITHUB_WORKSPACE:-$(pwd)}/.apt-cache"
mkdir -p "$cache_dir/archives" "$cache_dir/lists"

# Ensure apt can write to the cache directory (apt runs as _apt internally)
sudo chown -R _apt:root "$cache_dir"
sudo chmod -R 0775 "$cache_dir"

cat > "$cache_dir/apt-cache.conf" <<EOF
Dir::Cache::Archives "$cache_dir/archives";
Dir::State::Lists "$cache_dir/lists";
EOF

sudo apt-get -c "$cache_dir/apt-cache.conf" update
sudo apt-get -c "$cache_dir/apt-cache.conf" install -y tmate inotify-tools
