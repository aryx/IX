/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Strings: the last byte the number of padding bytes before it */
/*****************************************************************************/

static value
string_alloc(value len)
{
	value w, s;

	w = len / W + 1;
	s = ml_alloc(w, String_tag);
	Field(s, w - 1) = 0;
	Bytes(s)[w * W - 1] = w * W - 1 - len;
	return s;
}

static value
length(value s)
{
	return Wosize(s) * W - 1 - Bytes(s)[Wosize(s) * W - 1];
}

/* a C string as an ML one */
value
ml_string(char *s)
{
	value r, n;

	n = strlen(s);
	r = string_alloc(n);
	memmove(Bytes(r), s, n);
	return r;
}

value
ml_string_length(value s)
{
	return Val_int(length(s));
}

static void
bound(value s, value i)
{
	if(i < 0 || i >= length(s))
		ml_raise(bound_exn);
}

value
ml_string_get(value s, value i)
{
	bound(s, Long_val(i));
	return Val_int(Bytes(s)[Long_val(i)]);
}

value
ml_string_set(value s, value i, value c)
{
	bound(s, Long_val(i));
	Bytes(s)[Long_val(i)] = Long_val(c);
	return Val_unit;
}

void
caml_array_bound_error(void)
{
	ml_raise(bound_exn);
}

value
create_string(value n)
{
	return string_alloc(Long_val(n));
}

/* OPTIMIZATION: a string's bytes copied and filled a word at a time
 * (the bytes before the first whole word and after the last, one by
 * one): the C library's memmove is a byte a turn, and the fill was so
 * here; a frame of pixels a program makes is a megabyte cleared, then
 * copied (docs/plans/plan_playground_speed.md: the two were 29% of a
 * frame's instructions). Words when the two places are a multiple of a
 * word apart and the copy can go forward.
 * old: memmove(Bytes(s2) + Long_val(o2), Bytes(s1) + Long_val(o1), Long_val(n));
 *   for(i = 0; i < Long_val(n); i++) Bytes(s)[Long_val(o) + i] = Long_val(c); */
static void
move_bytes(char *d, char *s, value n)
{
	if((((uvalue)d ^ (uvalue)s) & (W - 1)) != 0 || (d > s && d < s + n)){
		memmove(d, s, n);
		return;
	}
	while(n > 0 && ((uvalue)d & (W - 1)) != 0){
		*d++ = *s++;
		n--;
	}
	for(; n >= W; n -= W){
		*(value*)d = *(value*)s;
		d += W;
		s += W;
	}
	while(n > 0){
		*d++ = *s++;
		n--;
	}
}

value
blit_string(value s1, value o1, value s2, value o2, value n)
{
	move_bytes((char*)Bytes(s2) + Long_val(o2), (char*)Bytes(s1) + Long_val(o1), Long_val(n));
	return Val_unit;
}

value
fill_string(value s, value o, value n, value c)
{
	char *p;
	uvalue w;

	p = (char*)Bytes(s) + Long_val(o);
	n = Long_val(n);
	c = Long_val(c) & 255;
	w = c | (c << 8);
	w = w | (w << 16);
	if(W == 8)
		w = w | ((w << 16) << 16);
	while(n > 0 && ((uvalue)p & (W - 1)) != 0){
		*p++ = c;
		n--;
	}
	for(; n >= W; n -= W){
		*(uvalue*)p = w;
		p += W;
	}
	while(n > 0){
		*p++ = c;
		n--;
	}
	return Val_unit;
}

value
is_printable(value c)
{
	c = Long_val(c);
	return Val_bool(c >= 32 && c < 127);
}

value
caml_string_equal(value a, value b)
{
	value n;

	n = length(a);
	if(n != length(b))
		return Val_false;
	return Val_bool(memcmp(Bytes(a), Bytes(b), n) == 0);
}

/* n's digits, in base b, at the end of buf; where they start */
static int
digits(uvalue n, int b, int upper, char *buf, int end)
{
	int d;

	do {
		d = n % b;
		buf[--end] = d < 10 ? '0' + d : (upper ? 'A' : 'a') + d - 10;
		n = n / b;
	} while(n != 0);
	return end;
}

/* the same for what a word doesn't hold: an int64 on arm */
static int
digits64(uvlong n, int b, int upper, char *buf, int end)
{
	int d;

	do {
		d = n % b;
		buf[--end] = d < 10 ? '0' + d : (upper ? 'A' : 'a') + d - 10;
		n = n / b;
	} while(n != 0);
	return end;
}

/* printf's integers: %[-0 +]width[d i u x X o], as C's; n of bits bits
 * when it is printed unsigned: 31 or 63 an int's, as ocaml-light's,
 * 32 and 64 an int32's and an int64's */
static value
format_num(value fmt, vlong n, int bits)
{
	char buf[96];
	uchar *f;
	int i, start, left, zero, sign, space, width, neg, b, upper, len, pad, k;
	uvlong u;

	f = Bytes(fmt);
	left = zero = sign = space = width = 0;
	for(i = 1; f[i] == '-' || f[i] == '0' || f[i] == '+' || f[i] == ' '; i++)
		switch(f[i]){
		case '-': left = 1; break;
		case '0': zero = 1; break;
		case '+': sign = 1; break;
		case ' ': space = 1; break;
		}
	while(f[i] >= '0' && f[i] <= '9')
		width = width * 10 + f[i++] - '0';
	while(f[i] == 'l' || f[i] == 'n' || f[i] == 'L')
		i++;
	b = 10; upper = 0; neg = 0;
	switch(f[i]){
	case 'x': b = 16; break;
	case 'X': b = 16; upper = 1; break;
	case 'o': b = 8; break;
	}
	if((f[i] == 'd' || f[i] == 'i') && n < 0){
		neg = 1;
		u = -(uvlong)n;
	}else if((b != 10 || f[i] == 'u') && bits < 64)
		u = (uvlong)n & (((uvlong)1 << bits) - 1);
	else
		u = n;
	start = u == (uvalue)u ? digits(u, b, upper, buf, 64) : digits64(u, b, upper, buf, 64);
	if(neg)
		buf[--start] = '-';
	else if(sign)
		buf[--start] = '+';
	else if(space)
		buf[--start] = ' ';
	len = 64 - start;
	pad = width > len ? width - len : 0;
	k = 0;
	if(pad > 0 && !left && !zero)
		for(; k < pad; k++) buf[k] = ' ';
	if(pad > 0 && zero && !left){
		/* the sign first, then the zeros */
		if(neg || sign || space){
			buf[k++] = buf[start++];
			len--;
		}
		for(i = 0; i < pad; i++) buf[k++] = '0';
	}
	memmove(buf + k, buf + start, len);
	k += len;
	if(pad > 0 && left)
		for(i = 0; i < pad; i++) buf[k++] = ' ';
	buf[k] = 0;
	return ml_string(buf);
}

value format_int(value fmt, value arg) { return format_num(fmt, Long_val(arg), 8 * W - 1); }

/* an integer's value: -, then 0x 0o 0b or decimal, _ between digits;
 * who is the function that fails */
static vlong
parse_int(value s, char *who)
{
	uchar *p;
	value neg, b, d, len, i;
	uvlong n;

	p = Bytes(s);
	len = length(s);
	i = 0; neg = 0; n = 0; b = 10;
	if(i < len && p[i] == '-'){ neg = 1; i++; }
	else if(i < len && p[i] == '+')	/* as OCaml's: +5 */
		i++;
	if(i + 1 < len && p[i] == '0'){
		switch(p[i + 1]){
		case 'x': case 'X': b = 16; i += 2; break;
		case 'o': case 'O': b = 8; i += 2; break;
		case 'b': case 'B': b = 2; i += 2; break;
		}
	}
	if(i == len)
		goto bad;
	for(; i < len; i++){
		if(p[i] == '_')
			continue;
		if(p[i] >= '0' && p[i] <= '9') d = p[i] - '0';
		else if(p[i] >= 'a' && p[i] <= 'f') d = p[i] - 'a' + 10;
		else if(p[i] >= 'A' && p[i] <= 'F') d = p[i] - 'A' + 10;
		else goto bad;
		if(d >= b)
			goto bad;
		n = n * b + d;
	}
	return neg ? -(vlong)n : (vlong)n;
bad:
	failwith(who);
	return 0;
}

value int_of_string(value s) { return Val_int((value)parse_int(s, "int_of_string")); }
