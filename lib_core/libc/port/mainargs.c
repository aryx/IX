/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* The arguments the process started with, as the start saved them
 * (arch/'s rt0.s), for port/getenv.c: on Linux the environment is on
 * the stack right after argv's nil. Defined for Plan 9 too, where
 * rt0.s is the same and nothing reads them. */

char **_mainargv;

/* argc, saved with it: the environment is argv + argc + 1. Not found
 * by looking for argv's nil, which a program that parses its flags
 * may have moved (rc's getflags shifts argv in place: its -c argument
 * was read as the environment). An intptr, not a long: rt0.s stores a
 * whole register, 8 bytes on arm64, where the compiler's long is 4
 * (and 4 bytes of alignment: "odd offset" said the assembler). */
intptr _mainargc;
