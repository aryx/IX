// The part of Plan 9's libc the tests use, declared for tiny-c (its
// runtime, TinyCRuntime/, has them) and for mini-cc with goken's libc
// (languages/c/tests/simple.sh): Plan 9's C, long is 4 bytes, vlong is
// long long (TinyC_fuzz.py's programs without --32; tiny-c refuses a
// variable of it). host.h is this file for the host's cc.
typedef unsigned char uchar;
typedef unsigned long ulong;
typedef long long vlong;
typedef unsigned long long uvlong;

extern int print(char*, ...);
extern int sprint(char*, char*, ...);
extern void exits(char*);
extern void *malloc(ulong);
extern void free(void*);
extern long strlen(char*);
extern char *strcpy(char*, char*);
extern int strcmp(char*, char*);
extern void *memset(void*, int, ulong);
extern int atoi(char*);
