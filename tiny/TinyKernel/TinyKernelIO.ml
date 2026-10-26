(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelIO.mli *)
open TinyMemory
open TinyKernelGraphics
open TinyKernelNetwork
open TinyKernelAudio
open TinyKernelFS
open TinyKernelMemory
open TinyKernelMachine
open TinyKernelFiles
open TinyKernelProcs
open TinyKernelDevices

(*****************************************************************************)
(* Reads and writes: Some n done, None must wait *)
(*****************************************************************************)

(* the console's input, typed and not yet read, and its end *)
let typed = ref ""
let typed_end = ref false

(* the process that has the console raw (rawcons), or 0: its ^C is a
 * byte typed, not the kill of every process *)
let raw = ref 0
let raw_on () =
  List.exists (fun q ->
    q.pid = !raw && (match q.state with Zombie _ -> false | _ -> true)) !procs

let read f a n =
  match f with
  | Link l ->
      (match l.heard with
       | [] -> None
       | m :: rest ->
           let k = min n (String.length m) in
           k_blit m 0 a k;
           l.heard <- rest;
           Some k)
  (* a message, whole (what is over n bytes is lost); the end *)
  | Call c ->
      (match il_hear c.il with
       | Some m -> let k = min n (String.length m) in k_blit m 0 a k; Some k
       | None -> if il_over c.il then Some 0 else None)
  | Console ->
      let t = !typed in
      let eot = not (raw_on ()) in
      if t = "" then (if !typed_end then Some 0 else None)
      (* ^D, but at a raw console: the read's end, nothing read, as
       * Plan 9's (old: a byte, and only the input's end ended a read) *)
      else if eot && t.[0] = '\004' then
        (typed := String.sub t 1 (String.length t - 1); Some 0)
      else begin
        (* up to a line's end, or a ^D *)
        let rec upto i =
          if i >= String.length t || i >= n then i
          else if t.[i] = '\n' then i + 1
          else if eot && t.[i] = '\004' then i
          else upto (i + 1) in
        let k = upto 0 in
        k_blit t 0 a k;
        typed := String.sub t k (String.length t - k);
        Some k
      end
  | Reader pi ->
      if pi.buf = "" then (if pi.writers = 0 then Some 0 else None)
      else begin
        let k = min n (String.length pi.buf) in
        k_blit pi.buf 0 a k;
        pi.buf <- String.sub pi.buf k (String.length pi.buf - k);
        Some k
      end
  | Writer _ | Draw _ | Post _ | Voice _ -> Some (-1)
  (* what the trace said, a line at a time; its end when the process ended *)
  | Trace t ->
      (match t.said with
       | m :: rest ->
           let k = min n (String.length m) in
           k_blit m 0 a k;
           t.said <- rest;
           Some k
       | [] -> (match traced_proc t with Some _ -> None | None -> Some 0))
  (* what was last written, once; its end when no writer is left *)
  | Peek b ->
      if b.fresh then
        (let k = min n (String.length b.last) in
         b.fresh <- false;
         k_blit b.last 0 a k;
         Some k)
      else if b.posters = 0 then Some 0
      else None
  | Open o -> (
      match o.node with
      | Rom (at, size) ->
          let k = max 0 (min n (size - o.off)) in
          row_copy a (at + o.off) k;
          o.off <- o.off + k;
          Some k
      (* a disk's file, from its blocks to the program's memory *)
      | Disk (r, i) when not (fs_is_dir r i) ->
          let k = fs_read_at r i o.off a n in
          o.off <- o.off + k;
          Some k
      | Data d ->
          let k = max 0 (min n (d.dsize - o.off)) in
          k_blit (Bytes.sub_string d.dbytes o.off k) 0 a k;
          o.off <- o.off + k;
          Some k
      | _ ->
          let s = contents o.node in
          let k = max 0 (min n (String.length s - o.off)) in
          k_blit s o.off a k;
          o.off <- o.off + k;
          Some k)

(* the network device's command (1 send, 2 take) on n bytes at the buffer *)
let net_command n cmd =
  poke net_dev net_buf; poke (net_dev + 4) n; poke (net_dev + 8) cmd

(* a packet to the wire: at the buffer, then the device's send *)
let net_send packet =
  let n = String.length packet in
  k_blit packet 0 net_buf n;
  net_command n 1

(* A traced process stopped, and the line that says why to its tracer
 * (a step ends there); stop's: where it is (its pc), then break (a
 * breakpoint's word), illegal and the word, fault and the address,
 * exec (its new program's first instruction), or step *)
let traced p = match p.traced with Some _ -> true | None -> false
let pause p line =
  p.state <- Stopped;
  match p.traced with
  | Some t -> t.step <- false; t.said <- t.said @ [ line ^ "\n" ]
  | None -> ()
let stop p why = pause p ("stopped " ^ string_of_int (reg p 16) ^ " " ^ why)

(* bytes in hexadecimal, two digits each *)
let hex_bytes l =
  let d = "0123456789abcdef" in
  String.concat "" (List.map (fun b ->
    String.make 1 d.[b lsr 4] ^ String.make 1 d.[b land 15]) l)

(* A tracer's command (plan_tiny_debugger.md), the numbers in decimal:
 * b addr, a breakpoint, the word there kept and 0 written in its place
 * (no instruction is 0: the process traps there, c_illegal); d addr,
 * the breakpoint removed, its word put back; r, the registers (r1 to
 * r15, then the pc); m addr n, n bytes in hexadecimal (1024 at most; a
 * breakpoint's are the word it hides); w addr v, a word written; y and
 * n, a stop at each call or not (trace); f, the children it forks
 * traced too, by the same tracer (trace -f); c, the stopped process
 * resumed; s, resumed for one instruction. From a breakpoint, c and s
 * run its word, then write the 0 again (run); from a call, they let
 * the call in. Bad if the command is none of these, or its address
 * not the process's. *)
let command t q words =
  let addr s =
    match int_of_string_opt s with
    | Some a when a land 3 = 0 -> ignore (user q a 4); a
    | _ -> raise Bad in
  let say m = t.said <- t.said @ [ m ^ "\n" ] in
  let unset a =
    (match List.assoc_opt a t.stops with
     | Some w -> mem_store q.mem a w
     | None -> ());
    t.stops <- List.filter (fun (b, _) -> b <> a) t.stops in
  match words, q.state with
  | [ "b"; s ], _ ->
      let a = addr s in
      if not (List.exists (fun (b, _) -> b = a) t.stops) then
        (t.stops <- t.stops @ [ a, mem_fetch q.mem a ]; mem_store q.mem a 0);
      say "ok"
  | [ "d"; s ], _ -> unset (addr s); say "ok"
  | [ "r" ], _ ->
      say (String.concat " " (List.init 16 (fun k ->
        (if k = 15 then "pc" else "r" ^ string_of_int (k + 1))
        ^ " " ^ string_of_int (reg q (k + 1)))))
  | [ "m"; s; k ], _ ->
      (match int_of_string_opt s, int_of_string_opt k with
       | Some a, Some n when n > 0 && n <= 1024 ->
           say (hex_bytes (List.init n (fun i ->
             match List.assoc_opt ((a + i) land lnot 3) t.stops with
             | Some w -> (w lsr (8 * ((a + i) land 3))) land 255
             | None -> peekb (user q (a + i) 1))))
       | _ -> raise Bad)
  | [ "w"; s; v ], _ ->
      let a = addr s in
      (match int_of_string_opt v with
       | Some v when List.exists (fun (b, _) -> b = a) t.stops ->
           t.stops <- List.map (fun (b, w) -> b, if b = a then v else w) t.stops
       | Some v -> mem_store q.mem a v
       | None -> raise Bad);
      say "ok"
  | [ "y" ], _ -> t.calls <- true; say "ok"
  | [ "n" ], _ -> t.calls <- false; say "ok"
  | [ "f" ], _ -> t.follow <- true; say "ok"
  | [ ("c" | "s") as c ], Stopped ->
      let pc = reg q 16 in
      (match List.assoc_opt pc t.stops with
       | Some w when t.call < 0 -> mem_store q.mem pc w; t.over <- pc
       | _ -> ());
      t.step <- c = "s";
      q.state <- Ready
  | _ -> raise Bad

let write f a n =
  match f with
  | Link l ->
      if n > 1024 then Some (-1)
      else begin
        l.asked <- l.asked + 1;
        net_send (ip_packet ip_icmp net_machine l.peer
          (icmp_message icmp_ask l.lid l.asked (k_string a n)));
        Some n
      end
  (* a message: now, or when the other end has acknowledged enough of
   * those before *)
  | Call c ->
      if n > il_max || il_over c.il then Some (-1)
      else if n = 0 then Some 0
      else if il_room c.il then
        (net_send (il_write c.il (k_string a n) !ticks); Some n)
      else None
  | Console -> k_console a n; Some n
  | Writer pi ->
      if pi.readers = 0 then Some (-1)
      else if String.length pi.buf = 512 then None
      else
        (let k = min n (512 - String.length pi.buf) in
         pi.buf <- pi.buf ^ k_string a k;
         Some k)
  | Open o -> (
      match o.node with
      | Data d when o.writes ->
          let at = min o.off d.dsize in
          if at + n > Bytes.length d.dbytes then begin
            let b = Bytes.make (max (at + n) (2 * Bytes.length d.dbytes)) ' ' in
            Bytes.blit d.dbytes 0 b 0 d.dsize;
            d.dbytes <- b
          end;
          Bytes.blit_string (k_string a n) 0 d.dbytes at n;
          d.dsize <- max d.dsize (at + n);
          d.dtime <- date ();
          o.off <- at + n;
          Some n
      | Disk (0, i) when o.writes ->
          (try fs_write_at i o.off a n; o.off <- o.off + n; Some n
           with Disk_full -> Some (-1))
      | _ -> Some (-1))
  (* messages, whole; a bad one is said on the console, the write -1 *)
  | Draw d ->
      (try messages d.conn (k_string a n); Some n
       with Graphics why -> puts ("draw: " ^ why ^ "\n"); Some (-1))
  | Post b -> b.last <- k_string a n; b.fresh <- true; Some n
  (* sounds, whole, when they fit in the ring (else a look again in 10
   * ms); a bad one, or more than a ring, -1 *)
  | Voice v ->
      (match (try Some (sounds (k_string a n)) with Bad_sound -> None) with
       | Some l
         when List.fold_left (fun acc snd -> acc + sound_length snd) 0 l <= ring
         ->
           if speak v l then Some n
           else
             (if !alarm = 0 || !ticks + 4 < !alarm then alarm := !ticks + 4;
              None)
       | _ -> Some (-1))
  (* a command to the traced process, each answered by a line but c,
   * which its next stop answers *)
  | Trace t ->
      (match traced_proc t with
       | Some q ->
           (try
              command t q (String.split_on_char ' ' (String.trim (k_string a n)));
              Some n
            with
            | Bad -> Some (-1)
            (* (a breakpoint in a shared text, and no room for its copy) *)
            | No_room -> Some (-1))
       | None -> Some (-1))
  | Reader _ | Peek _ -> Some (-1)

(* whether a read would not wait *)
let readable f =
  match f with
  | Console -> !typed <> "" || !typed_end
  | Reader pi -> pi.buf <> "" || pi.writers = 0
  | Peek b -> b.fresh || b.posters = 0
  | Link l -> (match l.heard with [] -> false | _ -> true)
  | Call c -> il_readable c.il
  | Trace t ->
      t.said <> []
      || (match traced_proc t with Some _ -> false | None -> true)
  | _ -> true
