#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The commit's guard (docs/plans/plan_tests.md, step 6), git's
# pre-commit hook (tests/hooks/pre-commit, by make hooks): the files
# modified, deleted or new in the directories a commit touches, and not
# in it. make test tests the working tree; a commit that needs one of
# those passes it and breaks CI. Another session's work in progress is
# listed too: the guard says, it does not stop the commit.
# In the hook, the index is the commit's, git commit -- paths's too
# (git's temporary index): what differs from it is what is left out.
# usage: tests/guard.sh

cd "$(git rev-parse --show-toplevel)" || exit 0
dirs=$(git diff --cached --name-only --no-renames | xargs -r dirname | sort -u)
[ -n "$dirs" ] || exit 0
left=$({ git diff --name-only; git ls-files --others --exclude-standard; } |
  sort -u | while read -r f; do
    grep -qxF "$(dirname "$f")" <<< "$dirs" && echo "$f"
  done)
[ -n "$left" ] || exit 0
{
  echo "guard: in the directories this commit touches, and not in it:"
  git status --short -- $left | head -20 | sed 's/^/  /'
  n=$(echo "$left" | wc -l)
  [ $n -gt 20 ] && echo "  ... ($n files)"
  echo "(add those the commit needs: CI tests the commit, make test the tree)"
} >&2
exit 0
