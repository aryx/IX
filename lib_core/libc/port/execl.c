/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* execl, over exec: the arguments are counted, then copied in an
 * array (a va_list is walked once). */

int
execl(char *prog, ...)
{
	int i;
	va_list arg;
	char **argv;

	va_start(arg, prog);
	for(i = 0; va_arg(arg, char*) != nil; i++)
		;
	va_end(arg);

	argv = malloc((i+1)*sizeof(char*));
	if(argv == nil)
		return -1;

	va_start(arg, prog);
	for(i = 0; (argv[i] = va_arg(arg, char*)) != nil; i++)
		;
	va_end(arg);

	exec(prog, argv);
	free(argv);
	return -1;
}
