// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// TinyKernel.ml's shell: commands separated by ';', pipelines by '|',
// '< file' and '> file'; cd its own. Unix's way: a command is a fork,
// its descriptors changed in the copy (close then dup: the lowest free
// descriptor is the one just closed), then an exec. The copy inherits
// every descriptor, so it closes the pipe's end it does not use, or a
// reader would wait for a writer that is itself (t6's sh, with spawn,
// has no such end to forget).
#include "user.h"

char line[256], spaced[512];
char *toks[64];

// a line after the prompt; -1 at the input's end
int
getline(void)
{
	int n;

	print("$ ");
	for(n = 0; n < sizeof line - 1; n++){
		if(read(0, line + n, 1) != 1){
			if(n == 0)
				return -1;
			break;
		}
		if(line[n] == '\n')
			break;
	}
	line[n] = 0;
	return n;
}

// the line's words, its operators spaced out as words
int
tokenize(void)
{
	char *s, *d;
	int n;

	for(d = spaced, s = line; *s; s++)
		if(*s == '<' || *s == '>' || *s == '|' || *s == ';'){
			*d++ = ' ';
			*d++ = *s;
			*d++ = ' ';
		} else
			*d++ = *s;
	*d = 0;
	n = 0;
	for(s = spaced; *s && n < 63; ){
		while(*s == ' ' || *s == '\t')
			*s++ = 0;
		if(*s == 0)
			break;
		toks[n++] = s;
		while(*s && *s != ' ' && *s != '\t')
			s++;
	}
	return n;
}

// fd as the descriptor to, if not already
void
move(int fd, int to)
{
	if(fd == to)
		return;
	close(to);
	dup(fd);
	close(fd);
}

// the command t[0..n) forked, its 0 and 1 in and out unless redirected,
// other (a pipe's end it does not use, or -1) closed; its pid, or -1
int
command(char **t, int n, int in, int out, int other)
{
	char *argv[32], path[64];
	int i, argc, pid;

	if(n == 0)
		return -1;
	if((pid = fork()) != 0)
		return pid;
	if(other >= 0)
		close(other);
	argc = 0;
	for(i = 0; i < n; i++)
		if(strcmp(t[i], "<") == 0 && i + 1 < n){
			close(in);
			if((in = open(t[++i], O_RDONLY)) < 0){
				print("sh: cannot open %s\n", t[i]);
				exit(1);
			}
		} else if(strcmp(t[i], ">") == 0 && i + 1 < n){
			close(out);
			if((out = open(t[++i], O_CREATE | O_WRONLY | O_TRUNC)) < 0){
				print("sh: cannot create %s\n", t[i]);
				exit(1);
			}
		} else if(argc < 31)
			argv[argc++] = t[i];
	argv[argc] = 0;
	move(in, 0);
	move(out, 1);
	// a name without a '/' is a program of the root
	if(argv[0][0] == '/' || argv[0][0] == '.')
		strcpy(path, argv[0]);
	else
		sprint(path, "/%s", argv[0]);
	exec(path, argv);
	print("sh: %s: not found\n", argv[0]);
	exit(1);
	return -1;
}

// a pipeline t[0..n): each command's output the next's input
void
pipeline(char **t, int n)
{
	int k, start, in, p[2], forked;

	in = 0;
	forked = 0;
	for(start = 0; start < n; start = k + 1){
		for(k = start; k < n && strcmp(t[k], "|") != 0; k++)
			;
		p[0] = -1;
		p[1] = 1;
		if(k < n && pipe(p) < 0){
			print("sh: no pipe\n");
			break;
		}
		if(command(t + start, k - start, in, p[1], p[0]) >= 0)
			forked++;
		if(in != 0)
			close(in);
		if(p[1] != 1)
			close(p[1]);
		in = p[0];
	}
	if(in > 0)
		close(in);
	for(; forked > 0; forked--)
		wait(0);
}

void
main(void)
{
	int n, i, j;

	while(getline() >= 0){
		n = tokenize();
		for(i = 0; i < n; i = j + 1){
			for(j = i; j < n && strcmp(toks[j], ";") != 0; j++)
				;
			if(j == i)
				continue;
			if(strcmp(toks[i], "cd") == 0){
				if(j - i < 2 || chdir(toks[i + 1]) < 0)
					print("sh: cd failed\n");
			} else
				pipeline(toks + i, j - i);
		}
	}
	exit(0);
}
