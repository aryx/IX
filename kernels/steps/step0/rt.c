/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with a kernel step's heap (steps 1 to 3): two
 * halves of 4M words (32 MB each on the Pi 4), a value stack of 1 MB.
 * The heap is the runtime's bss, sized when it is compiled, so a kernel
 * has a runtime object of its own, made from this file, one object of
 * one source (plan_simpler_builds.md, step 4).
 * old: the mkfiles compiled runtime.c with -DMAXHEAP and -DSTACK, an
 * object of the same source in each, other flags */
#define MAXHEAP 4194304
#define STACK 131072
#include "../../../languages/ml/runtime/runtime.c"
