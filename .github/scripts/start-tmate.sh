#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Remote + persistent branch used to store the filesystem state.
remote=${REMOTE:-origin}
filesystem_branch="filesystem"

# Helper scripts are cached so they remain available even if the filesystem
# branch is empty (or cleaned by git).
RUNNER_SCRIPTS_DIR="/tmp/runner-scripts"
rm -rf "$RUNNER_SCRIPTS_DIR"
mkdir -p "$RUNNER_SCRIPTS_DIR"
cp -r .github/scripts "$RUNNER_SCRIPTS_DIR/" 2>/dev/null || true

# Optional per-repo initialization hook.
if [ -f ".github/scripts/prestart.sh" ]; then
  echo "Running prestart script"
  bash .github/scripts/prestart.sh
fi

# Make sure the remote filesystem branch exists locally (for fast checks).
git fetch "$remote" "$filesystem_branch":refs/remotes/$remote/$filesystem_branch 2>/dev/null || true

# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

push_filesystem() {
  # Push the current working branch into the remote filesystem branch.
  git push --force "$remote" "filesystem-workspace:$filesystem_branch" 2>/dev/null || true
}

ensure_filesystem_branch() {
  # Ensure the filesystem branch exists remotely (create it if missing).
  if ! git ls-remote --exit-code "$remote" "refs/heads/$filesystem_branch" >/dev/null 2>&1; then
    git checkout --orphan filesystem-workspace
    git rm -rf --cached . || true
    git clean -fdx -e .git -e .github -e .github/scripts -e .github/workflows -e .apt-cache -e .cache || true
    git commit --allow-empty -m "init filesystem (empty)" || true
    push_filesystem || true
  fi
}

sync_from_remote() {
  # Fast-forward local workspace from the remote filesystem branch.
  git fetch "$remote" "$filesystem_branch":refs/remotes/$remote/$filesystem_branch 2>/dev/null || true
  git merge --ff-only "refs/remotes/$remote/$filesystem_branch" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Restore workspace from filesystem branch
# ---------------------------------------------------------------------------

ensure_filesystem_branch

git checkout -B filesystem-workspace "refs/remotes/$remote/$filesystem_branch"
git reset --hard "refs/remotes/$remote/$filesystem_branch"
# Keep cache dirs (apt cache, etc.) from being deleted and avoid permission issues
git clean -fdx -e .apt-cache -e .cache -e host.conf -e tmate.sock

# Ensure the filesystem branch exists remotely for the next run
push_filesystem || true

autosave() {
  # Watch filesystem changes (ignore Git metadata, caches and temporary session state) and commit/push immediately
  while inotifywait -qq -r -e modify,create,delete,move --exclude '(^|/)(\.git|\.apt-cache|\.cache|host\.conf|tmate\.sock|\.gitignore|\.txt\.swp)(/|$)' .; do
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

    # Ensure we're up-to-date with any remote changes to filesystem.
    sync_from_remote

    # Add all changes (respect .gitignore). Explicitly avoid committing workflow/script changes.
    git add -A
    git reset -- .github/workflows/ .github/scripts/ 2>/dev/null || true

    if ! git diff --cached --quiet; then
      # Keep a single commit in the filesystem branch by amending the existing commit.
      if git rev-parse --verify HEAD >/dev/null 2>&1; then
        git commit --amend --no-edit || true
      else
        git commit -m "autosave $(date -u +%Y%m%dT%H%M%SZ)" || true
      fi

      # Push filesystem branch for the current commit.
      push_filesystem || true
    fi
  ) 200>/tmp/tmate_autosave.lock
}

autosave &
autosave_pid=$!

periodic_save() {
  while true; do
    # Keep the local branch in sync with remote if it was updated elsewhere
    sync_from_remote
    sleep 5
    echo "[periodic autosave]"
    commit_and_push
  done
}

periodic_save &
periodic_save_pid=$!

if [ -f startup.sh ]; then
  echo "startup.sh exists; running it before starting tmate"
  chmod +x startup.sh
  bash startup.sh &
fi

# Start tmate in a loop so we can restart it automatically if the session ends.
# This makes reconnecting stable even after "exit".
while true; do
  tmate -S /tmp/tmate.sock new-session -d "bash --rcfile $HOME/.bashrc -i"
  # Keep the tmux session alive after the shell exits so clients can reconnect.
  tmate -S /tmp/tmate.sock set-option -g remain-on-exit on

  # Wait for tmate to generate session URLs (can take a short moment)
  until tmate_ssh=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}') && [ -n "$tmate_ssh" ]; do
    sleep 0.2
  done

  until tmate_web=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}') && [ -n "$tmate_web" ]; do
    sleep 0.2
  done

  # Also write a host.conf file containing only the host string, so it can be fetched via gh api.
  printf '%s' "${tmate_ssh#ssh }" > host.conf

  source "$HOME/.bashrc"

  # echo "=== tmate connection ==="
  # echo "SSH: ${tmate_ssh}"
  # echo "WEB: ${tmate_web}"
  # echo "RUN (gh): ssh \"\$(gh api -H 'Accept: application/vnd.github.v3.raw' \"/repos/${GITHUB_REPOSITORY}/contents/host.conf?ref=filesystem\" | tr -d '\r\n')\""
  # echo "========================"

  # Update README with the live session link(s)
  python3 "$RUNNER_SCRIPTS_DIR/scripts/update_readme.py" \
    --ssh "$tmate_ssh" \
    --web "$tmate_web" \
    --run-cmd "ssh \"\$(gh api -H 'Accept: application/vnd.github.v3.raw' \"/repos/${GITHUB_REPOSITORY}/contents/host.conf?ref=filesystem\" | tr -d '\r\n')\""

  # Wait until tmate session is gone, then restart it
  while tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}' >/dev/null 2>&1; do
    sleep 2
  done

  echo "tmate session ended; restarting..."
done