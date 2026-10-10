(* The machines as the front end sees them, whatever the back end: the
 * types' sizes and alignments, what is returned through a pointer or
 * passed in a register (the calling convention, which libc's assembly
 * and the kernel share), and which operators the machine computes
 * itself rather than by com64.c's calls. arm is 5c's (pointers are
 * longs, vlongs structures), arm64 7c's (pointers are vlongs).
 *
 *                       arm (-m 5)              arm64 (-m 7)
 *     char, short       1, 2                    1, 2
 *     int, long         4                       4
 *     vlong             8                       8
 *     float, double     4, 8                    4, 8
 *     a pointer         4                       8
 *     alignment, most   4                       8
 *     in a register     char to long, pointer   and vlong
 *     the result by a   struct, union, vlong    struct, union
 *     hidden pointer
 *     a vlong's + - *   calls of libc (Com64)   instructions
 *
 * terminology:
 * long is 4 bytes on both, and the 64-bit integer is vlong (very
 * long, Plan 9's name for long long, in u.h): a program that wants
 * an integer as wide as a pointer says uintptr. Unix on 64-bit
 * machines widened long instead (the convention called LP64, where
 * Windows kept it at 4, LLP64), and decades of C that kept a
 * pointer in a long or a file's offset in an int are why the choice
 * mattered. Plan 9's sources had said vlong for an offset since
 * their 32-bit days. *)

val arm : Tree.machine
val arm64 : Tree.machine
