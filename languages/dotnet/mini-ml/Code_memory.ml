(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Code_memory.mli: mini-ml's build (the mkfile's), Linux's system
 * calls by their numbers, arm64's; Plan 9's on arm *)

(* the runtime's (unix.c), as lib_core's Unix declares it: a string's
 * argument its address, an int its value *)
external syscall : int -> Obj.t array -> int = "unix_syscall"

let plan9 = Sys.os_type = "Plan9"
let available = (Sys.os_type = "Unix" && Sys.word_size = 64) || plan9

let call (nr : int) (args : Obj.t list) : int =
  let a = Array.make 6 (Obj.repr 0) in
  List.iteri (fun i x -> a.(i) <- x) args;
  syscall nr a

(* the kernel's answer, a negative errno when it fails *)
let check (what : string) (n : int) : int =
  if n < 0 && n > -4096 then failwith (Printf.sprintf "the JIT's memory: %s: error %d" what (-n));
  n

(* Plan 9's (sys.h): pread 10, pwrite 11, pipe 27, segattach 28,
 * segflush 31. The memory a segment attached (zeros, class "memory"),
 * its bytes written through a pipe: ML writes no memory but its own
 * values' (and the collector moves those), the kernel writes where a
 * read is asked to put them; then segflush, the bytes in memory and
 * the instructions' cache emptied of what was there. Plan 9 runs its
 * processes' memory, arm having no right to run apart. *)
let segment (n : int) : int = check "segattach" (call 28 [ Obj.repr 0; Obj.repr "memory"; Obj.repr 0; Obj.repr n ])

let fds : (int * int) option ref = ref None

let poke (addr : int) (data : string) : unit =
  let r, w = match !fds with
    | Some p -> p
    | None ->
        let b = Bytes.create 8 in
        ignore (check "pipe" (call 27 [ Obj.repr b ]));
        let p = (Int32.to_int (Bytes.get_int32_le b 0), Int32.to_int (Bytes.get_int32_le b 4)) in
        fds := Some p;
        p in
  let n = String.length data in
  let rec chunks off =
    if off < n then begin
      (* (4 KB a time: the pipe holds 32, and no one else reads it) *)
      let k = min 4096 (n - off) in
      if check "pwrite" (call 11 [ Obj.repr w; Obj.repr (String.sub data off k); Obj.repr k; Obj.repr (-1); Obj.repr (-1) ]) <> k
      then failwith "the JIT's memory: a short write";
      let rec read got =
        if got < k then begin
          let m = check "pread" (call 10 [ Obj.repr r; Obj.repr (addr + off + got); Obj.repr (k - got); Obj.repr (-1); Obj.repr (-1) ]) in
          if m = 0 then failwith "the JIT's memory: the pipe's end";
          read (got + m)
        end in
      read 0;
      chunks (off + k)
    end in
  chunks 0

let load_plan9 (code : string) : int =
  let n = String.length code in
  let addr = segment n in
  poke addr code;
  ignore (check "segflush" (call 31 [ Obj.repr addr; Obj.repr n ]));
  addr

(* memfd_create 279, write 64, mmap 222 (PROT_READ|PROT_EXEC 5,
 * MAP_SHARED 1), close 57 *)
let load (code : string) : int =
  if plan9 then load_plan9 code else
  let fd = check "memfd_create" (call 279 [ Obj.repr "mini-dotnet-jit"; Obj.repr 0 ]) in
  let n = String.length code in
  if check "write" (call 64 [ Obj.repr fd; Obj.repr code; Obj.repr n ]) <> n then failwith "the JIT's memory: a short write";
  let addr = check "mmap" (call 222 [ Obj.repr 0; Obj.repr n; Obj.repr 5; Obj.repr 1; Obj.repr fd; Obj.repr 0 ]) in
  ignore (call 57 [ Obj.repr fd ]);
  addr

(* the words as bytes, little-endian *)
let words (a : int array) : string =
  let w = Sys.word_size / 8 in
  let b = Bytes.create (w * Array.length a) in
  Array.iteri (fun i x ->
      if w = 8 then Bytes.set_int64_le b (8 * i) (Int64.of_int x)
      else Bytes.set_int32_le b (4 * i) (Int32.of_int x)) a;
  Bytes.to_string b

(* mapped readable (PROT_READ 1), the file kept open; a word written by
 * pwrite64 (68), which the mapping, MAP_SHARED, sees *)
let cells (init : int array) : int * (int -> int -> unit) =
  if plan9 then begin
    (* (a segment's words, written through the pipe) *)
    let addr = segment (4 * Array.length init) in
    poke addr (words init);
    (addr, fun i x -> poke (addr + (4 * i)) (words [| x |]))
  end else
  let fd = check "memfd_create" (call 279 [ Obj.repr "mini-dotnet-cells"; Obj.repr 0 ]) in
  let data = words init in
  let n = String.length data in
  if check "write" (call 64 [ Obj.repr fd; Obj.repr data; Obj.repr n ]) <> n then failwith "the JIT's cells: a short write";
  let addr = check "mmap" (call 222 [ Obj.repr 0; Obj.repr n; Obj.repr 1; Obj.repr 1; Obj.repr fd; Obj.repr 0 ]) in
  (addr, fun i x ->
      if check "pwrite64" (call 68 [ Obj.repr fd; Obj.repr (words [| x |]); Obj.repr 8; Obj.repr (8 * i) ]) <> 8
      then failwith "the JIT's cells: a short write")

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
  (* (an int64's 8 bytes: two words on 32 bits, the second's bits past
   * the int's) *)
  let b = Obj.new_block 255 (8 / (Sys.word_size / 8)) in
  Obj.set_field b 0 v;
  Int64.to_int (Obj.obj b : int64)
