(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What a test of a window's program looks at, beside the stub's
 * TinyLibSystem (TinyLibSystem.ml here): what the program wrote where it
 * draws, its drawing messages, for the test to give
 * TinyKernelGraphics.ml. Not in ../../TinyLibSystem.mli: only a test
 * names it, linking this stub *)

let drawn = Buffer.create 4096
