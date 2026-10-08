/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
/* What is not a call of Plan 9's kernel, over those of svc_arm.s:
 * read and write are pread and pwrite at offset -1, the current
 * position (principia's 9sys/read.c, write.c); exit(int), which the
 * other systems have, is exits with "" for 0 and "error" otherwise. */
extern long pread(int fd, void *buf, long n, vlong offset);
extern long pwrite(int fd, void *buf, long n, vlong offset);
extern void exits(char *msg);

long
read(int fd, void *buf, long n)
{
	return pread(fd, buf, n, -1LL);
}

long
write(int fd, void *buf, long n)
{
	return pwrite(fd, buf, n, -1LL);
}

void
exit(int code)
{
	if (code == 0)
		exits(0);
	else
		exits("error");
}
