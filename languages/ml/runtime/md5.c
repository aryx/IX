/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Digest: MD5 (RFC 1321) */
/*****************************************************************************/

typedef struct MD5 MD5;
struct MD5 {
	unsigned int h[4];
	uvlong len;             /* the bytes added */
	uchar buf[64];          /* those of the block not yet full */
};

/* 2^32 |sin(i + 1)|: a table, not computed, for arm has no floats here */
static unsigned int md5_k[64] = {
	0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
	0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
	0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
	0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
	0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
	0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
	0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
	0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
	0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
	0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
	0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
	0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
	0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
	0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
	0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
	0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};
/* a round's four rotations */
static uchar md5_s[16] = { 7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21 };

static void
md5_block(MD5 *m)
{
	unsigned int a, b, c, d, f, t, w[16];
	uchar *p;
	int i, g, r;

	p = m->buf;
	for(i = 0; i < 16; i++, p += 4)
		w[i] = p[0] | p[1] << 8 | p[2] << 16 | (unsigned int)p[3] << 24;
	a = m->h[0]; b = m->h[1]; c = m->h[2]; d = m->h[3];
	for(i = 0; i < 64; i++){
		/* without ~ on 32 bits: 7c's EORW $0xffffffff is an illegal
		 * instruction by 7l (and so by mini-ld, its twin). The first two
		 * are (b & c) | (~b & d) and (d & b) | (~d & c); ~d is -1 - d */
		switch(i >> 4){
		case 0: f = d ^ (b & (c ^ d)); g = i; break;
		case 1: f = c ^ (d & (b ^ c)); g = (5 * i + 1) & 15; break;
		case 2: f = b ^ c ^ d; g = (3 * i + 5) & 15; break;
		default: f = c ^ (b | (0xffffffff - d)); g = (7 * i) & 15; break;
		}
		t = a + f + md5_k[i] + w[g];
		r = md5_s[(i >> 4) * 4 + (i & 3)];
		a = d; d = c; c = b;
		b += t << r | t >> (32 - r);
	}
	m->h[0] += a; m->h[1] += b; m->h[2] += c; m->h[3] += d;
}

static void
md5_init(MD5 *m)
{
	m->h[0] = 0x67452301; m->h[1] = 0xefcdab89; m->h[2] = 0x98badcfe; m->h[3] = 0x10325476;
	m->len = 0;
}

static void
md5_add(MD5 *m, uchar *p, long n)
{
	long i;

	for(i = 0; i < n; i++){
		m->buf[m->len++ & 63] = p[i];
		if((m->len & 63) == 0)
			md5_block(m);
	}
}

/* the padding (a 1 bit, zeros, the length in bits), then the digest:
 * the 16 bytes of an ML string */
static value
md5_end(MD5 *m)
{
	uchar pad[8], b;
	uvlong bits;
	value s;
	int i;

	bits = m->len * 8;
	for(i = 0; i < 8; i++)
		pad[i] = bits >> (8 * i);
	b = 0x80;
	md5_add(m, &b, 1);
	b = 0;
	while((m->len & 63) != 56)
		md5_add(m, &b, 1);
	md5_add(m, pad, 8);
	s = string_alloc(16);
	for(i = 0; i < 16; i++)
		Bytes(s)[i] = m->h[i >> 2] >> (8 * (i & 3));
	return s;
}

value
md5_string(value s, value ofs, value len)
{
	MD5 m;

	md5_init(&m);
	md5_add(&m, Bytes(s) + Long_val(ofs), Long_val(len));
	return md5_end(&m);
}

/* len bytes of the channel (End_of_file if it has fewer), or with a
 * negative len all that is left */
value
md5_chan(value ch, value len)
{
	MD5 m;
	value n;
	int b;
	uchar c;

	md5_init(&m);
	for(n = Long_val(len); n != 0; n--){
		b = getc_chan((Chan*)ch);
		if(b < 0){
			if(n > 0)
				raise_const(caml_exn_End_of_file);
			break;
		}
		c = b;
		md5_add(&m, &c, 1);
	}
	return md5_end(&m);
}
