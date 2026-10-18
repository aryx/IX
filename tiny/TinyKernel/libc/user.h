// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// What a program of TinyKernel.ml has: its system calls (sys.tm, and
// start.tm's write) and libc (../../TinyCRuntime/, its libc.h included
// here). cat, echo, ls, wc, mkdir and rm are t6's too
// (TinyKernel/steps/t6/user/ has links to them): they use only calls in
// common, and t6's user.h (its libc/) agrees on the values below.

#include "../../TinyCRuntime/libc.h"

typedef unsigned int uint;

// a directory's entry, as read from it (t6's: a first block, which here
// is the file's links instead, how many names it has)
struct dirent { char name[20]; int type; uint first; uint size; };

#define T_DIR 1
#define T_FILE 2
#define T_DEV 3
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#define O_CREATE 0x200
#define O_TRUNC 0x400

void exit(int);
int read(int, char*, int);
// a copy of the caller: 0 in the copy, its pid in the caller
int fork(void);
// the program at path, argv its arguments (16 at most); -1 if it fails
int exec(char *path, char **argv);
int wait(int*);
int getpid(void);
int open(char*, int);
int close(int);
int pipe(int*);
// the file of fd at the lowest free descriptor
int dup(int fd);
int mkdir(char*);
int unlink(char*);
// a second name, new, for the file old (not a directory): 0, or -1
int link(char *old, char *new);
int chdir(char*);
// the current directory's path in the n bytes at buf, ended by a 0:
// its length; -1 when it does not fit
int getcwd(char *buf, int n);
// the process ended, as a fault ends one (its status -1); ^C at the
// console kills every process but the shell
int kill(int pid);
// the console raw for this process while it lives (on 1), or not (0):
// its ^C is then a byte read, not the kill above (emacs's C-x C-c)
int rawcons(int on);
// the first of fds' n descriptors that a read would not wait on; -1
// when the clock reaches until (0: no limit; n 0: a sleep)
int ready(int *fds, int n, int until);
// the clock: the kernel's timer interrupts since the boot
int ticks(void);
// a box: a pipe that keeps only what was last written (a mouse's
// place); fds[0] reads it, fds[1] writes it
int box(int *fds);
// a connection to a port of the machine at an address ("10.0.0.1"): a
// descriptor, -1 without a network or when nothing answers there; a
// write is a message, a read gives one, 0 at the other end's end. Port
// 0 is the echo: a write is a question sent there, a read an answer's
// bytes
int dial(char *address, int port);
// the next connection another machine makes to a port of this one: a
// descriptor (a server calls it in a loop)
int listen(int port);
// net.c: dial, by an address or by a name (asked of the wire's other
// end, its port 53)
int reach(char *host, int port);

// what a program is given beside 0, 1 and 2: where it draws (draw.h's
// messages; the screen, or its window) and its mouse (a read waits for
// a change: x, y, the buttons, a word each)
#define DRAW 3
#define MOUSE 4
