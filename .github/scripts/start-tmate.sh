set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Ensure we have the latest filesystem tag from remote
git fetch --tags origin "refs/tags/filesystem:refs/tags/filesystem" || true

# Cache helper scripts so they remain available even if the filesystem tag is empty
RUNNER_SCRIPTS_DIR="/tmp/runner-scripts"
rm -rf "$RUNNER_SCRIPTS_DIR"
mkdir -p "$RUNNER_SCRIPTS_DIR"
cp -r .github/scripts "$RUNNER_SCRIPTS_DIR/" 2>/dev/null || true

# Run optional prestart hook (if present) after restoring the filesystem tag
if [ -f ".github/scripts/prestart.sh" ]; then
  echo "Running prestart script"
  bash .github/scripts/prestart.sh
fi

push_tag() {
  git tag -f filesystem
  # Push tag explicitly (avoid "matches more than one" when a branch has the same name)
  git push origin --force refs/tags/filesystem:refs/tags/filesystem
}

# Checkout the tag content into a working branch so we can modify it.
# Reset/clean to ensure the working tree matches the tag exactly.
if git rev-parse -q --verify "refs/tags/filesystem" >/dev/null; then
  git checkout -B filesystem-workspace refs/tags/filesystem
  git reset --hard refs/tags/filesystem
  # Keep cache dirs (apt cache, etc.) from being deleted and avoid permission issues
  git clean -fdx -e .apt-cache
else
  # Create an empty filesystem branch (no files) to avoid importing main content
  git checkout --orphan filesystem-workspace
  git rm -rf --cached . || true
  git clean -fdx -e .git -e .apt-cache -e .github -e .github/scripts -e .github/workflows
  git commit --allow-empty -m "init filesystem (empty)" || true
  push_tag || true
fi

# Ensure the filesystem tag exists for next run
push_tag || true

commit_and_push() {
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "autosave $(date -u +%Y%m%dT%H%M%SZ)" || true
    push_tag || true
  fi
}

autosave() {
  # Watch filesystem changes (ignore Git metadata and local cache dirs) and commit/push immediately
  while inotifywait -qq -r -e modify,create,delete,move --exclude '(^|/)(\.git|\.apt-cache)(/|$)' .; do
    echo "[autosave] change detected"
    commit_and_push
    # debounce bursty changes (same file saved multiple times quickly)
    sleep 1
  done
}

commit_and_push() {
  # Use an exclusive lock so multiple autosave loops don't run the git commands concurrently.
  (
    flock -n 200 || return

    # Add only non-hidden files (avoid committing runtime dotfiles like .bashrc, .apt-cache, etc.)
    # Exclude workflow files / helper scripts so the push isn't rejected due to missing workflows permission.
    git add -A -- . ':(exclude).*' ':(exclude).github/workflows/**' ':(exclude).github/scripts/**'

    if ! git diff --cached --quiet; then
      # Keep a single commit in the filesystem tag by amending the existing commit.
      if git rev-parse --verify HEAD >/dev/null 2>&1; then
        git commit --amend --no-edit || true
      else
        git commit -m "autosave $(date -u +%Y%m%dT%H%M%SZ)" || true
      fi
      push_tag || true
    fi
  ) 200>/tmp/tmate_autosave.lock
}

autosave &
autosave_pid=$!

periodic_save() {
  while true; do
    sleep 5
    echo "[periodic autosave]"
    commit_and_push
  done
}

periodic_save &
periodic_save_pid=$!

# Start tmate in a loop so we can restart it automatically if the session ends.
# This makes reconnecting stable even after "exit".
while true; do
  tmate -S /tmp/tmate.sock new-session -d "bash --rcfile $HOME/.bashrc -i"
  # Keep the tmux session alive after the shell exits so clients can reconnect.
  tmate -S /tmp/tmate.sock set-option -g remain-on-exit on

  sleep 2

  tmate_ssh=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
  tmate_web=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

  # Write a helper script that can be fetched via raw URL and executed to connect.
  cat > run.sh <<'RUN'
#!/usr/bin/env sh
exec ssh "$tmate_ssh"
RUN
  chmod +x run.sh

  source "$HOME/.bashrc"

  echo "=== tmate connection ==="
  echo "SSH: ${tmate_ssh}"
  echo "WEB: ${tmate_web}"
  echo "RUN: curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/filesystem/run.sh | sh"
  echo "========================"

  # Update README with the live session link(s)
  python3 "$RUNNER_SCRIPTS_DIR/scripts/update_readme.py" \
    --ssh "$tmate_ssh" \
    --web "$tmate_web" \
    --run-url "https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/filesystem/run.sh"

  # Wait until tmate session is gone, then restart it
  while tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}' >/dev/null 2>&1; do
    sleep 2
  done

  echo "tmate session ended; restarting..."
done

# keep the job alive indefinitely (or until timeout/cancel)
# Emit periodic output to avoid GitHub Actions idle-timeout killing the job.
echo "Session is running. Cancel the workflow or wait for timeout to stop."
while true; do
  echo "[heartbeat] $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sleep 300
done