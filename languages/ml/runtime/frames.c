/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* A raise's frames, named by the program's own table */
/*****************************************************************************/

/* plan_debugger.md, stage 5a: a program that dies of an exception names
 * where it was raised and through whom, itself, on the board as on the
 * host: `f2_down+0x10 Deep.ml:5 < ... < _main+0x1c rt0.s:17` (Go's
 * way: a program that names its own frames needs no debugger). The
 * table is the one mini-ld -g writes in the a.out, read from the
 * program's image (Plan 9's /proc/$pid/text: mini-9pi's and
 * mini-5i's); a program without one says addresses (exceptions.c's
 * guess). Arm's only: its raises keep the registers a walk needs
 * (Gen's ml_raise).
 *
 * What lib_executable's Symbols and Frames do, in C, of them what a
 * trace needs: the function at an address and its .frame, mini-ml's
 * prologue, the pc/line table and the history's file. The walk is
 * Frames.walk: from the raise's pc, its function's frame gives where
 * the caller's address is (0(SP)), and the caller's sp, to _main. The
 * stack below the handler's is gone when the trace is asked (the
 * handler ran there): its words are ml_raise_words, kept at the raise;
 * above it the frames are still there. The table is read once, at the
 * first trace, and kept. */
#ifndef __GNUC__
enum { Textbase = 0x1020 };     /* the text's first instruction (Exe's -H2) */

static uchar *tab;              /* the symbols, then the lines; nil: none */
static long nsyms, nlines;
static uvalue textend;
static int tabtried;

static uint
be32(uchar *p)
{
	return ((uint)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

/* n bytes at off, read until there are (a file of the kernel's may
 * give fewer a read); how many there were */
static long
readat(fdt fd, void *buf, long n, vlong off)
{
	long r, got;

	if(seek(fd, off, 0) < 0)
		return -1;
	for(got = 0; got < n; got += r){
		r = read(fd, (char*)buf + got, n - got);
		if(r <= 0)
			break;
	}
	return got;
}

/* the a.out's table: its header (Exe's: the magic, text, data, bss,
 * the symbols' size, the entry, two words, the lines' size), the
 * symbols after the data, the lines after them */
static int
table(void)
{
	char path[40], d[20];
	uchar h[32];
	fdt fd;
	int s;
	long text, data;

	if(tabtried)
		return tab != nil;
	tabtried = 1;
	s = digits(getpid(), 10, 0, d, 20);
	strcpy(path, "/proc/");
	memmove(path + 6, d + s, 20 - s);
	strcpy(path + 6 + 20 - s, "/text");
	fd = open(path, OREAD);
	if(fd < 0)
		return 0;
	if(readat(fd, h, 32, 0) == 32 && be32(h) == 0x647 && be32(h + 16) != 0){
		text = be32(h + 4);
		data = be32(h + 8);
		nsyms = be32(h + 16);
		nlines = be32(h + 28);
		tab = malloc(nsyms + nlines);
		if(tab != nil
		&& readat(fd, tab, nsyms + nlines, 32 + text + data) != nsyms + nlines)
			tab = nil;
		textend = Textbase + text;
	}
	close(fd);
	return tab != nil;
}

/* the entry at o: its value, its letter, its name (a z's: the files'
 * numbers, two bytes each, to two NULs); the next one's offset */
static long
entry(long o, uint *v, int *t, uchar **name, long *len)
{
	uchar *s;
	long e;

	s = tab + o;
	*v = be32(s);
	*t = s[4] & 0x7f;
	s += 5;
	if(*t == 'z' || *t == 'Z'){
		for(e = 1; s[e] != 0 || s[e + 1] != 0; e += 2)
			;
		*name = s + 1;
		*len = e - 1;
		return o + 5 + e + 2;
	}
	for(e = 0; s[e] != 0; e++)
		;
	*name = s;
	*len = e;
	return o + 5 + e + 1;
}

static int
istext(int t)
{
	return t == 'T' || t == 't' || t == 'L' || t == 'l';
}

typedef struct Func Func;
struct Func {
	uint start;
	int type;
	uchar *name;
	long len;
	uint frame;     /* its .frame, the entry after it */
};

/* the function at pc (the last of those at its start, as Frames') */
static int
function(uvalue pc, Func *f)
{
	long o, n;
	uint v;
	int t, found, after;
	uchar *nm;

	found = after = 0;
	for(o = 0; o + 5 <= nsyms; ){
		o = entry(o, &v, &t, &nm, &n);
		if(after && t == 'm' && n == 6 && memcmp(nm, ".frame", 6) == 0)
			f->frame = v;
		after = 0;
		if(istext(t) && v <= pc && (!found || v >= f->start)){
			f->start = v;
			f->type = t;
			f->name = nm;
			f->len = n;
			f->frame = 0;
			found = after = 1;
		}
	}
	return found && pc < textend;
}

/* libmach's pc2line: the global line of pc; the table's pc one
 * instruction behind, as the linker started it; -1: none */
static long
pc2line(uvalue pc)
{
	uvalue p;
	long i, line;
	int u;

	if(pc < Textbase - 4 || pc > textend)
		return -1;
	p = Textbase - 4;
	line = 0;
	for(i = 0; p < pc; i++){
		if(i >= nlines)
			return -1;
		u = tab[nsyms + i];
		if(u == 0){
			line += (int)be32(tab + nsyms + i + 1);
			i += 4;
			p += 4;
		}else if(u < 65){
			line += u;
			p += 4;
		}else if(u < 129){
			line -= u - 64;
			p += 4;
		}else
			p += 4 * (u - 129) + 4;
	}
	return line;
}

/* the file of a global line at pc, and its own line: the history of
 * the object (the z entries before its first function: the last such
 * at or before pc), its files a stack, an included one's lines added to
 * its includer's at its end (libmach's fline). The file is its path's
 * last component, all a trace says */
static int
fileline(uvalue pc, long line, uchar **file, long *flen, long *fline)
{
	struct { uchar *path; long len, base, at; } st[16];
	long o, at, g, best, n;
	uint v, k;
	int t, sp;
	uchar *nm;

	g = best = -1;
	for(o = 0; o + 5 <= nsyms; ){
		at = o;
		o = entry(o, &v, &t, &nm, &n);
		if(t == 'z'){
			if(g < 0)
				g = at;
		}else if(istext(t) && g >= 0){
			if(v <= pc)
				best = g;
			g = -1;
		}
	}
	if(best < 0)
		return 0;
	sp = 0;
	for(o = best; o + 5 <= nsyms; ){
		o = entry(o, &v, &t, &nm, &n);
		if(t != 'z' || (long)v > line)
			break;
		if(n > 0){
			if(sp == nelem(st))
				return 0;
			st[sp].path = nm;
			st[sp].len = n;
			st[sp].base = v - 1;
			st[sp].at = v;
			sp++;
		}else{
			if(sp < 2)
				return 0;
			st[sp - 2].base += v - st[sp - 1].at;
			sp--;
		}
	}
	if(sp == 0)
		return 0;
	/* the last component: the f entry of the path's last number */
	nm = st[sp - 1].path + st[sp - 1].len - 2;
	k = (nm[0] << 8) | nm[1];
	for(o = 0; o + 5 <= nsyms; ){
		o = entry(o, &v, &t, &nm, &n);
		if(t == 'f' && v == k){
			*file = nm;
			*flen = n;
			*fline = line - st[sp - 1].base;
			return 1;
		}
	}
	return 0;
}

/* a word of the stopped program: below the handler's stack pointer the
 * stack as the raise kept it, above it the stack itself, the text's */
static int
load(uvalue a, uint *w)
{
	uvalue n;

	n = nelem(ml_raise_words) - ml_raise_left;
	if(a >= ml_raise_sp && a < ml_raise_sp + 4 * n){
		*w = ml_raise_words[(a - ml_raise_sp) / 4];
		return 1;
	}
	if((a >= ml_raise_top && a < (uvalue)machine_top + 4096)
	|| (a >= Textbase && a < textend)){
		*w = *(uint*)a;
		return 1;
	}
	return 0;
}

/* mini-ml's prologue (Gen's and Emit's): SUB $n, R13 (an immediate,
 * rotated, or a constant of the pool in R11), then MOVW R14, 0(R13):
 * the frame's size, and where the save is */
static int
prologue(uvalue start, uint *size, uvalue *saved)
{
	uint w, w2, k;
	int imm, rot;

	if(!load(start, &w))
		return 0;
	if((w >> 16) == 0xe24d && (w & 0xf000) == 0xd000
	&& load(start + 4, &w2) && w2 == 0xe58de000){
		imm = w & 0xff;
		rot = 2 * ((w >> 8) & 15);
		*size = rot == 0 ? imm : (imm >> rot) | (imm << (32 - rot));
		*saved = start + 4;
		return 1;
	}
	if((w >> 16) == 0xe59f && (w & 0xf000) == 0xb000
	&& load(start + 4, &w2) && w2 == 0xe04dd00b
	&& load(start + 8, &k) && k == 0xe58de000 && load(start + 8 + (w & 0xfff), &k)){
		*size = k;
		*saved = start + 8;
		return 1;
	}
	return 0;
}

static int
add(char *b, int len, int max, char *s, int n)
{
	if(len + n < max){
		memmove(b + len, s, n);
		len += n;
	}
	return len;
}

/* the frames of the last raise, at most 40, in b as the kernel says a
 * suicide's (Frames.show): " f+0x10 a.ml:12 < g+0x2c a.ml:30"; its
 * length, 0 when there is no table or no raise kept */
static int
frames(char *b, int max)
{
	Func f;
	uvalue pc, sp, saved, ra;
	uint size, w;
	long line, flen, fl;
	uchar *file;
	char d[20];
	int n, len, s, leaf;

	if(sizeof(value) != 4 || ml_raise_pc == 0 || !table())
		return 0;
	pc = ml_raise_pc - 8;
	sp = ml_raise_sp;
	/* a raise's MOVW R15, R2, or a call of ml_raise_c (BL): else R2 was
	 * not set, a raise of code older than this (an object mk did not
	 * make again when mini-ml changed), and the guess says it */
	if(!load(pc, &w) || (w != 0xe1a0200f && (w & 0x0f000000) != 0x0b000000))
		return 0;
	len = 0;
	for(n = 0; n < 40 && function(pc, &f); n++){
		len = add(b, len, max, n == 0 ? " " : " < ", n == 0 ? 1 : 3);
		len = add(b, len, max, (char*)f.name, f.len);
		if(pc != f.start){
			len = add(b, len, max, "+0x", 3);
			s = digits(pc - f.start, 16, 0, d, 20);
			len = add(b, len, max, d + s, 20 - s);
		}
		line = pc2line(pc);
		if(line > 0 && fileline(pc, line, &file, &flen, &fl)){
			len = add(b, len, max, " ", 1);
			len = add(b, len, max, (char*)file, flen);
			len = add(b, len, max, ":", 1);
			s = digits(fl, 10, 0, d, 20);
			len = add(b, len, max, d + s, 20 - s);
		}
		if(f.len == 5 && memcmp(f.name, "_main", 5) == 0)
			break;
		/* the caller's address, and how far the caller's sp is: the
		 * link register before the save (the innermost frame only) */
		if(f.type == 'L' || f.type == 'l')
			leaf = !prologue(f.start, &size, &saved);
		else{
			leaf = 0;
			size = f.frame;
			saved = f.start;
		}
		if(leaf || pc <= saved){
			if(n > 0)
				break;
			ra = ml_raise_lr;
			if(leaf || pc == f.start)
				size = 0;
		}else if(load(sp, &w))
			ra = w;
		else
			break;
		/* the call: one instruction before where it returns */
		if(ra == 0 || (ra == pc && size == 0))
			break;
		pc = ra - 4;
		sp += size;
	}
	b[len] = 0;
	return len;
}
#endif
