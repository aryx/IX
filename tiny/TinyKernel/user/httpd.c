// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// httpd [port]: tiny-kernel's files, served to a web browser (port 80
// without one). With tiny-machine -net-forward 8080:80, the address
// http://localhost:8080/ in Firefox is this program: / is a page that
// lists the files, /name is the file. A connection at a time: listen,
// the request read to its empty line (it comes in messages cut
// anywhere: the world's side is TCP), its first line's path taken,
// the answer written (HTTP/1.0: the end of the connection is the
// file's), the connection closed. ^C ends it.
#include "../libc/user.h"

char req[2048], buf[1024];
int n;

void
flush(int fd)
{
	if(n > 0)
		write(fd, buf, n);
	n = 0;
}

void
put(int fd, char *s)
{
	while(*s){
		if(n == 1024)
			flush(fd);
		buf[n++] = *s++;
	}
}

// the files, a link each
void
list(int fd)
{
	struct dirent d;
	char name[21];
	int dir, i;

	put(fd, "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n");
	put(fd, "<html><body><h1>tiny-kernel</h1><p>Served by httpd, a program of tiny-kernel's, on tiny-machine.</p><ul>\n");
	if((dir = open("/", O_RDONLY)) >= 0){
		while(read(dir, (char*)&d, sizeof d) == sizeof d){
			if(d.type == 0)
				continue;
			for(i = 0; i < 20 && d.name[i]; i++)
				name[i] = d.name[i];
			name[i] = 0;
			put(fd, "<li><a href=\"/"); put(fd, name); put(fd, "\">"); put(fd, name); put(fd, "</a></li>\n");
		}
		close(dir);
	}
	put(fd, "</ul></body></html>\n");
	flush(fd);
}

void
serve(int fd)
{
	char *path, *p;
	int len, k, file;

	// the request: until an empty line, or the buffer is full
	len = 0;
	while(len < 2047 && (k = read(fd, req + len, 2047 - len)) > 0){
		len += k;
		req[len] = 0;
		for(p = req; *p; p++)
			if(p[0] == '\n' && (p[1] == '\n' || (p[1] == '\r' && p[2] == '\n')))
				break;
		if(*p)
			break;
	}
	req[len] = 0;
	// "GET /name HTTP/1.0": the path is between the first two spaces
	for(path = req; *path && *path != ' '; path++)
		;
	if(*path == ' ')
		path++;
	for(p = path; *p && *p != ' ' && *p != '\r' && *p != '\n'; p++)
		;
	*p = 0;
	print("httpd: %s\n", path);
	if(path[0] == '/' && path[1] == 0){
		list(fd);
		return;
	}
	if((file = open(path, O_RDONLY)) < 0){
		put(fd, "HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\n\r\nno such file in tiny-kernel\n");
		flush(fd);
		return;
	}
	put(fd, "HTTP/1.0 200 OK\r\nContent-Type: ");
	len = strlen(path);
	put(fd, len > 5 && strcmp(path + len - 5, ".html") == 0 ? "text/html" : len > 4 && strcmp(path + len - 4, ".txt") == 0 ? "text/plain" : "application/octet-stream");
	put(fd, "\r\n\r\n");
	flush(fd);
	while((k = read(file, buf, 1024)) > 0)
		if(write(fd, buf, k) < 0)
			break;
	close(file);
}

void
main(int argc, char *argv[])
{
	int fd, port;

	port = argc > 1 ? atoi(argv[1]) : 80;
	print("httpd: listening on port %d\n", port);
	while((fd = listen(port)) >= 0){
		serve(fd);
		close(fd);
	}
	print("httpd: no network\n");
	exit(1);
}
