/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's stat_arm.c and stat_arm64.c in one (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* dirfstat, dirfwstat, dirread and dirreadall for Linux: a Dir from
 * the kernel's own struct stat, which is not the same on arm64 (the
 * "generic" one of asm-generic/stat.h) and on arm (stat64's, with its
 * padding, and the 64 bits of the inode at the end). A field that is a
 * long of 8 bytes for the kernel is a vlong here: the compiler's long
 * is 4. */
typedef struct Kstat Kstat;
#ifdef arm64
struct Kstat {
	uvlong	dev;
	uvlong	ino;
	uint	mode;
	uint	nlink;
	uint	uid;
	uint	gid;
	uvlong	rdev;
	uvlong	__pad1;
	vlong	size;
	int	blksize;
	int	__pad2;
	vlong	blocks;
	vlong	atime;
	uvlong	atime_nsec;
	vlong	mtime;
	uvlong	mtime_nsec;
	vlong	ctime;
	uvlong	ctime_nsec;
	uint	__unused4;
	uint	__unused5;
};
#else
struct Kstat {
	uvlong	dev;
	ushort	__pad1;
	ushort	__pad0;
	uint	__st_ino;
	uint	mode;
	uint	nlink;
	uint	uid;
	uint	gid;
	uvlong	rdev;
	ushort	__pad2;
	ushort	__pad3a;
	uint	__pad3b;
	vlong	size;
	int	blksize;
	uint	__pad4;
	vlong	blocks;
	int	atime;
	int	atime_nsec;
	int	mtime;
	int	mtime_nsec;
	int	ctime;
	int	ctime_nsec;
	uvlong	ino;
};
#endif

#define S_IFMT	0170000
#define S_IFDIR	0040000

static void
kstat2dir(Kstat *st, Dir *d)
{
	memset(d, 0, sizeof(Dir));
	d->name = d->uid = d->gid = d->muid = "";
	d->qid.path = st->ino;
	d->mode = st->mode & 0777;
	if ((st->mode & S_IFMT) == S_IFDIR) {
		d->mode |= DMDIR;
		d->qid.type = QTDIR;
	}
	d->atime = st->atime;
	d->mtime = st->mtime;
	d->length = st->size;
}

extern int _sysfstat(int fd, void *buf);
extern int _sysfchmod(int fd, int mode);
#ifdef arm64
extern int _sysftruncate(int fd, vlong length);
#else
extern int _sysftruncate64(int fd, ulong lo, ulong hi);
#endif

Dir*
dirfstat(fdt fd)
{
	Kstat st;
	Dir *d;

	if (_sysfstat(fd, &st) < 0)
		return nil;
	d = malloc(sizeof(Dir));
	if (d == nil)
		return nil;
	kstat2dir(&st, d);
	return d;
}

/* the mode and the length only: not the times */
int
dirfwstat(fdt fd, Dir *d)
{
	int ret;

	ret = 0;
	if (~d->mode != 0) {
		if (_sysfchmod(fd, (int)(d->mode & 0777)) < 0)
			ret = -1;
	}
	if (~d->length != 0) {
#ifdef arm64
		if (_sysftruncate(fd, d->length) < 0)
#else
		if (_sysftruncate64(fd, (ulong)d->length,
		    (ulong)((uvlong)d->length >> 32)) < 0)
#endif
			ret = -1;
	}
	return ret;
}

/* The names are getdents64's; each is made a Dir by opening it from
 * the directory's descriptor (openat: dirread has no path) and
 * dirfstat. "." and ".." are left out, as Plan 9's directories have
 * none. dirread gives what one getdents64 gave, dirreadall goes on to
 * the end. */
typedef struct Dirent64 Dirent64;
struct Dirent64 {
	uvlong	ino;
	vlong	off;
	ushort	reclen;
	uchar	type;
	char	name[1];
};

extern long openat(int dirfd, void *path, int flags, int mode);
extern long _sysgetdents64(int fd, void *buf, uint count);

static long
dirreadbuf(fdt fd, Dir **dp, int all)
{
	uchar buf[8192];
	Dir *d, *nd, *tmp;
	long n, off, ndir, cap;
	fdt cfd;
	Dirent64 *de;

	d = nil;
	ndir = 0;
	cap = 0;
	for (;;) {
		n = _sysgetdents64(fd, buf, sizeof buf);
		if (n <= 0)
			break;
		for (off = 0; off < n; off += de->reclen) {
			de = (Dirent64*)(buf + off);
			if (de->name[0] == '.' && (de->name[1] == 0 ||
			    (de->name[1] == '.' && de->name[2] == 0)))
				continue;
			cfd = openat(fd, de->name, 0, 0);
			if (cfd < 0)
				continue;
			nd = dirfstat(cfd);
			close(cfd);
			if (nd == nil)
				continue;
			nd->name = strdup(de->name);
			if (ndir >= cap) {
				cap = cap ? cap*2 : 16;
				tmp = realloc(d, cap * sizeof(Dir));
				if (tmp == nil) {
					free(nd);
					free(d);
					return -1;
				}
				d = tmp;
			}
			d[ndir++] = *nd;
			free(nd);
		}
		if (!all)
			break;
	}
	*dp = d;
	return ndir;
}

long
dirread(fdt fd, Dir **dp)
{
	return dirreadbuf(fd, dp, 0);
}

long
dirreadall(fdt fd, Dir **dp)
{
	return dirreadbuf(fd, dp, 1);
}
