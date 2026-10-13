/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Channels: ocaml-light's io.c, a buffer written when full */
/*****************************************************************************/

typedef struct Chan Chan;
struct Chan {
	int fd;
	int len;                /* output: the bytes buffered; input: those left, */
	int pos;                /* from pos */
	vlong offset;
	uchar buf[4096];
};

value
caml_open_descriptor(value fd)
{
	Chan *c;

	c = malloc(sizeof(Chan));
	c->fd = Long_val(fd);
	c->len = 0;
	c->pos = 0;
	c->offset = 0;
	return (value)c;
}

static void
flush_chan(Chan *c)
{
	if(c->len > 0)
		write(c->fd, c->buf, c->len);
	c->offset += c->len;
	c->len = 0;
}

value
caml_flush(value ch)
{
	flush_chan((Chan*)ch);
	return Val_unit;
}

static void
putc_chan(Chan *c, int b)
{
	if(c->len == 4096)
		flush_chan(c);
	c->buf[c->len++] = b;
}

value
caml_output_char(value ch, value b)
{
	putc_chan((Chan*)ch, Long_val(b));
	return Val_unit;
}

value
caml_output(value ch, value s, value ofs, value len)
{
	value i;

	for(i = 0; i < Long_val(len); i++)
		putc_chan((Chan*)ch, Bytes(s)[Long_val(ofs) + i]);
	return Val_unit;
}

/* Linux's read, by its number: its answer says an interruption (-4,
 * EINTR), which a libc's read hides */
#define Interrupted (-4)
static int signalled[65];	/* the signals noted ([0]: one is); below */
static long
fill(Chan *c)
{
	long n;

	n = ux(W == 8 ? 63 : 3, c->fd, (value)c->buf, 4096, 0, 0, 0);
	if(n > 0){
		c->offset += n;
		c->len = n;
		c->pos = 0;
	}
	return n;
}

/* the next byte, or -1 at the end; a signal's interruption is not one
 * (the signal stays noted, for the next place that runs the handlers) */
static int
getc_chan(Chan *c)
{
	long n;

	if(c->len == 0){
		do n = fill(c); while(n == Interrupted);
		if(n <= 0)
			return -1;
	}
	c->len--;
	return c->buf[c->pos++];
}

value
caml_input_char(value ch)
{
	int b;

	b = getc_chan((Chan*)ch);
	if(b < 0)
		raise_const(caml_exn_End_of_file);
	return Val_int(b);
}

/* The three a program waits in (Pervasives' input_char, input and
 * input_line): interrupted by a signal, they say so (-2, -1, and
 * Scan_interrupted), for Pervasives to run the signal's handler, which
 * is OCaml's, and ask again. Interrupted too, without reading, when a
 * signal came before (signalled[0]: one is noted). */

static long
fill_or_signal(Chan *c)
{
	return signalled[0] ? Interrupted : fill(c);
}

value
ml_input_char(value ch)
{
	Chan *c;
	long n;

	c = (Chan*)ch;
	if(c->len == 0){
		n = fill_or_signal(c);
		if(n <= 0)
			return Val_int(n == Interrupted ? -2 : -1);
	}
	c->len--;
	return Val_int(c->buf[c->pos++]);
}

value
caml_input(value ch, value s, value ofs, value len)
{
	Chan *c;
	value n;
	int b;

	c = (Chan*)ch;
	if(c->len == 0 && Long_val(len) > 0 && fill_or_signal(c) == Interrupted)
		return Val_int(-1);
	n = 0;
	while(n < Long_val(len) && c->len > 0){
		b = getc_chan(c);
		if(b < 0)
			break;
		Bytes(s)[Long_val(ofs) + n] = b;
		n++;
	}
	return Val_int(n);
}

/* how far to the next newline (included), negated if the buffer ends
 * first: ocaml-light's input_scan_line, which input_line loops on */
#define Scan_interrupted (-100000)
value
caml_input_scan_line(value ch)
{
	Chan *c;
	int i;
	long n;

	c = (Chan*)ch;
	if(c->len == 0){
		n = fill_or_signal(c);
		if(n <= 0)
			return Val_int(n == Interrupted ? Scan_interrupted : 0);
	}
	for(i = 0; i < c->len; i++)
		if(c->buf[c->pos + i] == '\n')
			return Val_int(i + 1);
	return Val_int(-c->len);
}

value
caml_close_channel(value ch)
{
	Chan *c;

	c = (Chan*)ch;
	flush_chan(c);
	close(c->fd);
	return Val_unit;
}

