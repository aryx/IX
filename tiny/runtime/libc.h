// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// What libc.c and start.s give a C program compiled by tiny-cc:
// Plan 9's names, a 32-bit machine (a long is 4 bytes, no long long).

typedef unsigned char uchar;
typedef unsigned long ulong;

// start.s
extern int write(int, char*, int);
extern void exits(char*);

// libc.c
extern int print(char*, ...);
extern int sprint(char*, char*, ...);
extern void *malloc(ulong);
extern void free(void*);
extern long strlen(char*);
extern char *strcpy(char*, char*);
extern int strcmp(char*, char*);
extern void *memset(void*, int, ulong);
extern int atoi(char*);
