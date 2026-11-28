/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with mini-oberon's heap: two halves of 4M words,
 * a value stack of 1 MB. The heap is the runtime's bss, sized when it
 * is compiled: an object of this file, one object of one source
 * (plan_simpler_builds.md, step 4).
 * old: the mkfile compiled runtime.c with -DMAXHEAP and -DSTACK */
#define MAXHEAP 4194304
#define STACK 131072
#include "../../../languages/ml/runtime/runtime.c"
