#!/usr/bin/env bash
# Regenerate the contributions block in README.md from merged pull requests.
#
# The `is:public` qualifier is load-bearing. Without it the search returns every
# repo the token can read, which on a personal token includes private employer
# repos, and this file writes its output straight into a public profile.
#
# MINE drops my own repos and my own org: Current Projects already covers them,
# and counting them here would read as work done for someone else.
set -euo pipefail

AUTHOR=fajarhide
MINE='^(fajarhide|weekndlabs)/'
README="$(dirname "$0")/../README.md"
START='<!--START_SECTION:contributions-->'
END='<!--END_SECTION:contributions-->'

# The block goes through a file, not an awk -v variable: BSD awk on macOS
# rejects a multi-line string passed with -v.
block=$(mktemp)
trap 'rm -f "$block" "$README.tmp"' EXIT

gh search prs 'is:public' --author "$AUTHOR" --merged --limit 200 --json repository \
| jq -r --arg mine "$MINE" '
    [.[].repository.nameWithOwner | select(test($mine) | not)]
    | group_by(.)
    | map({repo: .[0], n: length})
    | sort_by(-.n, .repo)[]
    | "- [\(.repo)](https://github.com/\(.repo)) `\(.n) merged`"' > "$block"

# Zero results means the search ran but matched nothing, which is more likely a
# lost token scope than a real change. Keep the last good block.
if [ ! -s "$block" ]; then
  echo "no public external PRs found, leaving README alone" >&2
  exit 0
fi

awk -v f="$block" -v s="$START" -v e="$END" '
  index($0, s) { print; while ((getline line < f) > 0) print line; skip = 1; next }
  index($0, e) { skip = 0 }
  !skip
' "$README" > "$README.tmp" && mv "$README.tmp" "$README"

echo "contributions block updated:"
cat "$block"
