/* tests/check.sh: ix/vlrt.c's functions against gcc's 64 bits, on random
 * and chosen values. (long is 32 bits for Plan 9's compilers.) */
#define long int
#define abort ix_abort
#include "../ix/vlrt.c"
#undef long
#undef abort
#include <stdio.h>
#include <stdint.h>
#include <string.h>

void ix_abort(void) { printf("abort\n"); }

static int bad;
static uint64_t seed = 88172645463325252ULL;
static uint64_t rnd(void) { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return seed; }

static Vlong V(uint64_t x) { Vlong v; v.lo = x; v.hi = x >> 32; return v; }
static uint64_t U(Vlong v) { return (uint64_t)v.hi << 32 | v.lo; }

static void
eq(char *what, uint64_t a, uint64_t b, uint64_t got, uint64_t want)
{
	if(got != want && bad++ < 20)
		printf("%s %#llx %#llx: %#llx, not %#llx\n", what, (long long)a, (long long)b, (long long)got, (long long)want);
}

static uint64_t
pick(void)
{
	static uint64_t edge[] = { 0, 1, 2, 3, 10, 0x7fffffff, 0x80000000u, 0xffffffffu, 0x100000000ull, 0x1ffffffffull,
		0x7fffffffffffffffull, 0x8000000000000000ull, 0xffffffffffffffffull, 0xfffffffffffffffeull, 0xffffffff00000000ull, 1000000000 };
	uint64_t r;

	r = rnd();
	switch(r & 7){
	case 0: return edge[(r >> 3) % (sizeof edge / sizeof edge[0])];
	case 1: return (r >> 3) & 0xffff;				/* small */
	case 2: return -(int64_t)((r >> 3) & 0xffff);	/* small, negative */
	case 3: return r >> (r >> 58);				/* any size */
	case 4: return (int64_t)r >> (r >> 58);
	default: return r;
	}
}

int
main(void)
{
	Vlong r, l, v;
	uint64_t a, b, x;
	int64_t sa, sb;
	int i, s, ty;
	double d;
	static void (*ops[])(Vlong*, Vlong, Vlong) = { _addv, _subv, _andv, _orv, _xorv };

	for(i = 0; i < 3000000; i++){
		a = pick(); b = pick(); sa = a; sb = b;
		_addv(&r, V(a), V(b)); eq("add", a, b, U(r), a + b);
		_subv(&r, V(a), V(b)); eq("sub", a, b, U(r), a - b);
		_andv(&r, V(a), V(b)); eq("and", a, b, U(r), a & b);
		_orv(&r, V(a), V(b)); eq("or", a, b, U(r), a | b);
		_xorv(&r, V(a), V(b)); eq("xor", a, b, U(r), a ^ b);
		for(s = 0; s < 64; s += 1 + i % 7){
			_lshv(&r, V(a), s); eq("lsh", a, s, U(r), a << s);
			_rshlv(&r, V(a), s); eq("rshl", a, s, U(r), a >> s);
			_rshav(&r, V(a), s); eq("rsha", a, s, U(r), sa >> s);
		}
		if(b != 0){
			_divvu(&r, V(a), V(b)); eq("divu", a, b, U(r), a / b);
			_modvu(&r, V(a), V(b)); eq("modu", a, b, U(r), a % b);
			if(!(sa == INT64_MIN && sb == -1) && !((int32_t)a == INT32_MIN && (int32_t)b == -1)){
				_divv(&r, V(a), V(b)); eq("div", a, b, U(r), sa / sb);
				_modv(&r, V(a), V(b)); eq("mod", a, b, U(r), sa % sb);
			}
		}
		v = V(a); _vpp(&l, &v); eq("x++", a, 0, U(l), a); eq("x++ x", a, 0, U(v), a + 1);
		v = V(a); _vmm(&l, &v); eq("x--", a, 0, U(l), a); eq("x-- x", a, 0, U(v), a - 1);
		v = V(a); _ppv(&l, &v); eq("++x", a, 0, U(l), a + 1); eq("++x x", a, 0, U(v), a + 1);
		v = V(a); _mmv(&l, &v); eq("--x", a, 0, U(l), a - 1); eq("--x x", a, 0, U(v), a - 1);

		_sl2v(&r, (int32_t)a); eq("sl2v", a, 0, U(r), (int64_t)(int32_t)a);
		_si2v(&r, (int32_t)a); eq("si2v", a, 0, U(r), (int64_t)(int32_t)a);
		_ul2v(&r, (uint32_t)a); eq("ul2v", a, 0, U(r), (uint32_t)a);
		_ui2v(&r, (uint32_t)a); eq("ui2v", a, 0, U(r), (uint32_t)a);
		_sh2v(&r, (int32_t)a); eq("sh2v", a, 0, U(r), (int64_t)(int16_t)a);
		_uh2v(&r, (uint32_t)a); eq("uh2v", a, 0, U(r), (uint16_t)a);
		_sc2v(&r, (int32_t)a); eq("sc2v", a, 0, U(r), (int64_t)(int8_t)a);
		_uc2v(&r, (uint32_t)a); eq("uc2v", a, 0, U(r), (uint8_t)a);
		eq("v2sc", a, 0, _v2sc(V(a)), (int32_t)(int8_t)a); eq("v2uc", a, 0, _v2uc(V(a)), (uint8_t)a);
		eq("v2sh", a, 0, _v2sh(V(a)), (int32_t)(int16_t)a); eq("v2uh", a, 0, _v2uh(V(a)), (uint16_t)a);
		eq("v2sl", a, 0, (uint32_t)_v2sl(V(a)), (uint32_t)a); eq("v2ul", a, 0, (uint32_t)_v2ul(V(a)), (uint32_t)a);
		eq("v2si", a, 0, (uint32_t)_v2si(V(a)), (uint32_t)a); eq("v2ui", a, 0, (uint32_t)_v2ui(V(a)), (uint32_t)a);

		eq("test", a, 0, _testv(V(a)), a != 0);
		eq("eq", a, b, _eqv(V(a), V(b)), a == b); eq("ne", a, b, _nev(V(a), V(b)), a != b);
		eq("lt", a, b, _ltv(V(a), V(b)), sa < sb); eq("le", a, b, _lev(V(a), V(b)), sa <= sb);
		eq("gt", a, b, _gtv(V(a), V(b)), sa > sb); eq("ge", a, b, _gev(V(a), V(b)), sa >= sb);
		eq("lo", a, b, _lov(V(a), V(b)), a < b); eq("ls", a, b, _lsv(V(a), V(b)), a <= b);
		eq("hi", a, b, _hiv(V(a), V(b)), a > b); eq("hs", a, b, _hsv(V(a), V(b)), a >= b);
		eq("eq same", a, a, _eqv(V(a), V(a)), 1); eq("le same", a, a, _lev(V(a), V(a)), 1); eq("hs same", a, a, _hsv(V(a), V(a)), 1);

		/* (a double's conversion to a vlong is exact up to 2^63) */
		d = (double)sa; memcpy(&x, &d, 8);
		if(d < 9.2e18 && d > -9.2e18){ _d2v(&r, d); eq("d2v", a, 0, U(r), (int64_t)d); }
		d = (double)(sa >> (i % 40)) / 8; if(1){ _d2v(&r, d); eq("d2v", a, 1, U(r), (int64_t)d); }
		d = _v2d(V(a)); memcpy(&x, &d, 8); d = (double)sa; memcpy(&b, &d, 8); eq("v2d", a, 0, x, b);

		/* lv op= rv, on each type */
		a = pick(); b = pick();
		for(ty = 1; ty <= 10; ty++){
			uint64_t cell, want, wcell;
			int op = i % 5;

			cell = a;
			switch(ty){
			case 1: x = (int64_t)(int8_t)a; break;
			case 2: x = (uint8_t)a; break;
			case 3: x = (int64_t)(int16_t)a; break;
			case 4: x = (uint16_t)a; break;
			case 5: case 9: x = (int64_t)(int32_t)a; break;
			case 6: case 10: x = (uint32_t)a; break;
			default: x = a; break;
			}
			want = op == 0 ? x + b : op == 1 ? x - b : op == 2 ? x & b : op == 3 ? x | b : x ^ b;
			wcell = a;
			memcpy(&wcell, &want, ty <= 2 ? 1 : ty <= 4 ? 2 : ty == 7 || ty == 8 ? 8 : 4);
			r = V(0);
			_vasop(&r, &cell, ops[op], ty, V(b));
			eq("vasop", a, ty, U(r), want); eq("vasop cell", a, ty, cell, wcell);
		}
	}
	printf("vlrt: %d differences\n", bad);
	return bad != 0;
}
