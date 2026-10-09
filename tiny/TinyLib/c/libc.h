/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* TinyLib's C library, its one header: what mini-ml's runtime here
 * (runtime.c and its parts) asks of a C library, for Linux on arm64,
 * compiled by mini-cc. The names and the types are Plan 9's, as in
 * lib_core/libc/ (goken's), whose include/ has 40 headers for the same
 * runtime; libc.c has the functions, start.s the two in assembly. */

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef long long vlong;
typedef unsigned long long uvlong;
/* a pointer's size, 8 bytes: the compiler's long is 4 on arm64 */
typedef unsigned long long uintptr;
typedef long long intptr;

#define nil ((void*)0)
#define USED(x) if(x){}else{}
#define nelem(x) (sizeof(x)/sizeof((x)[0]))

/* Plan 9's va_list: on arm64 every argument has 8 bytes of the stack,
 * whatever its type, a smaller one at the start of its 8 */
typedef char* va_list;
#define va_start(list, start) \
	(list = (sizeof(start) < 8 ? (char*)((vlong*)&(start) + 1) : (char*)(&(start) + 1)))
#define va_end(list)
#define va_arg(list, mode) \
	((sizeof(mode) == 1) ? ((list += 8), (mode*)list)[-8] : \
	 (sizeof(mode) == 2) ? ((list += 8), (mode*)list)[-4] : \
	 (sizeof(mode) == 4) ? ((list += 8), (mode*)list)[-2] : \
	 ((list += sizeof(mode)), (mode*)list)[-1])

/* Linux's system call, by its number: start.s. An argument a word each */
extern intptr _syscall6(intptr, intptr, intptr, intptr, intptr, intptr, intptr);

long read(int, void*, long);
long write(int, void*, long);
int close(int);
void exit(int);
char *getenv(char*);

void *malloc(ulong);
void free(void*);

void *memmove(void*, void*, ulong);
int memcmp(void*, void*, ulong);
long strlen(char*);
int atoi(char*);

double floor(double);

/* fmt.c: C's conversions, floats exactly both ways */
int snprint(char*, int, char*, ...);
int sprint(char*, char*, ...);
double strtod(char*, char**);
double NaN(void);
double Inf(int);
int isNaN(double);
int isInf(double, int);
