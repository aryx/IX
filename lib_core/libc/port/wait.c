/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* wait: Plan 9's, which gives a Waitmsg, over Linux's wait4. The
 * message is "" for a child that left with 0, its status otherwise, or
 * "signal n" (the bits are <sys/wait.h>'s, written here: no such
 * header). The times are left at 0: nothing reads them. */

#define WIFEXITED(status)	(((status) & 0x7f) == 0)
#define WEXITSTATUS(status)	(((status) >> 8) & 0xff)
#define WIFSIGNALED(status)	(((status) & 0x7f) != 0 && ((status) & 0x7f) != 0x7f)
#define WTERMSIG(status)	((status) & 0x7f)

extern int _syswait4(int pid, void *status, int options, void *rusage);

static Waitmsg*
_wait1(int pid, int opt)
{
	Waitmsg *w;
	int status, r;

	w = mallocz(sizeof(Waitmsg) + 64, 1);
	if(w == nil)
		return nil;
	w->msg = (char*)&w[1];

	status = 0;
	r = _syswait4(pid, &status, opt, nil);
	if(r < 0){
		free(w);
		return nil;
	}
	w->pid = r;
	if(WIFEXITED(status)){
		if(WEXITSTATUS(status))
			sprint(w->msg, "%d", WEXITSTATUS(status));
	}else if(WIFSIGNALED(status))
		sprint(w->msg, "signal %d", WTERMSIG(status));
	return w;
}

Waitmsg*
wait(void)
{
	return _wait1(-1, 0);
}
