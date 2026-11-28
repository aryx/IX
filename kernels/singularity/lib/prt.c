/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with a process's heap: two halves of 256k words, a
 * value stack of 64k words (the kernel's: machine/rt.c). The heap is
 * the runtime's bss, sized when it is compiled: an object of this file,
 * one object of one source (plan_simpler_builds.md, step 4).
 * old: the mkfile compiled runtime.c with -DMAXHEAP and -DSTACK (PHEAP) */
#define MAXHEAP 262144
#define STACK 65536
#include "../../../languages/ml/runtime/runtime.c"
