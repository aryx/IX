\title{git}{1}{devtools}

# NAME
git – a git repository, made and kept, as git9's

# SYNOPSIS
**git**
*command*
[ *arg* ... ]

# DESCRIPTION
*Git* is git9's programs, Plan 9's `git/`*command*, as the commands
of one program; the repository is git's own, `.git` with its loose
objects and packs, which Unix's git reads too. The commands:

`init`, `add`, `rm`, `walk`, `commit`, `revert`, `diff`, `log`,
`branch`, `merge`
:    The work tree and its history: `walk` says what changed (`M`,
     `A`, `R`...), `log -s` a commit a line.

`clone`, `pull`, `push`, `get`, `send`, `serve`
:    Another repository, a path or a `git://` or `https://` URL.

`query`, `conf`, `fs`, `save`, `repack`
:    git9's plumbing: a revision's hash (`query HEAD~2`), the
     configuration, the repository's paths, a commit made of a tree.

A command's own options are git9's: `git log -?` writes its usage.

# EXAMPLES
```
git init repo; cd repo; echo hello > a.txt
git add a.txt
git commit -m first a.txt
echo hi >> a.txt; git walk
git diff
git log -s
```

# DIFFERENCES
Plan 9's git is git9 (Ori Bernstein's), which this follows: `git log`
for `git/log`, its scripts made commands. `git/fs` is not mounted:
`.git/fs`'s paths are read without it. No `compat`, `export`,
`import`, `rebase` nor `hist`.

# SEE ALSO
\man{diff}{1}, \man{merge3}{1}; Plan 9's *git*(1), for each
command's options

# DIAGNOSTICS
A fatal error writes `git/`*command*`: `*message*, and the status
is 1.

# BUGS
`git clone repo copy`, a relative path, cannot clone: an absolute
one can.
