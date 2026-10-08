(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The kernels' String under OCaml 4.14 (kernel.mk's COMPILER=ocaml):
 * the kernels are written for ocaml-light, whose strings are written
 * (String.create, s.[i] <- c, String.blit into one); OCaml 4.14's are
 * not, and the switch's refuses -unsafe-string. Here its String, with
 * what ocaml-light's has more: a string written through the bytes it
 * is. Linked first, it is the String the kernels' modules see. *)
include Stdlib.String

let create (n : int) : string = Bytes.unsafe_to_string (Bytes.create n)
let set (s : string) (i : int) (c : char) : unit = Bytes.set (Bytes.unsafe_of_string s) i c
let unsafe_set (s : string) (i : int) (c : char) : unit = Bytes.unsafe_set (Bytes.unsafe_of_string s) i c
let blit (src : string) (o : int) (dst : string) (p : int) (n : int) : unit =
  Bytes.blit_string src o (Bytes.unsafe_of_string dst) p n
let unsafe_blit (src : string) (o : int) (dst : string) (p : int) (n : int) : unit =
  Bytes.unsafe_blit_string src o (Bytes.unsafe_of_string dst) p n
let fill (s : string) (o : int) (n : int) (c : char) : unit = Bytes.fill (Bytes.unsafe_of_string s) o n c
