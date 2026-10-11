// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// get name [address]: a document of another machine's, on the standard
// output (of the wire's other end without an address, 10.0.0.1). A
// connection to its port 70, the name written, a line; then what comes
// is read until the other end is done. That is Gopher (1991), over IL
// where it had TCP: a read gives a message whole, as it was written
// there (TinyNetwork.ml), 1,024 bytes at most; written all of it: a
// write to a pipe may take less.
#include "user.h"

char buf[1024];

void
main(int argc, char *argv[])
{
	char *to, *p;
	int fd, n, w;

	if(argc < 2){
		print("usage: get name [address]\n");
		exit(1);
	}
	to = argc > 2 ? argv[2] : "10.0.0.1";
	fd = dial(to, 70);
	if(fd < 0){
		print("get: nothing answers at %s\n", to);
		exit(1);
	}
	write(fd, argv[1], strlen(argv[1]));
	while((n = read(fd, buf, 1024)) > 0)
		for(p = buf; n > 0; p += w, n -= w)
			if((w = write(1, p, n)) <= 0)
				exit(1);
	exit(0);
}
