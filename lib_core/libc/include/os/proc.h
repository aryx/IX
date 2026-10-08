/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// Plan 9 specific
// exits() is the libc exit that performs some cleanup (and handle atexit())
// while _exits() is the syscall that is more abrupt
// TODO? still the case in goken libc? maybe reverted now
// alt: move under os/plan9/proc.h
extern	void	_exits(char*);
extern  void    exits(char*);

// in <stdlib.h>, with _exit() in <unistd.h>
// plain POSIX-style exit(int), alongside Plan9's own exits(char*)/_exits(char*)
extern	void	exit(int);

extern  int     atexit(void(*)(void));

// Plan 9 specific (move in os/plan9/proc.h?)
extern	int	rfork(int);
// rfork's flags: Plan 9's values (principia's Rfork_flags)
enum {
	RFNAMEG  = (1<<0),
	RFENVG   = (1<<1),
	RFFDG    = (1<<2),
	RFNOTEG  = (1<<3),
	RFPROC   = (1<<4),
	RFMEM    = (1<<5),
	RFNOWAIT = (1<<6),
	RFCNAMEG = (1<<10),
	RFCENVG  = (1<<11),
	RFCFDG   = (1<<12),
	RFREND   = (1<<13),
	RFNOMNT  = (1<<14),
};
// in <unistd.h>
extern	int	fork(void);

// alt: Plan 9 specific, no wait message in Unix, move under os/plan9/wait.h?
/* keep /sys/src/ape/lib/ap/plan9/sys9.h in sync with this -rsc */
typedef struct Waitmsg Waitmsg;
struct Waitmsg {
 int	pid;		/* of loved one */
 ulong	time[3];	/* of loved one & descendants */
 // ref_own?<string>?
 char	*msg;
};

extern	Waitmsg* wait(void);

extern	int	await(char*, int);

extern	int	exec(char*, char*[]);

extern	int	execl(char*, ...);

extern	int	waitpid(void);

// goken's: a process started with its three descriptors given (-1:
// the caller's), for where fork and exec cannot be; its pid, or -1
extern	int	spawn(char*, char**, fdt, fdt, fdt);

// in <unistd.h>
extern	int	getpid(void);
extern	int	getppid(void);

// process id type. I like types! similar to os/file.h fdt.
typedef int pidt;
