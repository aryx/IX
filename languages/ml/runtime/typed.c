/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* An exception's arguments by their types */
/*****************************************************************************/

/* plan_debugger.md, stage 5: an uncaught exception says its arguments
 * as OCaml's toplevel says values,
 *     Bad(Rect (3, -4), {x = 1; y = 2; name = "origin"}, [1; 2], Some "why")
 * where their words say Bad(#1(3, -4), (1, 2, "origin"), (1, (2, 0)),
 * ("why")). The types are mini-ml -g's descriptions (Acid_ml), acid's
 * text in the program's .acid (mini-ld -g; frames.c finds it by the
 * table), lines of lists:
 *     mltypes = append mltypes, {"Typed.shape", {}, "variant",
 *         {"Empty"}, {"Circle", {"float"}}, {"Rect", {"int"}, {"int"}}};
 *     mlexns = append mlexns, {"Typed.Bad", {"Typed.shape"}, ...};
 * an exception found by its block's symbol (its value's first field).
 * The text is read in place, an element a pointer to its '{' or its
 * '"'. Nothing is allocated while a value is printed: it stays where it
 * is. Without a description (no table, an exception of a unit not
 * compiled with -g, a value not of its type's shape): the words.
 * port.acid's mlt prints a value by the same descriptions, in acid.
 * Here, not in Printexc: the runtime is in every program, where
 * Printexc and the String it needs are 190 KB a hello world does not
 * link (its to_string asks here, ml_exn_string). */

static char xbuf[1024];
static int xlen;

static void
xput(char *s, int n)
{
	int i;

	for(i = 0; i < n && xlen < sizeof xbuf - 1; i++)
		xbuf[xlen++] = s[i];
}

static void
xs(char *s)
{
	xput(s, strlen(s));
}

static void
xint(value n)
{
	char d[24];
	int s;

	if(n < 0){
		s = digits(-(uvalue)n, 10, 0, d, 24);
		d[--s] = '-';
	}else
		s = digits(n, 10, 0, d, 24);
	xput(d + s, 24 - s);
}

/* a character as %S and %C write it: the quote, the backslash, a line */
static void
xchar(int c, int quote)
{
	char e[2];

	e[0] = '\\';
	e[1] = c == '\n' ? 'n' : c == '\t' ? 't' : c;
	if(c == quote || c == '\\' || c == '\n' || c == '\t')
		xput(e, 2);
	else{
		e[0] = c;
		xput(e, 1);
	}
}

static void
xstring(value v)
{
	uchar *p;
	value i;

	p = (uchar*)Bytes(v);
	xs("\"");
	for(i = 0; i < length(v); i++)
		xchar(p[i], '"');
	xs("\"");
}

/* string_of_float's */
static void
xfloat(value v)
{
	char b[64];

	snprint(b, sizeof b, "%.12g", Double_val(v));
	xs(b);
}

/* a value by its words: an integer, a string, a float, a block's
 * fields (#tag first when it is not 0), d blocks deep */
static void
xwords(value v, int d)
{
	value i;

	if(Is_int(v))
		xint(Long_val(v));
	else if(Tag(v) == String_tag)
		xstring(v);
	else if(Tag(v) == Double_tag)
		xfloat(v);
	else if(Tag(v) == Closure_tag)
		xs("<fun>");
	else if(Tag(v) > Closure_tag)
		xs("_");
	else if(d == 0)
		xs("...");
	else{
		if(Tag(v) != 0){
			xs("#");
			xint(Tag(v));
		}
		xs("(");
		for(i = 0; i < Wosize(v); i++){
			if(i > 0)
				xs(", ");
			xwords(Field(v, i), d - 1);
		}
		xs(")");
	}
}

/* the descriptions' text, a list's elements: the one after e, past
 * the commas; nil at the list's end */
static char*
elskip(char *p)
{
	while(*p == ' ' || *p == ',' || *p == '\n')
		p++;
	return *p == '{' || *p == '"' ? p : nil;
}

static char*
elafter(char *e)
{
	int depth;

	if(*e == '"'){
		for(e++; *e != 0 && *e != '"'; e++)
			;
		return *e != 0 ? e + 1 : e;
	}
	depth = 0;
	for(; *e != 0; e++){
		if(*e == '"')
			e = elafter(e) - 1;
		else if(*e == '{')
			depth++;
		else if(*e == '}' && --depth == 0)
			return e + 1;
	}
	return e;
}

static char*
elfirst(char *l)
{
	return l != nil && *l == '{' ? elskip(l + 1) : nil;
}

static char*
elnext(char *e)
{
	return e != nil ? elskip(elafter(e)) : nil;
}

static char*
elnth(char *l, int n)
{
	char *e;

	for(e = elfirst(l); e != nil && n > 0; n--)
		e = elnext(e);
	return e;
}

static int
elcount(char *l)
{
	char *e;
	int n;

	n = 0;
	for(e = elfirst(l); e != nil; e = elnext(e))
		n++;
	return n;
}

/* whether e is the string s, of n characters */
static int
elis(char *e, char *s, int n)
{
	return e != nil && *e == '"' && memcmp(e + 1, s, n) == 0 && e[n + 1] == '"';
}

static int
eliss(char *e, char *s)
{
	return elis(e, s, strlen(s));
}

static int
ellen(char *e)
{
	char *q;

	for(q = e + 1; *q != 0 && *q != '"'; q++)
		;
	return q - e - 1;
}

/* the list on a line after key whose first element is the string name,
 * or nil (none, or no descriptions) */
static char*
described(char *key, char *name, int n)
{
#ifndef __GNUC__
	char *p;
	int k;

	k = strlen(key);
	for(p = acidtext(); p != nil && *p != 0; ){
		if(memcmp(p, key, k) == 0 && elis(elfirst(p + k), name, n))
			return p + k;
		while(*p != 0 && *p != '\n')
			p++;
		if(*p != 0)
			p++;
	}
#else
	USED(key);
	USED(name);
	USED(n);
#endif
	return nil;
}

/* a described type's variables: its params ({"'a", ...}), the type
 * that names it ({"Typed.tree", {"int"}}: the arguments after its
 * path), whose own variables are up's */
typedef struct Env Env;
struct Env {
	char *params;
	char *args;
	Env *up;
};

static void xval(value v, char *t, Env *env, int d);

/* in parentheses, what was printed since start, when it is a negative
 * number or a constructor's with arguments (OCaml's Some (-5)) */
static void
xparen(int start)
{
	int i, sp;

	sp = 0;
	for(i = start; i < xlen; i++)
		if(xbuf[i] == ' ')
			sp = 1;
	if(xlen == start || xlen + 2 >= sizeof xbuf
	|| !(xbuf[start] == '-' || (xbuf[start] >= 'A' && xbuf[start] <= 'Z' && sp)))
		return;
	memmove(xbuf + start + 1, xbuf + start, xlen - start);
	xbuf[start] = '(';
	xlen++;
	xs(")");
}

/* the fields of v from the types ts on, separated by sep */
static void
xfields(value v, char *ts, Env *env, int d, char *sep)
{
	value i;

	for(i = 0; ts != nil; i++, ts = elnext(ts)){
		if(i > 0)
			xs(sep);
		xval(Field(v, i), ts, env, d - 1);
	}
}

/* v by its type t (a list, its path first), d deep */
static void
xval(value v, char *t, Env *env, int d)
{
	char *n, *desc, *k, *e, *c;
	Env sub;
	value i;
	int at;

	/* a variable: the type it stands for */
	for(n = elfirst(t); n != nil && n[1] == '\'' && env != nil; n = elfirst(t)){
		for(e = elfirst(env->params), i = 1; e != nil && !elis(e, n + 1, ellen(n)); e = elnext(e))
			i++;
		if(e == nil)
			break;
		t = elnth(env->args, i);
		env = env->up;
	}
	if(n == nil || *n != '"' || n[1] == '\''){
		xwords(v, d);
		return;
	}
	if(d == 0){
		xs("...");
		return;
	}
	if(eliss(n, "int") && Is_int(v))
		xint(Long_val(v));
	else if(eliss(n, "char") && Is_int(v)){
		xs("'");
		xchar(Long_val(v), '\'');
		xs("'");
	}else if(eliss(n, "bool") && Is_int(v))
		xs(Long_val(v) ? "true" : "false");
	else if(eliss(n, "unit"))
		xs("()");
	else if(eliss(n, "->"))
		xs("<fun>");
	else if(eliss(n, "list")){
		xs("[");
		for(i = 0; !Is_int(v) && i < 32; i++){
			if(i > 0)
				xs("; ");
			xval(Field(v, 0), elnext(n), env, d - 1);
			v = Field(v, 1);
		}
		if(!Is_int(v))
			xs("; ...");
		xs("]");
	}else if(eliss(n, "array") && !Is_int(v) && Tag(v) == 0){
		xs("[|");
		for(i = 0; i < Wosize(v) && i < 32; i++){
			if(i > 0)
				xs("; ");
			xval(Field(v, i), elnext(n), env, d - 1);
		}
		xs("|]");
	}else if(eliss(n, "*") && !Is_int(v) && Tag(v) == 0 && Wosize(v) == elcount(t) - 1){
		xs("(");
		xfields(v, elnext(n), env, d, ", ");
		xs(")");
	}else if((eliss(n, "string") || eliss(n, "bytes")) && !Is_int(v) && Tag(v) == String_tag)
		xstring(v);
	else if(eliss(n, "float") && !Is_int(v) && Tag(v) == Double_tag)
		xfloat(v);
	else if((desc = described("mltypes = append mltypes, ", n + 1, ellen(n))) != nil
	&& elcount(elnth(desc, 1)) == elcount(t) - 1){
		/* {path, params, kind, ...} */
		sub.params = elnth(desc, 1);
		sub.args = t;
		sub.up = env;
		k = elnth(desc, 2);
		if(eliss(k, "="))
			xval(v, elnext(k), &sub, d);
		else if(eliss(k, "variant") && Is_int(v) && (e = elnth(elnext(k), Long_val(v))) != nil)
			xput(e + 1, ellen(e));
		else if(eliss(k, "variant") && !Is_int(v) && (c = elnth(desc, 4 + Tag(v))) != nil
		&& elcount(c) - 1 == Wosize(v)){
			/* {"C", t1, ...} */
			xput(elfirst(c) + 1, ellen(elfirst(c)));
			xs(" ");
			if(Wosize(v) == 1){
				at = xlen;
				xval(Field(v, 0), elnth(c, 1), &sub, d - 1);
				xparen(at);
			}else{
				xs("(");
				xfields(v, elnth(c, 1), &sub, d, ", ");
				xs(")");
			}
		}else if(eliss(k, "record") && !Is_int(v) && Tag(v) == 0 && Wosize(v) == elcount(desc) - 3){
			xs("{");
			for(i = 0, e = elnext(k); e != nil; i++, e = elnext(e)){
				if(i > 0)
					xs("; ");
				xput(elfirst(e) + 1, ellen(elfirst(e)));
				xs(" = ");
				xval(Field(v, i), elnth(e, 1), &sub, d - 1);
			}
			xs("}");
		}else
			xwords(v, d);
	}else
		xwords(v, d);
}

/* an exception, its name and its arguments, in xbuf: by their types
 * when the program describes them, else their words (a single tuple's
 * fields alone, as Match_failure's) */
static void
xexn(value exn)
{
	value id, name, b, i, start;
	char *d, *e;
#ifndef __GNUC__
	uchar *sym;
	long n;
#endif

	id = Field(exn, 0);
	name = Field(id, 0);
	xput((char*)Bytes(name), length(name));
	if(Wosize(exn) < 2)
		return;
	d = nil;
#ifndef __GNUC__
	if(acidtext() != nil && (sym = datasym((uvalue)id - sizeof(value), &n)) != nil)
		d = described("mlexns = append mlexns, ", (char*)sym, n);
#endif
	xs("(");
	if(d != nil && elcount(d) == Wosize(exn))
		for(i = 1, e = elnth(d, 1); e != nil; i++, e = elnext(e)){
			if(i > 1)
				xs(", ");
			xval(Field(exn, i), e, nil, 6);
		}
	else{
		b = exn;
		start = 1;
		if(Wosize(exn) == 2 && !Is_int(Field(exn, 1)) && Tag(Field(exn, 1)) == 0){
			b = Field(exn, 1);
			start = 0;
		}
		for(i = start; i < Wosize(b); i++){
			if(i > start)
				xs(", ");
			xwords(Field(b, i), 3);
		}
	}
	xs(")");
}

/* Printexc.to_string's, for an exception its printers do not know */
value
ml_exn_string(value exn)
{
	xlen = 0;
	xexn(exn);
	xbuf[xlen] = 0;
	return ml_string(xbuf);
}
