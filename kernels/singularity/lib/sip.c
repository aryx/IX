/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A process of mini-singularity: the system under its C library and
 * its run-time system (lib_core/libc, mini-ml's runtime.c, built as
 * for Linux), which reach it through one function, _syscall6. As the
 * kernel's own machine/shim.c, but here the system is the kernel's ABI
 * (Abi: the same numbers), called through the address the kernel gave
 * at the start: write is the debug line, exit the process's end, the
 * others say ENOSYS. */
#include <mlvalues.h>

/* Linux's numbers and a call's word, for arm (the Pi 1) and arm64 (the Pi 4) */
#ifdef arm
#define WRITE 4
#define EXIT 1
#define EXIT_GROUP 248
typedef long word;
#else
#define WRITE 64
#define EXIT 93
#define EXIT_GROUP 94
typedef vlong word;
#endif

/* Abi's: the two the C library's calls become */
enum { ABI_EXIT = 0, ABI_DEBUG = 1 };

extern void main(int, char**);
extern word sip_abi(word*);
/* the kernel's entry (start_*.s) */
uintptr sip_kernel;

/* A call: its number and its arguments, words the kernel reads here,
 * and where it leaves an answer's second word and the next. */
enum { WORDS = 8 };
static word words[WORDS];

static word
abi(word n, word a1, word a2, word a3, word a4)
{
	words[0] = n;
	words[1] = a1;
	words[2] = a2;
	words[3] = a3;
	words[4] = a4;
	return sip_abi(words);
}

word
_syscall6(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	switch((int)n){
	case WRITE:	/* any descriptor is the debug line */
		return abi(ABI_DEBUG, a2, a3, 0, 0);
	case EXIT:
	case EXIT_GROUP:
		abi(ABI_EXIT, a1, 0, 0, 0);
	}
	return -38;
}

/* the same, for the calls whose answer is 64 bits (lseek) */
word
_syscall6v(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	return _syscall6(n, a1, a2, a3, a4, a5, a6);
}

/* Sip's: a call of integers; one whose first argument is the address
 * of a string's or of bytes' first one (nothing is allocated before
 * the kernel returns: they do not move); a word of the last answer */
value
sip_call(value n, value a1, value a2, value a3, value a4)
{
	return Val_long(abi(Long_val(n), Long_val(a1), Long_val(a2), Long_val(a3), Long_val(a4)));
}

value
sip_call_s(value n, value s, value a2, value a3, value a4)
{
	return Val_long(abi(Long_val(n), (word)String_val(s), Long_val(a2), Long_val(a3), Long_val(a4)));
}

value sip_word(value i) { return Val_long(words[Long_val(i)]); }

/* The blocks of the exchange heap this process owns: for each handle
 * its address and its bytes, as the kernel said them (the answer's
 * words). Here and nowhere else: a program has the handle, and reads
 * and writes through these functions, which look at the table each
 * time; a block sent or freed is forgotten (Sip does it), and its
 * handle then answers -2. No call of the kernel, no copy. */
enum { BLOCKS = 64 };
static struct { uchar *base; word len; } blocks[BLOCKS];

static int held(value h) { return Long_val(h) >= 0 && Long_val(h) < BLOCKS && blocks[Long_val(h)].base != nil; }

/* handle h is a block: its address in the last answer's word wa, its bytes in the next */
value
sip_block_take(value h, value wa)
{
	if(Long_val(h) >= 0 && Long_val(h) < BLOCKS){
		blocks[Long_val(h)].base = (uchar*)words[Long_val(wa)];
		blocks[Long_val(h)].len = words[Long_val(wa) + 1];
	}
	return Val_unit;
}

value sip_block_drop(value h) { if(held(h)) blocks[Long_val(h)].base = nil; return Val_unit; }
value sip_block_size(value h) { return held(h) ? Val_long(blocks[Long_val(h)].len) : Val_long(-2); }

/* a byte read (0 to 255) and written; -1 outside the block */
value
sip_block_get(value h, value i)
{
	if(!held(h))
		return Val_long(-2);
	if(Long_val(i) < 0 || Long_val(i) >= blocks[Long_val(h)].len)
		return Val_long(-1);
	return Val_long(blocks[Long_val(h)].base[Long_val(i)]);
}

value
sip_block_set(value h, value i, value c)
{
	if(!held(h))
		return Val_long(-2);
	if(Long_val(i) < 0 || Long_val(i) >= blocks[Long_val(h)].len)
		return Val_long(-1);
	blocks[Long_val(h)].base[Long_val(i)] = Long_val(c);
	return Val_long(0);
}

/* n bytes between the block at off and bytes s at soff (which Sip
 * checked): out of the block, or into it */
value
sip_block_blit(value h, value off, value s, value soff, value n)
{
	uchar *p;

	if(!held(h))
		return Val_long(-2);
	if(Long_val(off) < 0 || Long_val(n) < 0 || Long_val(off) + Long_val(n) > blocks[Long_val(h)].len)
		return Val_long(-1);
	p = blocks[Long_val(h)].base + Long_val(off);
	if(Long_val(soff) >= 0)
		memmove(Bytes(s) + Long_val(soff), p, Long_val(n));
	else
		memmove(p, Bytes(s) + (-Long_val(soff) - 1), Long_val(n));
	return Val_long(0);
}

/* start_*.s's: the run-time system's main, which ends by exit */
void
sip_main(void)
{
	static char *argv[] = { "sip", nil };

	main(1, argv);
	for(;;)
		abi(ABI_EXIT, 0, 0, 0, 0);
}
