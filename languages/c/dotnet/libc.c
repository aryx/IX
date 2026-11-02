// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// mini-cc -dotnet's C library: the part of Plan 9's libc the programs
// use (tiny/tests/TinyC_tests/libc.h), in the managed C itself,
// compiled with each program, read after it (mini-cc -L: this
// directory). Beneath it two functions of .NET's, which the compiler
// makes calls (Cil_exprs): _write, the console's bytes (Stream.Write),
// and _exit (Environment.Exit). And what the compiler does itself:
// malloc a new array of the pointer's type, free nothing (the
// collector's), print and sprint their format compiled, each piece a
// call of _puts, _putc or _putint below, between _begin and _end.

extern void _write(unsigned char*, int);
extern void _exit(int);

unsigned char _obuf[4096];
int _on;
char *_sbuf;	// sprint's buffer; nil: the console
int _sn;	// what is printed

void
_flush(void)
{
	if(_on > 0)
		_write(_obuf, _on);
	_on = 0;
}

void
_putc(int c)
{
	if(_sbuf != 0)
		_sbuf[_sn] = c;
	else{
		_obuf[_on++] = c;
		if(_on == sizeof _obuf)
			_flush();
	}
	_sn++;
}

// flags: 1 left-justified, 2 zeros before
void
_puts(char *s, int width, int flags)
{
	int n;

	n = 0;
	if(s == 0)
		s = "<nil>";
	while(s[n])
		n++;
	if((flags & 1) == 0)
		for(; n < width; width--)
			_putc(' ');
	for(; *s; s++)
		_putc(*s);
	for(; n < width; width--)
		_putc(' ');
}

void
_putint(long long v, int base, int upper, int width, int flags)
{
	char buf[72];
	int n, neg;
	unsigned long long u;

	neg = base == 10 && v < 0;
	u = neg ? -v : v;
	n = sizeof buf;
	buf[--n] = 0;
	do{
		buf[--n] = (upper ? "0123456789ABCDEF" : "0123456789abcdef")[u % base];
		u /= base;
	}while(u != 0);
	if((flags & 2) != 0)
		while(sizeof buf - 1 - n < width - neg)
			buf[--n] = '0';
	if(neg)
		buf[--n] = '-';
	_puts(buf + n, width, flags);
}

void
_begin(char *s)
{
	_sbuf = s;
	_sn = 0;
}

int
_end(void)
{
	if(_sbuf != 0)
		_sbuf[_sn] = 0;
	_sbuf = 0;
	return _sn;
}

void
exits(char *s)
{
	_flush();
	_exit(s != 0 && *s != 0);
}

long
strlen(char *s)
{
	long n;

	n = 0;
	while(s[n])
		n++;
	return n;
}

char*
strcpy(char *d, char *s)
{
	char *p;

	p = d;
	while(*p++ = *s++)
		;
	return d;
}

int
strcmp(char *a, char *b)
{
	for(; *a == *b; a++, b++)
		if(*a == 0)
			return 0;
	return (*a & 0xFF) - (*b & 0xFF);
}

int
atoi(char *s)
{
	int n, neg;

	n = 0;
	while(*s == ' ' || *s == '\t')
		s++;
	neg = *s == '-';
	if(*s == '-' || *s == '+')
		s++;
	while(*s >= '0' && *s <= '9')
		n = n * 10 + *s++ - '0';
	return neg ? -n : n;
}
