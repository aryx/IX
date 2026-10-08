/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
/* arm's types, for the compiler (mini-cc, 5c): after principia's
 * include/arch/arm/u.h */

//old: used to be s8int, u8int, etc. but shorter s8/u8/... like in Rust and Zig.
typedef signed char s8;
typedef unsigned char u8;
typedef signed short s16;
typedef unsigned short u16;
typedef signed int s32;
typedef unsigned int u32;
typedef signed long long s64;
typedef unsigned long long u64;

/* Plan 9's older names for them */
typedef u8 u8int;
typedef u16 u16int;
typedef u32 u32int;
typedef u64 u64int;

typedef float float32;
typedef double float64;

typedef unsigned long uintptr;
typedef long intptr;

// a double's bits, for port/frexp.c (little endian)
union FPdbleword {
	double x;
	struct {	/* little endian */
		unsigned long lo;
		unsigned long hi;
	};
};
typedef union FPdbleword FPdbleword;

/* Plan 9's va_list, principia's: an argument has its own size on the
 * stack, 4 bytes at least, a smaller one at the start of its 4. */

typedef char* va_list;

#define va_start(list, start) \
	(list = (sizeof(start) < 4 ? (char*)((int*)&(start) + 1) : (char*)(&(start) + 1)))

#define va_end(list)

#define va_arg(list, mode) \
	((sizeof(mode) < 4) ? \
		((list += 4), *(mode*)(list - 4)) : \
		((list += sizeof(mode)), *(mode*)(list - sizeof(mode))))
