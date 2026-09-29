#!/usr/bin/env bash
# github-radar: cross-repo snapshot of the open PRs and issues that involve you.
# Emits a single JSON object on stdout. No state, fresh each run.
#
#   mine      - open PRs + issues in your own repos (<login>/*), any author
#   elsewhere - open PRs + issues in OTHER people's repos where you are
#               involved (author / assignee / mention / commenter / reviewer)
#
# Each PR carries reviewRequestedFromMe so the renderer can surface
# "waiting on your review" first. Requires: gh (authenticated), jq.
set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo '{"error":"gh CLI not found"}'; exit 0; }
command -v jq >/dev/null 2>&1 || { echo '{"error":"jq not found"}'; exit 0; }

login=$(gh api user --jq .login 2>/dev/null || true)
[ -z "${login:-}" ] && { echo '{"error":"gh not authenticated - run: gh auth login"}'; exit 0; }

limit=100
pr_fields="number,title,url,author,isDraft,repository,updatedAt,labels"
issue_fields="number,title,url,author,isPullRequest,repository,updatedAt,labels,assignees"

# Optional first arg = a single "owner/repo" to scope to. When given, the report
# covers just that repo (every open PR/issue, any author); "elsewhere" is unused.
repo_arg="${1:-}"

if [ -n "$repo_arg" ]; then
  scope="$repo_arg"
  mine_prs=$(gh search prs --repo="$repo_arg" --state=open --limit "$limit" --json "$pr_fields" 2>/dev/null || echo '[]')
  mine_issues=$(gh search issues --repo="$repo_arg" --state=open --limit "$limit" --json "$issue_fields" 2>/dev/null || echo '[]')
  inv_prs='[]'
  inv_issues='[]'
  review_prs=$(gh search prs --repo="$repo_arg" --review-requested=@me --state=open --limit "$limit" --json url 2>/dev/null || echo '[]')
else
  scope="account"
  mine_prs=$(gh search prs --owner="$login" --state=open --limit "$limit" --json "$pr_fields" 2>/dev/null || echo '[]')
  mine_issues=$(gh search issues --owner="$login" --state=open --limit "$limit" --json "$issue_fields" 2>/dev/null || echo '[]')
  inv_prs=$(gh search prs --involves=@me --state=open --limit "$limit" --json "$pr_fields" 2>/dev/null || echo '[]')
  inv_issues=$(gh search issues --involves=@me --state=open --limit "$limit" --json "$issue_fields" 2>/dev/null || echo '[]')
  review_prs=$(gh search prs --review-requested=@me --state=open --limit "$limit" --json url 2>/dev/null || echo '[]')
fi

stale_days="${RADAR_STALE_DAYS:-60}"

jq -n \
  --arg login "$login" \
  --arg scope "$scope" \
  --argjson stale_days "$stale_days" \
  --argjson mine_prs "$mine_prs" \
  --argjson mine_issues "$mine_issues" \
  --argjson inv_prs "$inv_prs" \
  --argjson inv_issues "$inv_issues" \
  --argjson review_prs "$review_prs" '
  ($review_prs | map(.url)) as $rr |
  def is_mine($u): ($u | startswith("https://github.com/" + $login + "/"));
  def is_auto($name; $title; $lbls):
    ($name // "" | ascii_downcase) as $a |
    ($a | endswith("[bot]")) or ($a | endswith("-bot")) or
    ($a | IN("copilot","dependabot","renovate","github-actions","mergify","sweep-ai","snyk-bot")) or
    (($lbls | map(ascii_downcase) | index("dependencies")) != null) or
    (($title // "") | test("^\\[(snyk|dependabot|renovate)\\]"; "i")) or
    (($title // "") | test("^(chore|build|fix)\\(deps"; "i"));
  def age_days: (((now - (.updatedAt | fromdateiso8601)) / 86400) | floor);
  def norm_pr:
    [(.labels // [])[].name] as $lbls | age_days as $age | {
    repo: .repository.nameWithOwner, number, title, url,
    author: (.author.login // "?"), automated: is_auto(.author.login; .title; $lbls), isDraft, updatedAt,
    ageDays: $age, stale: ($age > $stale_days),
    labels: $lbls,
    reviewRequestedFromMe: (.url | IN($rr[]))
  };
  def norm_issue:
    [(.labels // [])[].name] as $lbls | age_days as $age | {
    repo: .repository.nameWithOwner, number, title, url,
    author: (.author.login // "?"), automated: is_auto(.author.login; .title; $lbls), updatedAt,
    ageDays: $age, stale: ($age > $stale_days),
    labels: $lbls,
    assignees: [(.assignees // [])[].login]
  };
  {
    login: $login,
    scope: $scope,
    generatedAt: (now | todate),
    mine: {
      prs:    ($mine_prs    | map(norm_pr)),
      issues: ($mine_issues | map(select(.isPullRequest | not) | norm_issue))
    },
    elsewhere: {
      prs:    ($inv_prs    | map(norm_pr)    | map(select(is_mine(.url) | not))),
      issues: ($inv_issues | map(select(.isPullRequest | not) | norm_issue) | map(select(is_mine(.url) | not)))
    }
  }
  | .counts = {
      mine_prs_human:   (.mine.prs         | map(select((.automated | not) and (.stale | not))) | length),
      mine_prs_auto:    (.mine.prs         | map(select(.automated)) | length),
      mine_issues:      (.mine.issues      | map(select(.stale | not)) | length),
      else_prs:         (.elsewhere.prs    | map(select((.automated | not) and (.stale | not))) | length),
      else_issues:      (.elsewhere.issues | map(select(.stale | not)) | length),
      review_requested: ([.mine.prs[], .elsewhere.prs[]] | map(select(.reviewRequestedFromMe)) | length),
      stale_hidden:     ([.mine.prs[], .mine.issues[], .elsewhere.prs[], .elsewhere.issues[]] | map(select((.automated | not) and .stale)) | length),
      stale_days:       $stale_days
    }'
