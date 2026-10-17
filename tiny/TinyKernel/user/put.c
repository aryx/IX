// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// put file [name]: a file of tiny-kernel's kept at the wire's other end
// (10.0.0.1), under name (the file's own, without its directories, by
// default). tiny-kernel's files are in its memory and go with it; what
// is put is in tiny-machine's -net directory, or the web page's
// browser, and get brings it back after the next boot: get name > name.
// get '' says what was put (Gopher's empty line, its menu).
//
// get's way the other way round: a connection to port 70, a first
// message, the line "put name size"; then the bytes, a message of
// 1,024 at most each; then the other end's answer, a line: ok, or why
// not. The size comes first so that the other end knows where the file
// ends: the file is read twice, once to count it, and is never all in
// memory (a program has 1 MB).
#include "../libc/user.h"

char buf[1024];

void
fail(char *why, char *what)
{
	print("put: %s: %s\n", what, why);
	exit(1);
}

void
main(int argc, char *argv[])
{
	char *name, *s;
	int fd, conn, n, size;

	if(argc < 2 || argc > 3){
		print("usage: put file [name]\n");
		exit(1);
	}
	name = argv[1];
	for(s = argv[1]; *s; s++)
		if(*s == '/')
			name = s + 1;
	if(argc == 3)
		name = argv[2];
	if((fd = open(argv[1], O_RDONLY)) < 0)
		fail("cannot open", argv[1]);
	size = 0;
	while((n = read(fd, buf, sizeof buf)) > 0)
		size += n;
	close(fd);
	if((conn = reach("10.0.0.1", 70)) < 0)
		fail("nothing answers", "10.0.0.1");
	n = sprint(buf, "put %s %d\r\n", name, size);
	write(conn, buf, n);
	fd = open(argv[1], O_RDONLY);
	while((n = read(fd, buf, sizeof buf)) > 0)
		write(conn, buf, n);
	close(fd);
	n = read(conn, buf, sizeof buf - 1);
	buf[n > 0 ? n : 0] = 0;
	if(n < 3 || buf[0] != 'o' || buf[1] != 'k' || buf[2] != '\n'){
		print("put: %s: %s", name, n > 0 ? buf : "no answer\n");
		exit(1);
	}
	exit(0);
}
