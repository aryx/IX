// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// get name [host [port]]: a document of another machine's, on the
// standard output (of the wire's other end without a host, 10.0.0.1; a
// host is an address or a name). A connection to its port 70, the
// name written, a line; then what comes is read until the other end is
// done. That is Gopher (1991), over IL where it had TCP, and through
// tiny-machine -net-out it is Gopher itself: get / gopher.floodgap.com.
// With another port it is the web's first protocol, which is Gopher's
// with two more lines (HTTP/1.0, 1996: "GET name HTTP/1.0", the host's
// name, an empty line; the answer starts with the server's headers):
// get / example.com 80. No https: most of today's web answers by
// "moved", to an address that asks for TLS, which is m-ix's
// (mini-curl).
// A read gives a message, 1,024 bytes at most: whole as it was written
// when the other end is the wire's (TinyKernelNetwork.ml), cut anywhere when
// it comes from the world. Written all of it: a write to a pipe may
// take less.
#include "../libc/user.h"

char buf[1024];

int
put(int n, char *s)
{
	while(*s && n < 1000)
		buf[n++] = *s++;
	return n;
}

void
main(int argc, char *argv[])
{
	char *to, *p;
	int fd, n, w, port;

	if(argc < 2){
		print("usage: get name [host [port]]\n");
		exit(1);
	}
	to = argc > 2 ? argv[2] : "10.0.0.1";
	port = argc > 3 ? atoi(argv[3]) : 70;
	fd = reach(to, port);
	if(fd < 0){
		print("get: nothing answers at %s\n", to);
		exit(1);
	}
	// (a line ends with a return and a newline, Gopher's and HTTP's)
	n = 0;
	if(port != 70)
		n = put(n, "GET ");
	n = put(n, argv[1]);
	if(port != 70){
		n = put(n, " HTTP/1.0\r\nHost: ");
		n = put(n, to);
		n = put(n, "\r\n");
	}
	n = put(n, "\r\n");
	write(fd, buf, n);
	while((n = read(fd, buf, 1024)) > 0)
		for(p = buf; n > 0; p += w, n -= w)
			if((w = write(1, p, n)) <= 0)
				exit(1);
	exit(0);
}
