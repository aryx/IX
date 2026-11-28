/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with mini-squeak's heap: two halves of 8M words
 * (64 MB each), a value stack of 8 MB. The heap is the runtime's bss,
 * sized when it is compiled: an object of this file, one object of one
 * source (plan_simpler_builds.md, step 4).
 * old: the mkfile compiled runtime.c with -DMAXHEAP and -DSTACK */
#define MAXHEAP 8388608
#define STACK 1048576
#include "../../../languages/ml/runtime/runtime.c"
