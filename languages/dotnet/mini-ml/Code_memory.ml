(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Code_memory.mli: mini-ml's build (the mkfile's), Linux's system
 * calls by their numbers, arm64's *)

(* the runtime's (unix.c), as lib_core's Unix declares it: a string's
 * argument its address, an int its value *)
external syscall : int -> Obj.t array -> int = "unix_syscall"

let available = Sys.os_type = "Unix" && Sys.word_size = 64

let call (nr : int) (args : Obj.t list) : int =
  let a = Array.make 6 (Obj.repr 0) in
  List.iteri (fun i x -> a.(i) <- x) args;
  syscall nr a

(* the kernel's answer, a negative errno when it fails *)
let check (what : string) (n : int) : int =
  if n < 0 && n > -4096 then failwith (Printf.sprintf "the JIT's memory: %s: error %d" what (-n));
  n

(* memfd_create 279, write 64, mmap 222 (PROT_READ|PROT_EXEC 5,
 * MAP_SHARED 1), close 57 *)
let load (code : string) : int =
  let fd = check "memfd_create" (call 279 [ Obj.repr "mini-dotnet-jit"; Obj.repr 0 ]) in
  let n = String.length code in
  if check "write" (call 64 [ Obj.repr fd; Obj.repr code; Obj.repr n ]) <> n then failwith "the JIT's memory: a short write";
  let addr = check "mmap" (call 222 [ Obj.repr 0; Obj.repr n; Obj.repr 5; Obj.repr 1; Obj.repr fd; Obj.repr 0 ]) in
  ignore (call 57 [ Obj.repr fd ]);
  addr

(* An address as a value, and back, through an int64's block (tag 255:
 * its field a word the collector does not look in): the field read
 * is the word itself, untagged. A word that is even and outside the
 * heap is a pointer the collector leaves alone, as the code's of a
 * static closure. *)
let closure (addr : int) : Obj.t =
  let word = Obj.field (Obj.repr (Int64.of_int addr)) 0 in
  let c = Obj.new_block 247 2 in
  Obj.set_field c 0 word;
  Obj.set_field c 1 word;
  c

let address (v : Obj.t) : int =
  let b = Obj.new_block 255 1 in
  Obj.set_field b 0 v;
  Int64.to_int (Obj.obj b : int64)
