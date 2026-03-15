#!/usr/bin/env python3
"""
GitHub Repository Creator with Branch Protection, Rulesets & Conventional Commits.

Creates a GitHub repo with:
- Auto-init (README, .gitignore, license)
- Branch protection (required reviews, status checks)
- Branch naming regex via Repository Rulesets
- Conventional commits enforcement via GitHub Actions workflow

Requirements:
    pip install requests pyyaml

Usage:
    # Set your token
    export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

    # Run with defaults
    python github_repo_creator.py --name my-new-repo

    # Full options
    python github_repo_creator.py \
        --name my-new-repo \
        --org my-org \
        --description "My awesome repo" \
        --private \
        --license mit \
        --gitignore Python \
        --default-branch main \
        --required-reviewers 2 \
        --branch-pattern "^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\\.[0-9]+\\.[0-9]+)$"
"""

import argparse
import base64
import json
import os
import sys
import textwrap
from typing import Optional

import requests

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
GITHUB_API = "https://api.github.com"

CONVENTIONAL_COMMIT_WORKFLOW = textwrap.dedent("""\
    name: Conventional Commits Check

    on:
      pull_request:
        types: [opened, synchronize, reopened, edited]

    permissions:
      pull_requests: read
      statuses: write

    jobs:
      check-commits:
        name: Validate Conventional Commits
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
            with:
              fetch-depth: 0

          - name: Check commit messages
            run: |
              PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\\(.+\\))?!?:\\s.+'
              FAILED=0
              while IFS= read -r sha; do
                MSG=$(git log --format='%s' -n1 "$sha")
                if ! echo "$MSG" | grep -qE "$PATTERN"; then
                  echo "❌ Non-conventional commit: $MSG ($sha)"
                  FAILED=1
                fi
              done < <(git log --format='%H' origin/${{ github.base_ref }}..${{ github.event.pull_request.head.sha }})

              if [ "$FAILED" -eq 1 ]; then
                echo ""
                echo "Commits must follow Conventional Commits: https://www.conventionalcommits.org"
                echo "Format: <type>(<optional scope>): <description>"
                echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
                exit 1
              fi
              echo "✅ All commits follow Conventional Commits"
""")


# ---------------------------------------------------------------------------
# GitHub API helpers
# ---------------------------------------------------------------------------
class GitHubClient:
    """Thin wrapper around the GitHub REST API."""

    def __init__(self, token: str):
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            }
        )

    def _request(self, method: str, path: str, **kwargs) -> dict:
        url = f"{GITHUB_API}{path}" if path.startswith("/") else path
        resp = self.session.request(method, url, **kwargs)
        if resp.status_code >= 400:
            print(f"❌ {method} {path} → {resp.status_code}")
            print(json.dumps(resp.json(), indent=2))
            sys.exit(1)
        return resp.json() if resp.content else {}

    # -- Repo --
    def create_repo(
        self,
        name: str,
        org: Optional[str] = None,
        description: str = "",
        private: bool = True,
        auto_init: bool = True,
        gitignore_template: str = "",
        license_template: str = "",
        default_branch: str = "main",
    ) -> dict:
        path = f"/orgs/{org}/repos" if org else "/user/repos"
        payload = {
            "name": name,
            "description": description,
            "private": private,
            "auto_init": auto_init,
            "default_branch": default_branch,
        }
        if gitignore_template:
            payload["gitignore_template"] = gitignore_template
        if license_template:
            payload["license_template"] = license_template

        print(f"📦 Creating repo '{name}' ({'org: ' + org if org else 'personal'})...")
        return self._request("POST", path, json=payload)

    # -- Branch protection --
    def set_branch_protection(
        self,
        owner: str,
        repo: str,
        branch: str = "main",
        required_reviewers: int = 1,
        dismiss_stale_reviews: bool = True,
        require_status_checks: Optional[list[str]] = None,
        enforce_admins: bool = True,
        require_linear_history: bool = True,
    ) -> dict:
        path = f"/repos/{owner}/{repo}/branches/{branch}/protection"
        payload = {
            "required_pull_request_reviews": {
                "required_approving_review_count": required_reviewers,
                "dismiss_stale_reviews": dismiss_stale_reviews,
            },
            "enforce_admins": enforce_admins,
            "required_linear_history": require_linear_history,
            "restrictions": None,
            "required_status_checks": None,
        }
        if require_status_checks:
            payload["required_status_checks"] = {
                "strict": True,
                "checks": [{"context": c} for c in require_status_checks],
            }

        print(f"🛡️  Setting branch protection on '{branch}'...")
        return self._request("PUT", path, json=payload)

    # -- Rulesets (branch naming pattern) --
    def create_branch_naming_ruleset(
        self,
        owner: str,
        repo: str,
        pattern: str,
        ruleset_name: str = "branch-naming-convention",
    ) -> dict:
        path = f"/repos/{owner}/{repo}/rulesets"
        payload = {
            "name": ruleset_name,
            "target": "branch",
            "enforcement": "active",
            "conditions": {
                "ref_name": {
                    "include": ["~ALL"],
                    "exclude": [],
                }
            },
            "rules": [
                {
                    "type": "branch_name_pattern",
                    "parameters": {
                        "name": "branch naming convention",
                        "negate": False,
                        "operator": "regex",
                        "pattern": pattern,
                    },
                }
            ],
        }
        print(f"📐 Creating branch naming ruleset (regex: {pattern})...")
        return self._request("POST", path, json=payload)

    # -- File creation (for the GH Actions workflow) --
    def create_file(
        self,
        owner: str,
        repo: str,
        path: str,
        content: str,
        message: str = "chore: add file via API",
        branch: str = "main",
    ) -> dict:
        api_path = f"/repos/{owner}/{repo}/contents/{path}"
        payload = {
            "message": message,
            "content": base64.b64encode(content.encode()).decode(),
            "branch": branch,
        }
        print(f"📄 Creating file '{path}'...")
        return self._request("PUT", api_path, json=payload)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Create a GitHub repo with protection rules, rulesets & conventional commits."
    )
    p.add_argument("--name", required=True, help="Repository name")
    p.add_argument("--org", default=None, help="GitHub org (omit for personal repo)")
    p.add_argument("--description", default="", help="Repo description")
    p.add_argument(
        "--private",
        action="store_true",
        default=True,
        help="Private repo (default: True)",
    )
    p.add_argument("--public", action="store_true", help="Make repo public")
    p.add_argument("--license", default="mit", help="License template (default: mit)")
    p.add_argument(
        "--gitignore", default="", help="Gitignore template (e.g. Python, Node)"
    )
    p.add_argument(
        "--default-branch", default="main", help="Default branch (default: main)"
    )
    p.add_argument(
        "--required-reviewers",
        type=int,
        default=1,
        help="Required PR reviewers (default: 1)",
    )
    p.add_argument(
        "--enforce-admins",
        dest="enforce_admins",
        action="store_true",
        default=True,
        help="Enforce rules for admins too (default: enabled)",
    )
    p.add_argument(
        "--no-enforce-admins",
        dest="enforce_admins",
        action="store_false",
        help="Do not enforce rules for admins",
    )
    p.add_argument(
        "--require-linear-history",
        dest="require_linear_history",
        action="store_true",
        default=True,
        help="Require linear history (no merge commits) (default: enabled)",
    )
    p.add_argument(
        "--no-require-linear-history",
        dest="require_linear_history",
        action="store_false",
        help="Do not require linear history (allow merge commits)",
    )
    p.add_argument(
        "--branch-pattern",
        default=r"^(main|develop|feature\/[a-z0-9._-]+|bugfix\/[a-z0-9._-]+|hotfix\/[a-z0-9._-]+|release\/[0-9]+\.[0-9]+\.[0-9]+)$",
        help="Regex for allowed branch names (like GitLab push rules)",
    )
    p.add_argument(
        "--status-checks",
        nargs="*",
        default=["check-commits"],
        help="Required status checks (default: check-commits for conventional commits)",
    )
    p.add_argument(
        "--skip-conventional-commits",
        action="store_true",
        help="Skip conventional commits workflow",
    )
    p.add_argument(
        "--skip-branch-naming", action="store_true", help="Skip branch naming ruleset"
    )
    p.add_argument(
        "--token", default=None, help="GitHub token (or set GITHUB_TOKEN env var)"
    )

    args = p.parse_args()
    if args.public:
        args.private = False
    return args


def main():
    args = parse_args()

    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("❌ Set GITHUB_TOKEN env var or pass --token")
        sys.exit(1)

    gh = GitHubClient(token)

    # 1. Create repo
    repo = gh.create_repo(
        name=args.name,
        org=args.org,
        description=args.description,
        private=args.private,
        auto_init=True,
        gitignore_template=args.gitignore,
        license_template=args.license,
        default_branch=args.default_branch,
    )
    owner = repo["owner"]["login"]
    repo_name = repo["name"]
    print(f"✅ Repo created: {repo['html_url']}")

    # 2. Add conventional commits workflow
    if not args.skip_conventional_commits:
        gh.create_file(
            owner=owner,
            repo=repo_name,
            path=".github/workflows/conventional-commits.yml",
            content=CONVENTIONAL_COMMIT_WORKFLOW,
            message="ci: add conventional commits validation workflow",
            branch=args.default_branch,
        )
        print("✅ Conventional commits workflow added")

    # 3. Branch protection
    gh.set_branch_protection(
        owner=owner,
        repo=repo_name,
        branch=args.default_branch,
        required_reviewers=args.required_reviewers,
        enforce_admins=args.enforce_admins,
        require_linear_history=args.require_linear_history,
        require_status_checks=args.status_checks,
    )
    print("✅ Branch protection configured")

    # 4. Branch naming ruleset
    if not args.skip_branch_naming:
        gh.create_branch_naming_ruleset(
            owner=owner,
            repo=repo_name,
            pattern=args.branch_pattern,
        )
        print("✅ Branch naming ruleset created")

    print(f"\n🎉 Done! Repo ready at: {repo['html_url']}")
    print("\nConfigured rules:")
    print(
        f"  • Branch protection on '{args.default_branch}' ({args.required_reviewers} reviewer(s))"
    )
    print(f"  • Linear history required: {args.require_linear_history}")
    if not args.skip_conventional_commits:
        print("  • Conventional commits enforced via GitHub Actions")
    if not args.skip_branch_naming:
        print(f"  • Branch naming regex: {args.branch_pattern}")


if __name__ == "__main__":
    main()
