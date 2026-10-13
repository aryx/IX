/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Sys */
/*****************************************************************************/

static int argc;
static char **argv;

value
sys_exit(value n)
{
	exit(Long_val(n));
	return Val_unit;
}

value
sys_get_argv(value unit)
{
	value a, s;
	int i;

	a = make_vect(Val_int(argc), Val_unit);
	for(i = 0; i < argc; i++){
		push(a);
		s = ml_string(argv[i]);
		a = pop();
		Field(a, i) = s;
	}
	return a;
}

value
sys_get_config(value unit)
{
	value r, s;

	/* Sys.os_type: OCaml's "Unix" on Linux
	 * (old: "Plan9" on both, the libc's) */
	s = ml_string("Unix");
	push(s);
	r = ml_alloc(2, 0);
	s = pop();
	Field(r, 0) = s;
	Field(r, 1) = Val_int(8 * W);
	return r;
}

value
sys_getenv(value name)
{
	char *v;

	v = getenv((char*)Bytes(name));
	if(v == nil)
		raise_const(caml_exn_Not_found);
	return ml_string(v);
}

/* Linux's calls, by their number (ux): arm64's, or arm's. A path is
 * from the process's directory (AT_FDCWD) */
#define SYS(n64, n32) (W == 8 ? (n64) : (n32))
#define Cwd (-100)

/* ocaml-light's open_flag, in its order: a constant constructor's number */
enum { Open_rdonly, Open_wronly, Open_append, Open_creat, Open_trunc, Open_excl };

/* openat, the flags Linux's own (O_WRONLY 1, O_CREAT 0100, O_EXCL
 * 0200, O_TRUNC 01000, O_APPEND 02000). Open_append alone writes too:
 * OCaml's flag for it is O_APPEND | O_WRONLY. (lib_core's runtime
 * opens as Plan 9 does, a seek to the end for an append.) */
value
sys_open(value name, value flags, value perm)
{
	value fd, set, mode;

	set = 0;
	for(; !Is_int(flags); flags = Field(flags, 1))
		set |= 1 << Long_val(Field(flags, 0));
	mode = (set & (1 << Open_wronly | 1 << Open_append)) ? 1 : 0;
	if(set & 1 << Open_append)
		mode |= 02000;
	if(set & 1 << Open_creat)
		mode |= 0100;
	if(set & 1 << Open_trunc)
		mode |= 01000;
	if(set & 1 << Open_excl)
		mode |= 0200;
	fd = ux(SYS(56, 322), Cwd, name, mode, Long_val(perm), 0, 0);
	if(fd < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_int(fd);
}

value
sys_close(value fd)
{
	close(Long_val(fd));
	return Val_unit;
}

/* 0 a file, 1 a directory, -1 nothing: fstatat, the mode's four bytes
 * at 16 of the kernel's structure (arm64's stat, arm's stat64) */
static int
file_kind(value name)
{
	char st[256];

	if(ux(SYS(79, 327), Cwd, name, (value)st, 0, 0, 0) < 0)
		return -1;
	return (*(int*)(st + 16) & 0170000) == 0040000;
}

value sys_file_exists(value name) { return Val_bool(file_kind(name) >= 0); }

value
sys_is_directory(value name)
{
	int k;

	k = file_kind(name);
	if(k < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_bool(k);
}

/* a file, or an empty directory (Sys.rmdir too): unlinkat, again with
 * AT_REMOVEDIR (0x200) when it says a directory (-21, EISDIR) */
value
sys_remove(value name)
{
	value r;

	r = ux(SYS(35, 328), Cwd, name, 0, 0, 0, 0);
	if(r == -21)
		r = ux(SYS(35, 328), Cwd, name, 0x200, 0, 0, 0);
	if(r < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_unit;
}

/* renameat (lib_core's runtime renames in one directory only, as Plan 9) */
value
sys_rename(value from, value to)
{
	if(ux(SYS(38, 329), Cwd, from, Cwd, to, 0, 0) < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(from));
	return Val_unit;
}

value
sys_getcwd(value unit)
{
	char buf[1024];

	if(ux(SYS(17, 183), (value)buf, sizeof buf, 0, 0, 0, 0) < 0)
		raise_with(caml_exn_Sys_error, "getcwd");
	return ml_string(buf);
}

/* A directory's names, without . and ..: getdents64's records (the
 * length at 16, two bytes; the name from 19), counted, then read
 * again from the start into the array. */
static value
dir_names(value fd, value a)
{
	char buf[4096], *p, *name;
	value n, k, s;

	k = 0;
	ux(SYS(62, 19), fd, 0, 0, 0, 0, 0);
	while((n = ux(SYS(61, 217), fd, (value)buf, sizeof buf, 0, 0, 0)) > 0)
		for(p = buf; p < buf + n; p += *(ushort*)(p + 16)){
			name = p + 19;
			if(name[0] == '.' && (name[1] == 0 || (name[1] == '.' && name[2] == 0)))
				continue;
			if(a != Val_unit && k < (value)Wosize(a)){
				push(a);
				s = ml_string(name);
				a = pop();
				Field(a, k) = s;
			}
			k++;
		}
	return a == Val_unit ? k : a;
}

value
sys_read_directory(value name)
{
	value fd, n, a;

	fd = ux(SYS(56, 322), Cwd, name, 0, 0, 0, 0);
	if(fd < 0 || ux(SYS(61, 217), fd, 0, 0, 0, 0, 0) == -20){	/* (-20, ENOTDIR) */
		if(fd >= 0)
			close(fd);
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	}
	n = dir_names(fd, Val_unit);
	a = make_vect(Val_int(n), Val_unit);
	a = dir_names(fd, a);
	close(fd);
	return a;
}

/* Signals. A handler is OCaml's (Sys.signal's function), and C can't
 * call it: here a signal is only noted, and the stdlib runs the
 * handlers of those noted where a program waits, when a read or a
 * system call comes back interrupted (Pervasives' run_signals). So a
 * handler runs between two instructions of OCaml's, never in the
 * middle of the collector; and not in a computation that asks nothing
 * of the system, where OCaml would run it at an allocation. */
static void
note_signal(int sig)
{
	/* an interrupt again, the first one's handler not run yet: the
	 * program computes and waits nowhere, so the system's default, its
	 * end (exit_group, 130 as a shell says it) */
	if(sig == 2 && signalled[sig])
		ux(W == 8 ? 94 : 248, 130, 0, 0, 0, 0, 0);
	signalled[sig] = 1;
	signalled[0] = 1;
}

/* rt_sigaction, by its number: the handler, no flag (a system call
 * interrupted says so, and is not started again), no mask */
static void
set_signal(int sig, int how)
{
	value act[5];	/* handler, flags, restorer, and a mask of 64 bits */

	act[0] = how == 0 ? 0 : how == 1 ? 1 : (value)note_signal;
	act[1] = act[2] = act[3] = act[4] = 0;
	ux(W == 8 ? 134 : 174, sig, (value)act, 0, 8, 0, 0);
}

/* how: 0 the system's default, 1 ignored, 2 noted */
value
ml_signal(value sig, value how)
{
	set_signal(Long_val(sig), Long_val(how));
	return Val_unit;
}

/* a signal noted, forgotten here, or 0 */
value
ml_signal_pending(value unit)
{
	int s;

	if(!signalled[0])	/* none: asked after each system call (Unix's check) */
		return Val_int(0);
	signalled[0] = 0;	/* before the look: a signal coming meanwhile sets it again */
	for(s = 1; s < 65; s++)
		if(signalled[s]){
			signalled[s] = 0;
			signalled[0] = 1;
			return Val_int(s);
		}
	return Val_int(0);
}
