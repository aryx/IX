/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* A Dir for dirwstat that changes nothing: all ones in a field say
 * "leave it" (os/'s dirfwstat looks at each); the caller then sets
 * the fields to change. */
void
nulldir(Dir *d)
{
	memset(d, ~0, sizeof(Dir));
	d->name = d->uid = d->gid = d->muid = "";
}
