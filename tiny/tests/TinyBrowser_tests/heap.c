// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// The memory tm.c gives to ML: the value stack, and the heap's two
// halves of 352 KB each (tiny-cpu has 1 MB in all).
typedef long value;
value vstack[8192];
value space0[88000];
value space1[88000];
