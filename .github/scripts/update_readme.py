#!/usr/bin/env python3
"""Update README.md with live tmate session links.

This script is designed to be called from a GitHub Actions workflow.
It inserts or updates a block between markers in README.md:

<!-- TMATE-SESSION-START -->
## Live tmate session

- SSH: ...
- Web: ...
<!-- TMATE-SESSION-END -->

Usage:
  python update_readme.py --ssh <ssh-url> --web <web-url>

If README.md does not exist, it is created with a default title.
"""

import argparse
import os
import re
from pathlib import Path


def main(argv=None):
    parser = argparse.ArgumentParser(description="Update README with tmate session links")
    parser.add_argument("--ssh", required=True, help="tmate ssh connection string")
    parser.add_argument("--web", required=True, help="tmate web connection URL")
    parser.add_argument("--run-cmd", required=False, help="Optional command to run to connect (e.g. gh api ... | sh)")
    parser.add_argument("--readme", default="README.md", help="Path to README file")
    args = parser.parse_args(argv)

    repo = os.getenv("GITHUB_REPOSITORY", "")

    # Derived host-fetch command for private repo access
    host_cmd = None
    if repo:
        host_cmd = (
            "ssh \"$(gh api -H 'Accept: application/vnd.github.v3.raw' "
            f"\"/repos/{repo}/contents/host.conf?ref=filesystem\" | tr -d '\\r\\n')\""
        )

    path = Path(args.readme)
    if not path.exists():
        path.write_text("# Workspace\n")

    text = path.read_text()

    block = ""
    block += "<!-- TMATE-SESSION-START -->\n"
    block += "## Live tmate session\n\n"
    block += f"- SSH: `{args.ssh}`\n"
    block += f"- Web: `{args.web}`\n"

    cmd = args.run_cmd or host_cmd
    if cmd:
        block += f"- Run: `{cmd}`\n"

        block += (
            "\n"
            "### Connect via GitHub CLI\n\n"
            "1. Install GitHub CLI: https://cli.github.com/\n"
            "2. Authenticate: `gh auth login`\n"
            "3. Run:\n\n"
            "```bash\n"
            f"{cmd}\n"
            "```\n"
        )

    block += "<!-- TMATE-SESSION-END -->\n"

    if re.search(r"<!-- TMATE-SESSION-START -->.*?<!-- TMATE-SESSION-END -->", text, flags=re.S):
        text = re.sub(
            r"<!-- TMATE-SESSION-START -->.*?<!-- TMATE-SESSION-END -->",
            block,
            text,
            flags=re.S,
        )
    else:
        text = text + "\n" + block + "\n"

    path.write_text(text)


if __name__ == "__main__":
    main()
