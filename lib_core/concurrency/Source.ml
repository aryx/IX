(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See ../commons/Source.mli: mini-ml's threads.
 *
 * A source is a process (fork: its memory is its own), that waits in
 * the system in the program's place and writes what comes to the one
 * pipe: a frame, the source's number (a byte), a length (two), the
 * bytes, in one write (whole, among the other sources': under 4 KB).
 * The program reads the pipe when no thread can run (Thread.idle), and
 * gives each frame to its source's pump, the thread that sends it on
 * the channel (a send waits for its receiver: the scheduler cannot).
 * So a program whose threads never all wait reads no source: they
 * wait on channels, in a program of events.
 * Plan 9's way: it has no select, a process waits for you. *)

type source = { pump : Thread.t; frames : bytes Queue.t }

let sources : (int, source) Hashtbl.t = Hashtbl.create 8
let helpers : int list ref = ref []
let pipe : (Unix.file_descr * Unix.file_descr) option ref = ref None
(* what was read of the pipe and is not a whole frame yet *)
let pending = Buffer.create 4096

(* a read of the pipe (it waits), its whole frames given out *)
let wait () =
  let r = match !pipe with Some (r, _) -> r | None -> assert false in
  let b = Bytes.create 8192 in
  let n = try Unix.read r b 0 8192 with Unix.Unix_error (Unix.EINTR, _, _) -> 0 in
  Buffer.add_subbytes pending b 0 n;
  let all = Buffer.to_bytes pending in
  let rec frames o =
    if o + 3 <= Bytes.length all && o + 3 + Bytes.get_uint16_le all (o + 1) <= Bytes.length all then begin
      let len = Bytes.get_uint16_le all (o + 1) in
      (match Hashtbl.find_opt sources (Char.code (Bytes.get all o)) with
       | Some s -> Queue.add (Bytes.sub all (o + 3) len) s.frames; Thread.wakeup s.pump
       | None -> ());
      frames (o + 3 + len)
    end
    else o in
  let rest = frames 0 in
  Buffer.clear pending;
  Buffer.add_subbytes pending all rest (Bytes.length all - rest)

(* the first source: the pipe, the scheduler's wait (the one before it,
 * a deadlock's, when there is no source left to wait for), and the
 * processes ended with the program *)
let start () =
  match !pipe with
  | Some p -> p
  | None ->
      let p = Unix.pipe ~cloexec:false () in
      pipe := Some p;
      Thread.idle := wait;
      at_exit (fun () -> List.iter (fun pid -> try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ()) !helpers);
      p

(* a source's process (what [produce] gives, framed, until it gives
 * nothing: the last frame, empty) and its pump; [message] makes a
 * frame's bytes the channel's value *)
let source (_ : < Cap.fork; .. >) keep produce message =
  let r, w = start () in
  let id = Hashtbl.length sources in
  if id > 255 then failwith "Source: too many sources";
  let ch = Event.new_channel () and frames = Queue.create () in
  (match Unix.fork () with
   | 0 ->
       (* only its own descriptors: a pipe's other end kept here would
        * never say its end *)
       for fd = 0 to 63 do
         let fd : Unix.file_descr = Obj.magic fd in
         if fd <> w && fd <> Unix.stderr && not (List.mem fd keep) then (try Unix.close fd with Unix.Unix_error _ -> ())
       done;
       ignore r;
       let rec loop () =
         let data = try produce () with Unix.Unix_error _ -> Bytes.empty in
         let frame = Bytes.create (3 + Bytes.length data) in
         Bytes.set frame 0 (Char.chr id);
         Bytes.set_uint16_le frame 1 (Bytes.length data);
         Bytes.blit data 0 frame 3 (Bytes.length data);
         (match Unix.write w frame 0 (Bytes.length frame) with _ -> () | exception Unix.Unix_error _ -> Unix._exit 0);
         if Bytes.length data > 0 then loop () in
       loop ();
       Unix._exit 0
   | pid -> helpers := pid :: !helpers);
  let rec pump () =
    match Queue.take_opt frames with
    | Some data -> Event.sync (Event.send ch (message data)); pump ()
    | None -> Thread.sleep (); pump () in
  Hashtbl.replace sources id { pump = Thread.create pump (); frames };
  ch

let reader caps fd n =
  let buf = Bytes.create (min n 4000) in
  source caps [ fd ] (fun () -> Bytes.sub buf 0 (Unix.read fd buf 0 (Bytes.length buf))) (fun data -> data)

let timer caps d =
  source caps [] (fun () -> Unix.sleepf d; Bytes.make 1 '.') (fun _ -> ())

(* (its process reads what it is asked from a pipe of its own: a time,
 * 16 characters; sleeps that long; says so) *)
let alarm caps =
  let asked, ask = Unix.pipe ~cloexec:false () in
  let b = Bytes.create 16 in
  let ch =
    source caps [ asked ]
      (fun () ->
        if Unix.read asked b 0 16 < 16 then Bytes.empty
        else begin Unix.sleepf (float_of_string (String.trim (Bytes.to_string b))); Bytes.make 1 '.' end)
      (fun _ -> ()) in
  ((fun (d : float) -> ignore (Unix.write_substring ask (Printf.sprintf "%16.6f" d) 0 16)), ch)
