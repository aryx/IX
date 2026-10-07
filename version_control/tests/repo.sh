#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A repository for objects.sh and net.sh, made by C git in DIR: not
# ix's own (a test reads no .git but one it made; Docker's checkout has
# none). What a real one has, in some 40 commits: mini-git's sources added
# one by one, a file that grows by a line each time and a big one
# changed in a line (the deltas of a pack), directories, an empty file,
# a binary one, an executable, a symbolic link, a file renamed and one
# removed, a branch merged, a tag with its message.
#
# Usage: repo.sh DIR

set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D=$1
export GIT_AUTHOR_NAME=Glenda GIT_AUTHOR_EMAIL=glenda@9front.org GIT_COMMITTER_NAME=Glenda GIT_COMMITTER_EMAIL=glenda@9front.org
git -c init.defaultBranch=master init -q "$D"
cd "$D"
n=0
commit() {
  n=$((n + 1))
  git add -A
  GIT_AUTHOR_DATE="$((1600000000 + n * 3600)) +0000" GIT_COMMITTER_DATE="$((1600000000 + n * 3600)) +0000" git commit -q -m "$1"
}

echo "A repository for mini-git's tests." > README.md
commit "the README"
mkdir src
for f in "$ROOT"/version_control/*.ml; do
  cp "$f" src/
  echo "$(basename "$f")" >> history.txt
  cat "$f" >> all.ml
  commit "add $(basename "$f")"
done
for i in 1 2 3; do
  sed -i "${i}00s/.*/(* change $i *)/" all.ml
  commit "all.ml, change $i"
done
mkdir -p tests/deep/deeper
: > tests/empty
gzip -n -c all.ml > tests/deep/all.ml.gz
cp "$ROOT/version_control/tests/objects.sh" tests/deep/deeper/objects.sh
chmod +x tests/deep/deeper/objects.sh
ln -s README.md link
commit "an empty file, a binary one, an executable, a link"
git mv src/Main.ml src/Start.ml
git rm -q src/Hash.ml
commit "a file renamed, one removed"
git checkout -q -b side HEAD~2
echo "on the side" > side.txt
commit "a commit on the side"
git checkout -q master
echo "after the branch" >> history.txt
commit "a commit on master"
n=$((n + 1))
GIT_AUTHOR_DATE="$((1600000000 + n * 3600)) +0000" GIT_COMMITTER_DATE="$((1600000000 + n * 3600)) +0000" git merge -q --no-ff -m "the side merged" side
git branch -q -d side
GIT_COMMITTER_DATE="$((1600000000 + n * 3600)) +0000" git tag -a -m "the first version" v1
