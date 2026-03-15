# reverse-action — Turn a GitHub repo into a free VPS-like runner

This repository turns a GitHub Actions workflow into an **interactive SSH server** (a mini-VPS) with **persistent state** across runs using a dedicated Git branch: **`filesystem`**.

## 🏁 Quick start (using this as a template)

1. Click **Use this template** and create a **new private repo**. This should trigger the workflow and start a tmate session (if not, trigger it manually from the Actions tab).
2. Once the job starts, open the latest run and follow the tmate session links (the README will be updated automatically).

> ⚠️ Recommended: keep the repo private, since this exposes an interactive shell on a GitHub runner.

## 🚀 Key idea: a tmate session that survives runs

GitHub Actions normally runs disposable jobs. Here we combine:

- **tmate** for an interactive shell (SSH + web terminal)
- a **Git branch (`filesystem`)** to persist filesystem state across runs
- a **GitHub Actions workflow** that restores state, starts remote access, and records changes

➡️ The result: a reusable remote environment that can resume from a previous session like a VPS.

---

## 🧠 How it works (simplified architecture)

1. **The workflow starts** (via manual dispatch or scheduled trigger).
2. `start-tmate.sh` restores state from the `filesystem` branch (if it exists), or creates an empty branch.
3. The script starts `tmate`, prints SSH/web links, and updates `README.md`.
4. During the session, all modifications are automatically committed/pushed to the `filesystem` branch.

---

## 🗂️ `filesystem` branch: your persistent disk

The `filesystem` branch holds the current session state: files, installs, configs, etc.

- It is pushed on every automatic save.
- The workflow always starts from its latest state.
- You can reset / inspect it using Git (`git checkout filesystem`, `git log`, etc.).

### 🧩 Resetting `filesystem` to a clean state

You can force the `filesystem` branch from another ref (e.g. `main`):

```bash
# Reset filesystem from main and push
git checkout main
git checkout -B filesystem
git push -f origin filesystem
```

---

## 🛠️ What’s in this repo?

- `./.github/workflows/ssh.yml`: main workflow that starts the tmate session
- `./.github/scripts/start-tmate.sh`: restores `filesystem`, starts `tmate`, and handles saving
- `./.github/scripts/update_readme.py`: updates this README with live session links

---

## 🔐 Security & responsible use

This setup exposes a remote shell on a GitHub runner (private depending on the repo). Don’t share it publicly, and stop the workflow when you’re done.

---

## ✨ Summary

This repo turns a GitHub Actions workflow into a **mini-VPS**:

- live SSH / web shell via `tmate`
- persistent state via the `filesystem` branch
- easy restore: the session always resumes where it left off

Ready to use for exploring, developing, or debugging in a temporary Linux environment that can be restored at any time.
