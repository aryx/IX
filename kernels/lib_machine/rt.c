/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime with the heap of mkkernel's kernels (mini-xv6,
 * mini-9pi): two halves of 4M words (32 MB each on the Pi 4) and a
 * value stack of 1 MB, for the boot's use. With the image they stay far
 * below the 256 MB where the processes' pages start (board.h's
 * HEAP_LIMIT). Not runtime.c beside it, the kernel's own C runtime.
 * TRACING: a panic says the raise's addresses (plan_debugger.md, stage
 * 6). The heap is the runtime's bss, sized when it is compiled: an
 * object of this file, one object of one source (plan_simpler_builds.md,
 * step 4).
 * old: mkkernel compiled runtime.c with -DMAXHEAP, -DSTACK and
 * -DTRACING */
#define MAXHEAP 4194304
#define STACK 131072
#define TRACING
#include "../../languages/ml/runtime/runtime.c"
