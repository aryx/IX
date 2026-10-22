/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* Plan 9's u.h for 9front's Doom on Linux (build.sh): its types, over
 * C99's and POSIX's headers */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>
typedef unsigned char uchar; typedef unsigned short ushort; typedef unsigned int uint; typedef unsigned long ulong;
typedef int64_t vlong; typedef uint64_t uvlong; typedef uint8_t u8int; typedef uint16_t u16int; typedef uint32_t u32int; typedef uint64_t u64int; typedef uintptr_t uintptr;
#define nil NULL
#define USED(...) ((void)0)
#define SET(...) ((void)0)
