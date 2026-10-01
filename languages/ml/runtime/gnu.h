/* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
/* What runtime.c uses of Plan 9's libc, from POSIX's: for gcc, when
 * mini-ml's code goes through GNU's as and ld (Gas.ml, decision 8's
 * route B), in user programs (tests/gas.sh). */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/wait.h>

typedef unsigned char uchar;
typedef long long vlong;
typedef unsigned long long uvlong;
typedef intptr_t intptr;
typedef uintptr_t uintptr;

#define nil NULL
#define snprint snprintf

/* open's modes, POSIX's own bits; create, which makes a directory too */
#define OREAD O_RDONLY
#define OWRITE O_WRONLY
#define OTRUNC O_TRUNC
#define OEXCL O_EXCL
#define DMDIR 0x80000000
#define seek lseek
#define getwd(buf, n) getcwd(buf, n)

static int
create(char *name, int mode, unsigned long perm)
{
	if(perm & DMDIR){
		if(mkdir(name, perm & 0777) < 0)
			return -1;
		return open(name, O_RDONLY);
	}
	return open(name, mode | O_CREAT | O_TRUNC, perm);
}

/* a file's Dir, what the runtime reads of it: its mode's DMDIR, its name */
typedef struct Dir Dir;
struct Dir {
	unsigned long mode;
	char *name;
};

static Dir*
dirstat(char *name)
{
	struct stat st;
	Dir *d;

	if(stat(name, &st) < 0)
		return nil;
	d = malloc(sizeof(Dir));
	d->mode = S_ISDIR(st.st_mode) ? DMDIR : 0;
	d->name = nil;
	return d;
}

/* a directory's entries but . and .., in one block, the names after */
static long
dirreadall(int fd, Dir **dp)
{
	DIR *dir;
	struct dirent *e;
	long n, size, i;
	char *names;

	dir = fdopendir(dup(fd));
	if(dir == nil)
		return -1;
	n = 0;
	size = 0;
	*dp = nil;
	for(i = 0; i < 2; i++){
		/* the first pass counts, the second fills */
		if(i == 1)
			*dp = malloc(n * sizeof(Dir) + size + 1);
		names = (char*)(*dp + n);
		n = 0;
		rewinddir(dir);
		while((e = readdir(dir)) != nil){
			if(strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
				continue;
			if(i == 1){
				(*dp)[n].name = strcpy(names, e->d_name);
				names += strlen(e->d_name) + 1;
			}
			size += strlen(e->d_name) + 1;
			n++;
		}
	}
	closedir(dir);
	return n;
}

/* a directory's file under another name: POSIX's rename */
static int
rename_in_dir(char *from, char *to, char *name)
{
	(void)name;
	return rename(from, to);
}

/* the shell's status for a command */
static int
shell(char *cmd)
{
	int st;

	st = system(cmd);
	return WIFEXITED(st) ? WEXITSTATUS(st) : 255;
}
