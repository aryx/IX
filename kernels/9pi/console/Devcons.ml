(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Devcons.mli *)

open Types
open Errors

(* consdir's qids, in its order *)
let files = [ "cons", 0o660; "consctl", 0o220; "bintime", 0o664; "cputime", 0o444; "null", 0o666;
              "pgrpid", 0o444; "pid", 0o444; "ppid", 0o444; "random", 0o444; "swap", 0o664;
              "time", 0o664; "user", 0o666; "zero", 0o444; "kmesg", 0o440; "kprint", 0o440;
              (* (not 9pi's: 9front's, the keys as they go down and up: below) *)
              "kbd", 0o440 ]

let qdir = 0
let numsize = 12
let vlnumsize = 22

let qid_of name =
  let rec go i l = match l with
    | [] -> raise Not_found
    | (n, _) :: r -> if n = name then i else go (i + 1) r in
  go 1 files

let lengths = [ "bintime", 24; "cputime", 6 * numsize; "pgrpid", numsize; "pid", numsize; "ppid", numsize;
                "time", numsize + (3 * vlnumsize) ]

let entries path =
  if path <> qdir then raise (Error enotdir)
  else List.map (fun (name, perm) ->
    { Dev.dname = name; Dev.dqid = { path = qid_of name; vers = 0; typ = Qt_file };
      Dev.dlength = (try List.assoc name lengths with Not_found -> 0); Dev.dperm = perm }) files

let name_of path = fst (List.nth files (path - 1))

(*****************************************************************************)
(* Output *)
(*****************************************************************************)

let kmesg = Buffer.create 1024

let print s =
  for i = 0 to String.length s - 1 do
    if s.[i] = '\n' then Machine.uart_putc 13;
    Machine.putc s.[i]
  done

(*****************************************************************************)
(* Input *)
(*****************************************************************************)

(* raw (consctl's rawon): no echo, no editing *)
let raw = ref false
(* how many times consctl is open *)
let ctls = ref 0

(* the line being typed; the lines typed, not read yet (an empty one:
 * ^D alone, the end of file) *)
let line = Buffer.create 128
let lines = ref []

let send () =
  lines := !lines @ [ Buffer.contents line ];
  Buffer.clear line;
  Proc.wakeup Console_input

(* a byte of input: echoed as it is (echo()), then kbd's editing *)
let input c =
  let ch = Char.chr c in
  if !raw then begin Buffer.add_char line ch; send () end
  else begin
    print (String.make 1 ch);
    if c = 8 then begin
      let n = Buffer.length line in
      if n > 0 then begin
        let s = Buffer.contents line in
        Buffer.clear line;
        Buffer.add_string line (String.sub s 0 (n - 1))
      end
    end
    else if c = 0x15 then Buffer.clear line
    else if c = 4 then send ()
    else begin Buffer.add_char line ch; if ch = '\n' then send () end
  end

(* a character from the serial line (kbdcr2nl: CR as LF) *)
let intr c = input (if c = 13 then 10 else c)

(* a character from the keyboard (kbdputc: a rune, its UTF-8 bytes) *)
let kbdputc r = let s = Dev.utf8 r in for i = 0 to String.length s - 1 do input (Char.code s.[i]) done

(* The keys held, #c/kbd: Kbd.mli says what it is and why the console
 * is not enough. Kbd makes the messages; they wait here for a reader,
 * the last 64 of them, and are dropped when the file is opened (what
 * was typed before a program started is not its own). *)
let kbd_messages = ref []

let kbd_message m =
  let l = !kbd_messages @ [ m ] in
  kbd_messages := (if List.length l > 64 then List.tl l else l);
  Proc.wakeup Kbd_input

let rec read_kbd n =
  match !kbd_messages with
  | [] -> Proc.sleep Kbd_input; read_kbd n
  | m :: rest -> kbd_messages := rest; String.sub m 0 (min n (String.length m))

let rec read_cons n =
  match !lines with
  | [] -> Proc.sleep Console_input; read_cons n
  | l :: rest ->
      let k = min n (String.length l) in
      lines := (if k = String.length l then rest else String.sub l k (String.length l - k) :: rest);
      String.sub l 0 k

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

(* readstr: [off, off+n) of a string *)
let readstr off n s = if off >= String.length s then "" else String.sub s off (min n (String.length s - off))

(* readnum: the number right-aligned in [size]-1 columns, a space *)
let pad size s = if String.length s >= size - 1 then s ^ " " else String.make (size - 1 - String.length s) ' ' ^ s ^ " "
let readnum off n v size = readstr off n (pad size (string_of_int v))

(* Seconds since 1970 are past a Pi1's int (31 bits: the top one is its
 * sign). In decimal: a negative one is its low 30 bits and 2^30, said
 * by its tens and its units. *)
let unsigned secs =
  if secs >= 0 then string_of_int secs
  else begin
    let low = secs land max_int in
    string_of_int ((low / 10) + 107374182 + (((low mod 10) + 4) / 10)) ^ string_of_int (((low mod 10) + 4) mod 10)
  end

(* a number as 8 bytes, the high one first *)
let be64 v = let r = Bytes.make 8 '\000' in for k = 4 to 7 do Bytes.set r k (Char.chr ((v lsr (8 * (7 - k))) land 0xff)) done; Bytes.unsafe_to_string r
(* seconds as nanoseconds, and [more] of them (less than a second's), as
 * 8 bytes: the seconds' 4 bytes multiplied by 1000 three times, a byte
 * at a time (no 64 bits in a Pi1's int) *)
let nanoseconds secs more =
  let d = Array.make 8 0 in
  for k = 0 to 3 do d.(k) <- (secs lsr (8 * k)) land 0xff done;
  let times m add = let c = ref add in for k = 0 to 7 do let v = (d.(k) * m) + !c in d.(k) <- v land 0xff; c := v lsr 8 done in
  times 1000 0; times 1000 0; times 1000 more;
  let r = Bytes.make 8 '\000' in for k = 0 to 7 do Bytes.set r k (Char.chr d.(7 - k)) done; Bytes.unsafe_to_string r

let read (c : chan) n off =
  let p = Proc.myproc () in
  match name_of c.qid.path with
  | "cons" -> read_cons n
  | "kbd" -> read_kbd n
  | "null" | "kprint" -> ""
  | "zero" -> String.make n '\000'
  | "pid" -> readnum off n p.pid numsize
  | "ppid" -> readnum off n p.parent numsize
  | "pgrpid" -> readnum off n 1 numsize
  | "user" -> readstr off n !Dev.eve
  | "kmesg" -> readstr off n (Buffer.contents kmesg)
  (* the clock (Dev.epoch): the seconds, the nanoseconds, the ticks and how many a second *)
  | "time" ->
      let secs = unsigned (!Dev.epoch + (!Proc.ticks / 100)) in
      readstr off n (pad numsize secs ^ pad vlnumsize (secs ^ "000000000")
                     ^ pad vlnumsize (string_of_int !Proc.ticks) ^ pad vlnumsize "100")
  | "cputime" ->
      let ms = (!Proc.ticks - p.start) * 10 in
      readstr off n (String.concat "" (List.map (fun v -> pad numsize (string_of_int v)) [ 0; 0; ms; 0; 0 ]))
  | "random" -> let r = Bytes.make n '\000' in for i = 0 to n - 1 do Bytes.set r i (Char.chr (Random.int 256)) done; Bytes.unsafe_to_string r
  (* old: 9pi's numbers of one boot, as a string; now this kernel's: the
   * memory, the pages below the processes', theirs taken and in all,
   * and no swap *)
  | "swap" ->
      let lo, hi = Arch.pages in
      let all = (hi - lo) / 4096 in
      readstr off n (Printf.sprintf "%d memory\n4096 pagesize\n%d kernel\n%d/%d user\n0/0 swap\n%d/%d kernel malloc\n0/0 kernel draw\n" hi (lo / 4096) (all - Mmu.nfree ()) all (Machine.heap_top ()) (Machine.heap_limit ()))
  (* the same three, 8 bytes each, the high one first *)
  | "bintime" ->
      let all = nanoseconds (!Dev.epoch + (!Proc.ticks / 100)) ((!Proc.ticks mod 100) * 10000000) ^ be64 !Proc.ticks ^ be64 100 in
      String.sub all 0 (min n 24)
  | _ -> raise (Error egreg)

(* the swap's pager started (its kernel process: a pid) *)
let kpager = ref false

let write (c : chan) s _ =
  (match name_of c.qid.path with
   | "cons" -> print s
   | "consctl" ->
       if s = "rawon" then raw := true
       else if s = "rawoff" then begin raw := false; if Buffer.length line > 0 then send () end
       else if s = "holdon" || s = "holdoff" then ()
       else raise (Error ebadctl)
   | "swap" -> if s = "start" && not !kpager then begin kpager := true; Proc.kproc "kpager" end
   (* the clock set: the seconds since 1970 now, in decimal *)
   | "time" ->
       let secs = try int_of_string (String.trim s) with Failure _ -> raise (Error ebadarg) in
       Dev.epoch := secs - (!Proc.ticks / 100)
   | "null" | "bintime" -> ()
   | _ -> raise (Error eperm));
  String.length s

let init () =
  let root = { path = qdir; vers = 0; typ = Qt_dir } in
  let d = Dev.default 'c' "cons" in
  Dev.register { d with
    Dev.attach = (fun _ -> Dev.attach 'c' 0 root);
    Dev.walk = Dev.tab_walk entries (fun _ -> root);
    Dev.stat = Dev.tab_stat "#c" entries (fun _ -> root);
    (* (kbd is walked to, not listed: a listing of #c is in the sessions
     * recorded from the C 9pi, the twin's, which has no such file) *)
    Dev.dirs = Dev.tab_dirs (fun path -> List.filter (fun (e : Dev.dirtab) -> e.Dev.dname <> "kbd") (entries path));
    Dev.open_ = (fun c m ->
      if c.qid.path <> qdir && name_of c.qid.path = "kbd" then kbd_messages := [];
      let c = Dev.tab_open c m in
      if c.qid.path <> qdir && name_of c.qid.path = "consctl" then incr ctls;
      c);
    (* consctl's last close: the console is not raw any more (Plan 9's
     * rule: a program that asked for rawon and ended, or was killed,
     * leaves a console that echoes; a game quit left the shell's
     * without) *)
    Dev.close = (fun c ->
      if c.qid.path <> qdir && name_of c.qid.path = "consctl" then begin
        decr ctls;
        if !ctls = 0 && !raw then begin raw := false; if Buffer.length line > 0 then send () end
      end);
    Dev.read = read;
    Dev.write = write;
  }
