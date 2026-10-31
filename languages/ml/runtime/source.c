/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* A trace's line of code, from /src */
/*****************************************************************************/

/* plan_debugger.md, stage 5b: after an uncaught exception's frames, the
 * line of code of the innermost one whose source is there,
 *     Typed.ml:10  let check n = if n > 2 then raise (Bad (...
 * read from the card's /src (the repository: plan_self_hosting.md), or
 * from $ML_SRC elsewhere (a checkout of ix). Its unit compiled with -g:
 * the history says the file by its path in ix (Lines_ml.source), the
 * descriptions its MD5 (mlsources); a copy whose MD5 is not the same,
 * of another day, says nothing rather than a line that moved. The file
 * read a block at a time, summed as it goes (md5.c), nothing kept but
 * the line. */
#ifndef __GNUC__
/* the history's components (their numbers, two bytes each) joined by
 * '/', in p; its length, 0 when it does not fit or a number has no
 * name */
static int
joinpath(uchar *nums, long n, char *p, int max)
{
	long i, o, len;
	uint v, k;
	int t, at, found;
	uchar *nm;

	at = 0;
	for(i = 0; i + 1 < n; i += 2){
		k = (nums[i] << 8) | nums[i + 1];
		found = 0;
		for(o = 0; o + 5 <= nsyms && !found; ){
			o = entry(o, &v, &t, &nm, &len);
			found = t == 'f' && v == k;
		}
		if(!found || at + len + 2 > max)
			return 0;
		if(at > 0 && p[at - 1] != '/')
			p[at++] = '/';
		memmove(p + at, nm, len);
		at += len;
	}
	p[at] = 0;
	return at;
}

/* line n of the file at path, its blanks before it left out, in b (at
 * most max - 1); whether the file's MD5 is hex's */
static int
codeline(char *path, long n, char *hex, char *b, int max)
{
	char buf[4096], h[33];
	uchar d[16];
	MD5 m;
	fdt fd;
	long r, i, line;
	int len, start;

	fd = open(path, OREAD);
	if(fd < 0)
		return 0;
	md5_init(&m);
	line = 1;
	len = 0;
	start = 1;
	while((r = read(fd, buf, sizeof buf)) > 0){
		md5_add(&m, (uchar*)buf, r);
		for(i = 0; i < r; i++)
			if(buf[i] == '\n')
				line++;
			else if(line == n && !(start && (buf[i] == ' ' || buf[i] == '\t')) && len < max - 1){
				b[len++] = buf[i];
				start = 0;
			}
	}
	close(fd);
	b[len] = 0;
	md5_digest(&m, d);
	for(i = 0; i < 16; i++){
		h[2 * i] = "0123456789abcdef"[d[i] >> 4];
		h[2 * i + 1] = "0123456789abcdef"[d[i] & 15];
	}
	return memcmp(h, hex, 32) == 0 && len > 0;
}

/* the trace's line of code, "file:line  text" (cut at 80 columns), in
 * b; its length, 0 when no frame's source is there */
static int
srcline(char *b, int max)
{
	char rel[256], path[512], text[160], d[20], *root, *desc, *hex;
	long line, flen, fl, plen;
	uchar *file, *nums;
	int k, n, s, len;

	root = getenv("ML_SRC");
	if(root == nil)
		root = "/src";
	for(k = 0; k < ntpc; k++){
		line = pc2line(tpc[k]);
		if(line <= 0 || !fileline(tpc[k], line, &file, &flen, &fl, &nums, &plen)
		|| (n = joinpath(nums, plen, rel, sizeof rel)) == 0 || rel[0] == '/'
		|| strlen(root) + n + 2 > sizeof path)
			continue;
		desc = described("mlsources = append mlsources, ", rel, n);
		hex = elnth(desc, 1);
		if(hex == nil || ellen(hex) != 32)
			continue;
		s = strlen(root);
		memmove(path, root, s);
		path[s] = '/';
		memmove(path + s + 1, rel, n + 1);
		if(!codeline(path, fl, hex + 1, text, sizeof text))
			continue;
		len = add(b, 0, max, (char*)file, flen);
		len = add(b, len, max, ":", 1);
		s = digits(fl, 10, 0, d, 20);
		len = add(b, len, max, d + s, 20 - s);
		len = add(b, len, max, "  ", 2);
		/* within the console's 80 columns */
		s = strlen(text);
		if(len + s > 80 && len < 60){
			len = add(b, len, max, text, 80 - 3 - len);
			return add(b, len, max, "...", 3);
		}
		return add(b, len, max, text, s);
	}
	return 0;
}
#else
static int
srcline(char *b, int max)
{
	USED(b);
	USED(max);
	return 0;
}
#endif
