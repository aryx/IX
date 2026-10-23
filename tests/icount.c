/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* The instructions a command executes in user mode, by the processor's
 * own counter (Linux's perf_event_open; the perf tool is not needed),
 * on the standard error. Exact and fast: mini-ml's code and OCaml's
 * compiler's counted the same way on the arm64 host, where valgrind
 * stops at an instruction mini-ld emits and Ubuntu's qemu-user has no
 * plugins (docs/notes_profiling_techniques.md, "mini-ml's code against
 * OCaml's").
 *   usage: gcc -O -o icount tests/icount.c; ./icount command args...
 *   a frame of a game: frame 61's run less frame 31's, by 30:
 *     cd games/fps/doom; icount DOOM -dump-frame 61 f.ppm \
 *       -script up:1-61 wad=data/freedoom.wad   (then 31)
 * Needs /proc/sys/kernel/perf_event_paranoid at 2 or less. */

#include <linux/perf_event.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv) {
  struct perf_event_attr a;
  int go[2], st, fd;
  long long n;
  char c;
  pid_t p;
  if (argc < 2) {
    fprintf(stderr, "usage: icount command args...\n");
    return 2;
  }
  memset(&a, 0, sizeof a);
  a.type = PERF_TYPE_HARDWARE;
  a.size = sizeof a;
  a.config = PERF_COUNT_HW_INSTRUCTIONS;
  /* (the child's and its children's, from its exec on, user mode only) */
  a.disabled = 1; a.enable_on_exec = 1; a.inherit = 1;
  a.exclude_kernel = 1; a.exclude_hv = 1;
  if (pipe(go) < 0) { perror("pipe"); return 1; }
  p = fork();
  /* (the child waits until the counter is on it, then runs the command) */
  if (p == 0) {
    close(go[1]);
    if (read(go[0], &c, 1) != 1) _exit(127);
    execvp(argv[1], argv + 1);
    _exit(127);
  }
  fd = syscall(SYS_perf_event_open, &a, p, -1, -1, 0);
  if (fd < 0) { perror("perf_event_open"); return 1; }
  close(go[0]);
  if (write(go[1], "x", 1) != 1) { perror("write"); return 1; }
  close(go[1]);
  waitpid(p, &st, 0);
  if (read(fd, &n, sizeof n) != sizeof n) { perror("read"); return 1; }
  fprintf(stderr, "instructions: %lld\n", n);
  return WIFEXITED(st) ? WEXITSTATUS(st) : 1;
}
