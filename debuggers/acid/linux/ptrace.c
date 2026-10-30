/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Linux's ptrace for mini-acid (Ptrace.mli): a program run traced,
 * stopped before its first instruction; its registers read and
 * written (arm64's user_pt_regs, by PTRACE_GETREGSET); continued, a
 * signal given or not; waited for. Its memory is /proc/PID/mem,
 * which the tracer reads and writes as a file (Ptrace.ml). */

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>

#ifdef __linux__
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/uio.h>
#include <sys/user.h>
#include <sys/personality.h>
#include <elf.h>
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* the program forked and executed, traced (PTRACE_TRACEME), its
 * addresses not randomized (a session's are the same each run); the
 * exec's stop waited for */
value ml_ptrace_spawn(value path, value argv)
{
	CAMLparam2(path, argv);
	int n = Wosize_val(argv), i, st;
	char **a = malloc((n + 1) * sizeof(char *));
	char *p = strdup(String_val(path));
	pid_t pid;

	for(i = 0; i < n; i++)
		a[i] = strdup(String_val(Field(argv, i)));
	a[n] = NULL;
	pid = fork();
	if(pid == 0){
		ptrace(PTRACE_TRACEME, 0, NULL, NULL);
		personality(ADDR_NO_RANDOMIZE);
		execv(p, a);
		_exit(127);
	}
	for(i = 0; i < n; i++)
		free(a[i]);
	free(a);
	free(p);
	if(pid < 0)
		caml_failwith("fork");
	if(waitpid(pid, &st, 0) < 0 || !WIFSTOPPED(st))
		caml_failwith("exec");
	/* (the program killed if mini-acid dies) */
	ptrace(PTRACE_SETOPTIONS, pid, NULL, (void *)PTRACE_O_EXITKILL);
	CAMLreturn(Val_int(pid));
}

#ifdef __aarch64__
value ml_ptrace_getregs(value pid)
{
	CAMLparam1(pid);
	CAMLlocal1(s);
	struct user_regs_struct r;
	struct iovec io = { &r, sizeof r };

	if(ptrace(PTRACE_GETREGSET, Int_val(pid), (void *)NT_PRSTATUS, &io) < 0)
		caml_failwith(strerror(errno));
	s = caml_alloc_string(sizeof r);
	memcpy(Bytes_val(s), &r, sizeof r);
	CAMLreturn(s);
}

value ml_ptrace_setregs(value pid, value s)
{
	CAMLparam2(pid, s);
	struct user_regs_struct r;
	struct iovec io = { &r, sizeof r };

	if(caml_string_length(s) != sizeof r)
		caml_failwith("setregs: size");
	memcpy(&r, String_val(s), sizeof r);
	if(ptrace(PTRACE_SETREGSET, Int_val(pid), (void *)NT_PRSTATUS, &io) < 0)
		caml_failwith(strerror(errno));
	CAMLreturn(Val_unit);
}
#else
value ml_ptrace_getregs(value pid) { caml_failwith("ptrace: arm64's registers only"); }
value ml_ptrace_setregs(value pid, value s) { caml_failwith("ptrace: arm64's registers only"); }
#endif

value ml_ptrace_cont(value pid, value sig)
{
	if(ptrace(PTRACE_CONT, Int_val(pid), NULL, (void *)(long)Int_val(sig)) < 0)
		caml_failwith(strerror(errno));
	return Val_unit;
}

/* stopped: the signal (> 0); exited: -1 - its status; killed: -1000
 * - the signal */
value ml_ptrace_wait(value pid)
{
	int st;

	if(waitpid(Int_val(pid), &st, 0) < 0)
		caml_failwith(strerror(errno));
	if(WIFSTOPPED(st))
		return Val_int(WSTOPSIG(st));
	if(WIFEXITED(st))
		return Val_int(-1 - WEXITSTATUS(st));
	return Val_int(-1000 - WTERMSIG(st));
}

value ml_ptrace_signal(value pid, value sig)
{
	kill(Int_val(pid), Int_val(sig));
	return Val_unit;
}
#else
value ml_ptrace_spawn(value path, value argv) { caml_failwith("ptrace: Linux's only"); }
value ml_ptrace_getregs(value pid) { caml_failwith("ptrace: Linux's only"); }
value ml_ptrace_setregs(value pid, value s) { caml_failwith("ptrace: Linux's only"); }
value ml_ptrace_cont(value pid, value sig) { caml_failwith("ptrace: Linux's only"); }
value ml_ptrace_wait(value pid) { caml_failwith("ptrace: Linux's only"); }
value ml_ptrace_signal(value pid, value sig) { caml_failwith("ptrace: Linux's only"); }
#endif
