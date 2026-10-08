/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
/* arm64's types, for the compiler (mini-cc, 7c) */

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

// 8 bytes, as a pointer: the compiler's long is 4 on arm64
typedef unsigned long long uintptr;
typedef long long intptr;

// a double's bits, for port/frexp.c: 32 bits each, whatever a ulong is
union FPdbleword {
	double x;
	struct {	/* little endian */
		u32 lo;
		u32 hi;
	};
};
typedef union FPdbleword FPdbleword;

/* Plan 9's va_list. On arm64 every argument has 8 bytes of the
 * stack, whatever its type: a smaller one is at the start of its 8. */

typedef char* va_list;

#define va_start(list, start) \
	(list = (sizeof(start) < 8 ? (char*)((vlong*)&(start) + 1) : (char*)(&(start) + 1)))

#define va_end(list)

#define va_arg(list, mode) \
	((sizeof(mode) == 1) ? ((list += 8), (mode*)list)[-8] : \
	 (sizeof(mode) == 2) ? ((list += 8), (mode*)list)[-4] : \
	 (sizeof(mode) == 4) ? ((list += 8), (mode*)list)[-2] : \
	 ((list += sizeof(mode)), (mode*)list)[-1])
