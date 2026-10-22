/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* Plan 9's libc.h for 9front's Doom on Linux (build.sh): the few of its
 * calls the game makes outside its i_*.c, made POSIX's. rfork makes no
 * process (the game would start wadfs, for its music), bind binds
 * nothing. */
#include <stdio.h>
#include <strings.h>
#include <sys/stat.h>

#define print printf
#define fprint(fd, ...) dprintf(fd, __VA_ARGS__)
#define snprint snprintf
#define sprint sprintf
#define exits(s) exit((s) == 0 ? 0 : 1)
#define sysfatal(...) (fprintf(stderr, __VA_ARGS__), fprintf(stderr, "\n"), exit(1))
#define cistrcmp strcasecmp
#define cistrncmp strncasecmp
#define cistrstr strcasestr
#define create(p, m, perm) open(p, O_CREAT | O_TRUNC | O_WRONLY, perm)
#define seek(fd, o, w) lseek(fd, o, w)
#define OREAD O_RDONLY
#define OWRITE O_WRONLY
#define AEXIST F_OK

long long nsec(void);

typedef int QLock;
#define qlock(l) ((void)0)
#define qunlock(l) ((void)0)

#define rfork(f) (-2)
#define RFPROC 0
#define RFFDG 0
#define RFNAMEG 0
#define bind(a, b, c) (0)
#define MBEFORE 0

typedef struct Dir { long long length; } Dir;
static inline Dir *dirfstat(int fd) { struct stat st; Dir *d; if (fstat(fd, &st) < 0) return 0; d = malloc(sizeof *d); d->length = st.st_size; return d; }
static inline long readn(int fd, void *buf, long n) { long m = 0, r; while (m < n && (r = read(fd, (char *)buf + m, n - m)) > 0) m += r; return m; }
