#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v gh >/dev/null || { echo 'GitHub CLI(gh)가 필요합니다.'; exit 1; }
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
owner=$(gh api user --jq .login)
repo="${1:-musinsa-running-review-slides}"
if [[ ! -d .git ]]; then
  git init -b main
fi
if [[ -z "$(git config user.name || true)" ]]; then git config user.name "$owner"; fi
if [[ -z "$(git config user.email || true)" ]]; then git config user.email "$owner@users.noreply.github.com"; fi
git add index.html report.html assets data speaker-notes.md README.md .github .gitignore deploy.sh image-prompts.json
git diff --cached --quiet || git commit -m "Publish running review EDA presentation"
if ! git remote get-url origin >/dev/null 2>&1; then
  # A fresh public repository contains only this presentation and its published data.
  gh repo create "$owner/$repo" --public --source . --remote origin
fi
gh auth setup-git
git push -u origin main
full_repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
if gh api "repos/$full_repo/pages" >/dev/null 2>&1; then
  gh api --method PUT "repos/$full_repo/pages" -f build_type=workflow >/dev/null
else
  gh api --method POST "repos/$full_repo/pages" -f build_type=workflow >/dev/null
fi
gh workflow run pages.yml
run_id=""
for attempt in 1 2 3 4 5; do
  run_id=$(gh run list --workflow pages.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty')
  [[ -n "$run_id" ]] && break
  sleep 2
done
if [[ -n "$run_id" ]]; then gh run watch "$run_id" --exit-status; fi
gh api "repos/$full_repo/pages" --jq .html_url
