(* The machines as the front end sees them, whatever the back end is.
 * For each machine, this module says:
 * - the sizes and alignments of the types;
 * - what is returned through a pointer and what is passed in a register
 *   (the calling convention, which libc's assembly and the kernel
 *   share);
 * - which operators the machine computes itself rather than by
 *   com64.c's calls.
 * arm is the machine of 5c, where pointers are longs and vlongs are
 * structures; arm64 is the machine of 7c, where pointers are vlongs.
 *
 *                       arm (-m 5)              arm64 (-m 7)
 *     char, short       1, 2                    1, 2
 *     int, long         4                       4
 *     vlong             8                       8
 *     float, double     4, 8                    4, 8
 *     a pointer         4                       8
 *     alignment, most   4                       8
 *     in a register     char to long, pointer   the same, and vlong
 *     the result by a   struct, union, vlong    struct, union
 *     hidden pointer
 *     a vlong's + - *   calls to libc (Com64)   instructions
 *
 * terminology:
 * A long is 4 bytes on both machines, and the 64-bit integer is vlong
 * ("very long", Plan 9's name for long long, defined in u.h). A
 * program that wants an integer as wide as a pointer uses uintptr. On
 * 64-bit machines, Unix widened long instead (the convention called
 * LP64), while Windows kept it at 4 bytes (LLP64). The choice mattered
 * because of decades of C code that kept a pointer in a long or a
 * file's offset in an int. Plan 9's sources had used vlong for an
 * offset since their 32-bit days. *)

val arm : Tree.machine
val arm64 : Tree.machine
