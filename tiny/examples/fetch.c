// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// fetch: a document of another machine's, on the standard output, by
// Gopher (1991), the smallest of the protocols: a connection to its
// port 70, the document's name written as a line, then what comes read
// until the other end is done. The other machine is the wire's other
// end, 10.0.0.1, without a host (tiny-machine -net dir serves dir's
// files); a host is an address or a name (reach, net.o's, asks a name's
// address of the wire's other end). get is the same, with more.
// The Buildfile beside it builds it, with /lib/c's runtime and net.o:
//
//	cd /examples; build fetch; ./fetch hello.txt
//	./fetch / gopher.floodgap.com      through tiny-machine -net-out
#include "user.h"

char buf[1024];

void
main(int argc, char *argv[])
{
	char *host;
	int fd, n;

	if(argc < 2 || strlen(argv[1]) > 900){
		print("usage: fetch name [host]\n");
		exit(1);
	}
	host = argc > 2 ? argv[2] : "10.0.0.1";
	fd = reach(host, 70);
	if(fd < 0){
		print("fetch: %s: no answer\n", host);
		exit(1);
	}
	sprint(buf, "%s\r\n", argv[1]);
	write(fd, buf, strlen(buf));
	while((n = read(fd, buf, sizeof buf)) > 0)
		write(1, buf, n);
	close(fd);
	exit(0);
}
