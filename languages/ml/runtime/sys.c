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
#ifdef plan9
	s = ml_string("Plan9");
#else
	s = ml_string("Unix");
#endif
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

/* ocaml-light's open_flag, in its order: a constant constructor's number */
enum { Open_rdonly, Open_wronly, Open_append, Open_creat, Open_trunc, Open_excl };

/* A file opened as Plan 9's: open, which doesn't make it, then create,
 * which makes it (and empties it); with Open_excl, create alone, which
 * fails when the file is there. Open_append is a seek to the end, once:
 * not Unix's O_APPEND, each write at the end whoever else writes */
value
sys_open(value name, value flags, value perm)
{
	int fd, set, mode;
	char *s;

	s = (char*)Bytes(name);
	set = 0;
	for(; !Is_int(flags); flags = Field(flags, 1))
		set |= 1 << Long_val(Field(flags, 0));
	/* (Open_append alone writes too: OCaml's flag for it is O_APPEND | O_WRONLY) */
	mode = (set & (1 << Open_wronly | 1 << Open_append)) ? OWRITE : OREAD;
	fd = -1;
	if(!(set & 1 << Open_creat))
		fd = open(s, mode | ((set & 1 << Open_trunc) ? OTRUNC : 0));
	else if(set & 1 << Open_excl)
		fd = create(s, mode | OEXCL, Long_val(perm));
	else{
		fd = open(s, mode | ((set & 1 << Open_trunc) ? OTRUNC : 0));
		if(fd < 0)
			fd = create(s, mode, Long_val(perm));
	}
	if(fd < 0)
		raise_with(caml_exn_Sys_error, s);
	if(set & 1 << Open_append)
		seek(fd, 0, 2);
	return Val_int(fd);
}

value
sys_close(value fd)
{
	close(Long_val(fd));
	return Val_unit;
}

/* 0 a file, 1 a directory, -1 nothing */
static int
file_kind(value name)
{
	Dir *d;
	int k;

	d = dirstat((char*)Bytes(name));
	if(d == nil)
		return -1;
	k = (d->mode & DMDIR) != 0;
	free(d);
	return k;
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

/* a file, or an empty directory (Sys.rmdir too: Plan 9's remove) */
value
sys_remove(value name)
{
	if(remove((char*)Bytes(name)) < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_unit;
}

value
sys_mkdir(value name, value perm)
{
	int fd;

	fd = create((char*)Bytes(name), OREAD, DMDIR | Long_val(perm));
	if(fd < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	close(fd);
	return Val_unit;
}

#ifndef __GNUC__
/* Plan 9's rename: a file's name changed in its directory (dirwstat) */
static int
rename_in_dir(char *from, char *to, char *name)
{
	Dir d;

	USED(to);
	nulldir(&d);
	d.name = name;
	return dirwstat(from, &d);
}

/* sh -c cmd, waited for: its exit status, 255 for a signal */
static int
shell(char *cmd)
{
#ifdef plan9
	/* Plan 9's: rc, and await's line (the pid, three times, the
	 * child's last word: empty when all went well), read here: the
	 * libc's wait wants its tokenize and runes for it */
	char buf[256], *s;
	int pid, n, i;

	pid = fork();
	if(pid == 0){
		execl("/bin/rc", "rc", "-c", cmd, nil);
		exits("exec");
	}
	if(pid < 0)
		return 127;
	for(;;){
		n = await(buf, sizeof buf - 1);
		if(n < 0)
			return 127;
		buf[n] = 0;
		if(atoi(buf) != pid)
			continue;
		s = buf;
		for(i = 0; i < 4 && s != nil; i++){
			s = strchr(s, ' ');
			if(s != nil)
				s++;
		}
		if(s == nil || s[0] == 0 || (s[0] == '\'' && s[1] == '\''))
			return 0;
		return s[0] >= '0' && s[0] <= '9' ? atoi(s) : 255;
	}
#else
	Waitmsg *w;
	int pid, st;

	pid = fork();
	if(pid == 0){
		execl("/bin/sh", "sh", "-c", cmd, nil);
		exits("exec");
	}
	if(pid < 0)
		return 127;
	do{
		w = wait();
		if(w == nil)
			return 127;
		st = w->msg[0] == 0 ? 0 : w->msg[0] >= '0' && w->msg[0] <= '9' ? atoi(w->msg) : 255;
		st = w->pid == pid ? st : -1;
		free(w);
	}while(st < 0);
	return st;
#endif
}
#endif

/* the two names in one directory: Plan 9 has no other rename, and a
 * file moved to another directory is copied */
value
sys_rename(value from, value to)
{
	char *f, *t, *fb, *tb;

	f = (char*)Bytes(from);
	t = (char*)Bytes(to);
	fb = strrchr(f, '/');
	tb = strrchr(t, '/');
	fb = fb == nil ? f : fb + 1;
	tb = tb == nil ? t : tb + 1;
	if(fb - f != tb - t || strncmp(f, t, fb - f) != 0 || rename_in_dir(f, t, tb) < 0)
		raise_with(caml_exn_Sys_error, f);
	return Val_unit;
}

value
sys_getcwd(value unit)
{
	char buf[1024];

	if(getwd(buf, sizeof buf) == nil)
		raise_with(caml_exn_Sys_error, "getcwd");
	return ml_string(buf);
}

/* a directory's names, without . and .. */
value
sys_read_directory(value name)
{
	Dir *d;
	value a, s;
	long n, i;
	int fd;

	fd = open((char*)Bytes(name), OREAD);
	n = fd < 0 ? -1 : dirreadall(fd, &d);
	if(fd >= 0)
		close(fd);
	if(n < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	a = make_vect(Val_int(n), Val_unit);
	for(i = 0; i < n; i++){
		push(a);
		s = ml_string(d[i].name);
		a = pop();
		Field(a, i) = s;
	}
	free(d);
	return a;
}

value
sys_system_command(value cmd)
{
	return Val_int(shell((char*)Bytes(cmd)));
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
#ifdef plan9
		exits("interrupt");
#else
		ux(W == 8 ? 94 : 248, 130, 0, 0, 0, 0, 0);
#endif
	signalled[sig] = 1;
	signalled[0] = 1;
}

#ifdef plan9
/* A note is a string: the signal of the same meaning (Linux's number,
 * as Sys gives it here), or 0. The handler continues the program
 * (noted's NCONT, 0) for a signal ignored or noted, and lets the
 * kernel end it (NDFLT, 1) for any other. */
static char note_how[65];

static void
note_handler(void *ureg, char *note)
{
	int sig;

	USED(ureg);
	sig = strncmp(note, "interrupt", 9) == 0 ? 2 : strncmp(note, "hangup", 6) == 0 ? 1 :
		strncmp(note, "alarm", 5) == 0 ? 14 : 0;
	if(sig == 0 || note_how[sig] == 0)
		noted(1);
	if(note_how[sig] == 2)
		note_signal(sig);
	noted(0);
}
#endif

#ifndef __GNUC__
/* rt_sigaction, by its number: the handler, no flag (a system call
 * interrupted says so, and is not started again), no mask */
static void
set_signal(int sig, int how)
{
	value act[5];	/* handler, flags, restorer, and a mask of 64 bits */

	act[0] = how == 0 ? 0 : how == 1 ? 1 : (value)note_signal;
	act[1] = act[2] = act[3] = act[4] = 0;
#ifdef plan9
	/* Plan 9's are notes: one handler for all (note_handler), which
	 * looks here for what to do with each */
	USED(act);
	if(sig > 0 && sig < 65)
		note_how[sig] = how;
	notify(note_handler);
#else
	ux(W == 8 ? 134 : 174, sig, (value)act, 0, 8, 0, 0);
#endif
}
#endif

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
