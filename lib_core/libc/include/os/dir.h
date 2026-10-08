/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// require: <os/file.h> for Qid and fdt

typedef struct Dir Dir;
// a similar structure is defined in the kernel!
struct Dir {
 /* system-modified data */
 ushort	type;	/* server type */
 uint	dev;	/* server subtype */

 /* file data */
 Qid	qid;	/* unique id from server */

 ulong	mode;	/* permissions */

 ulong	atime;	/* last read time */
 ulong	mtime;	/* last write time */
    // TODO: mtime second granularity above is not enough for mk! need subsecond!
    // Note that 'float' precision is not enough and we need 'double' here
    // as in 2025 mtime = seconds since 1970 EPOCH will be a huge number
    // that would get truncated if using a 'float'.
    // double mtime_;

 vlong	length;	/* file length */
 char	*name;	/* last element of path */

 char	*uid;	/* owner name */
 char	*gid;	/* group name */
 char	*muid;	/* last modifier name */

};

/* bits in Dir.mode */
#define DMDIR		0x80000000	/* mode bit for directories */
#define DMREAD		0x4		/* mode bit for read permission */
#define DMWRITE		0x2		/* mode bit for write permission */
#define DMEXEC		0x1		/* mode bit for execute permission */
// advanced stuff
#define DMAPPEND	0x40000000	/* mode bit for append only files */
#define DMEXCL		0x20000000	/* mode bit for exclusive use files */
#define DMMOUNT		0x10000000	/* mode bit for mounted channel */
#define DMAUTH		0x08000000	/* mode bit for authentication file */
#define DMTMP		0x04000000	/* mode bit for non-backed-up files */

// require: stat.h before
#define	DIRMAX	(sizeof(Dir)+STATMAX)	/* max length of Dir structure */

// creat() in unix world
extern	int	create(char*, int, ulong);
// unlink() in unix world
extern	int	remove(char*);

extern  char*   getwd(char*, int);
extern	int	chdir(char*);

// plan9 specific
// alt: path.h?
extern	int	fd2path(fdt, char*, int);

extern	long	dirread(int, Dir**);
extern	void	nulldir(Dir*);
extern	long	dirreadall(int, Dir**);

// %M, a Dir's mode as "drwxrwxrwx" (for fmtinstall)
extern	int	dirmodefmt(Fmt*);

// in <unistd.h>
extern	int	access(char*, int); // ???

// pad: I added this one to factorize code in many progs
extern	bool	fileexists(char*); // new: used to be in linkers/
