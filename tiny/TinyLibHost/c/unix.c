/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Unix: a system call (Linux's) */
/*****************************************************************************/

/* The Unix module is OCaml (lib_core's Unix): each of its functions a
 * system call of Linux's, by its number, its structures packed and read
 * as bytes there. So here is only the call: nothing of a libc's, and
 * the same for goken's (its _syscall6) and for glibc (gnu.h's ux).
 * An argument is an int, a string or bytes (their address), or an
 * int32 or an int64 (their value: an int has 31 bits on arm). The
 * answer is the kernel's: a negative errno when it fails. */
static value
ux_arg(value v)
{
	if(Is_int(v))
		return Long_val(v);
	if(Tag(v) == Int32_tag)
		return Int32_val(v);
	if(Tag(v) == Int64_tag)
		return Int64_val(v);
	return v;
}

value
unix_syscall(value nr, value args)
{
	return Val_int(ux(Long_val(nr), ux_arg(Field(args, 0)), ux_arg(Field(args, 1)), ux_arg(Field(args, 2)),
		ux_arg(Field(args, 3)), ux_arg(Field(args, 4)), ux_arg(Field(args, 5))));
}

/* execve: its two arrays of strings, as C's, ended by nil */
static char**
ux_strings(value a)
{
	char **v;
	value i, n;

	n = Wosize(a);
	v = malloc((n + 1) * sizeof(char*));
	for(i = 0; i < n; i++)
		v[i] = (char*)Field(a, i);
	v[n] = nil;
	return v;
}

value
unix_execve(value path, value argv, value envp)
{
	return Val_int(ux(W == 8 ? 221 : 11, path, (value)ux_strings(argv), (value)ux_strings(envp), 0, 0, 0));
}
