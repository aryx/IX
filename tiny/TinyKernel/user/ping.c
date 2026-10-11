// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// ping [address]: is the machine at that address there? (the wire's
// other end without one, 10.0.0.1). Three questions, a quarter of a
// second apart, each waited for a second: what answers and in how
// long, by the kernel's clock (a tick is 2.5 ms). TinyNetwork.ml has
// the question and the answer, TinyKernel.ml's dial the link.
#include "user.h"

void
main(int argc, char *argv[])
{
	char *to;
	char buf[64];
	int fd, i, t, d, fds[1];

	to = argc > 1 ? argv[1] : "10.0.0.1";
	fd = dial(to, 0);
	if(fd < 0){
		print("ping: no network, or not an address: %s\n", to);
		exit(1);
	}
	fds[0] = fd;
	for(i = 0; i < 3; i++){
		t = ticks();
		write(fd, "ping", 4);
		if(ready(fds, 1, t + 400) < 0)
			print("no answer from %s\n", to);
		else{
			read(fd, buf, 64);
			d = (ticks() - t) * 5;
			print("answer from %s in %d.%d ms\n", to, d / 2, d % 2 * 5);
		}
		ready(fds, 0, ticks() + 100);
	}
	exit(0);
}
