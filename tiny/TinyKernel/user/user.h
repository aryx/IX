// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// What a program of TinyKernel.ml has: its system calls (sys.tm, and
// start.tm's write) and libc (../../libc/). t6's cat, echo, ls, wc,
// mkdir and rm, which use only calls in common, run here unchanged
// (their t6/user/user.h agrees on the values below).

typedef unsigned int uint;
typedef unsigned long ulong;

// a directory's entry, as read from it (t6's: a first block, always 0 here)
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
int write(int, char*, int);
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
int chdir(char*);
// the process ended, as a fault ends one (its status -1); ^C at the
// console kills every process but the shell
int kill(int pid);
// the first of fds' n descriptors that a read would not wait on; -1
// when the clock reaches until (0: no limit; n 0: a sleep)
int ready(int *fds, int n, int until);
// the clock: the kernel's timer interrupts since the boot
int ticks(void);
// a box: a pipe that keeps only what was last written (a mouse's
// place); fds[0] reads it, fds[1] writes it
int box(int *fds);

// what a program is given beside 0, 1 and 2: where it draws (draw.h's
// messages; the screen, or its window) and its mouse (a read waits for
// a change: x, y, the buttons, a word each)
#define DRAW 3
#define MOUSE 4

int print(char*, ...);
int sprint(char*, char*, ...);
int strcmp(char*, char*);
char *strcpy(char*, char*);
