/* From Plan 9's libc.h: the segments (segattach(2)); not in goken's. */
enum
{
	SG_RONLY	= 0040,	/* read only */
	SG_CEXEC	= 0100,	/* detach at exec */
};

extern	void*	segattach(int, char*, void*, ulong);
extern	int	segdetach(void*);
extern	int	segfree(void*, ulong);
extern	int	segflush(void*, ulong);
