set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Ensure we have the latest filesystem tag from remote
git fetch --tags origin "refs/tags/filesystem:refs/tags/filesystem" || true

# Run optional prestart hook (if present) after restoring the filesystem tag
if [ -f ".github/scripts/prestart.sh" ]; then
  echo "Running prestart script"
  bash .github/scripts/prestart.sh
fi

# Checkout the tag content into a working branch so we can modify it.
# Reset/clean to ensure the working tree matches the tag exactly.
if git rev-parse -q --verify "refs/tags/filesystem" >/dev/null; then
  git checkout -B filesystem-workspace refs/tags/filesystem
  git reset --hard refs/tags/filesystem
  # Keep cache dirs (apt cache, etc.) from being deleted and avoid permission issues
  git clean -fdx -e .apt-cache
else
  git checkout -B filesystem-workspace
fi

push_tag() {
  git tag -f filesystem
  # Push tag explicitly (avoid "matches more than one" when a branch has the same name)
  git push origin --force refs/tags/filesystem:refs/tags/filesystem
}

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
  # Watch filesystem changes (ignore hidden files/dirs like .bashrc, .apt-cache, etc.) and commit/push immediately
  while inotifywait -qq -r -e modify,create,delete,move --exclude '(^|/)\.' .; do
    commit_and_push
    # debounce bursty changes (same file saved multiple times quickly)
    sleep 1
  done
}

commit_and_push() {
  # Add only non-hidden files (avoid committing runtime dotfiles like .bashrc, .apt-cache, etc.)
  git add -A -- . ':(exclude).*'
  # Still allow explicitly tracked hidden metadata if needed (e.g., .github workflows)
  git add -A .github 2>/dev/null || true

  if ! git diff --cached --quiet; then
    git commit -m "autosave $(date -u +%Y%m%dT%H%M%SZ)" || true
    push_tag || true
  fi
}

autosave &
autosave_pid=$!

# Start tmate and show connection info (detached, so disconnecting client does not stop the job)
tmate -S /tmp/tmate.sock new-session -d
sleep 2

tmate_ssh=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
tmate_web=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

source "$HOME/.bashrc"

echo "=== tmate connection ==="
echo "SSH: ${tmate_ssh}"
echo "WEB: ${tmate_web}"
echo "========================"

# Update README with the live session link(s)
python3 .github/scripts/update_readme.py --ssh "$tmate_ssh" --web "$tmate_web"

# keep the job alive indefinitely (or until timeout/cancel)
# Emit periodic output to avoid GitHub Actions idle-timeout killing the job.
echo "Session is running. Cancel the workflow or wait for timeout to stop."
while true; do
  echo "[heartbeat] $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sleep 300
done