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
#ifdef plan9
	/* Plan 9's exec: no environment given (it is /env's files) */
	USED(envp);
	return Val_int(exec((char*)path, ux_strings(argv)));
#else
	return Val_int(ux(W == 8 ? 221 : 11, path, (value)ux_strings(argv), (value)ux_strings(envp), 0, 0, 0));
#endif
}

/* A thread's memory (thread_new's) is the system's (mmap, by its
 * number), n bytes of zeros. Not the C library's: its malloc (goken's,
 * a placeholder) gives 64 MB in all and takes nothing back. */
static void*
m_alloc(value n)
{
#ifdef __GNUC__
	void *p;

	p = calloc(n, 1);
	if(p == nil)
		fatal("Fatal error: out of memory\n");
	return p;
#else
	value p;

#ifdef plan9
	/* Plan 9's: the break moved up (zeros, the kernel's), not given back */
	p = (value)sbrk(n);
	if(p == -1)
		fatal("Fatal error: out of memory\n");
#else
	p = ux(W == 8 ? 222 : 192, 0, n, 3, 0x22, -1, 0);
	if(p < 0 && p > -4096)
		fatal("Fatal error: out of memory\n");
#endif
	return (void*)p;
#endif
}
