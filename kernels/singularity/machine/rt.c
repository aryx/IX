/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with mini-singularity's kernel's heap: two halves
 * of 1M words, a value stack of 1 MB (a process's: lib/'s prt.c). The
 * heap is the runtime's bss, sized when it is compiled: an object of
 * this file, one object of one source (plan_simpler_builds.md, step 4).
 * old: the mkfile compiled runtime.c with -DMAXHEAP and -DSTACK */
#define MAXHEAP 1048576
#define STACK 131072
#include "../../../languages/ml/runtime/runtime.c"
