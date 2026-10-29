(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Proc9.mli *)

let signal = 10

let stopped = ref false

let dir = "/tmp/mini-5i-debug"
let pipe pid ext = Printf.sprintf "%s/%d.%s" dir pid ext

let ok = function Ok v -> Some v | Error _ -> None

let read_all (h : Host_calls.t) fd =
  let b = Buffer.create 256 in
  let rec go () = match h.read fd 65536 with Ok "" | Error _ -> () | Ok s -> Buffer.add_string b s; go () in
  go ();
  Buffer.contents b

let write_all (h : Host_calls.t) fd s =
  let rec go off =
    if off < String.length s then
      match h.write fd (String.sub s off (String.length s - off)) with
      | Ok n when n > 0 -> go (off + n)
      | _ -> () in
  go 0

(* a pipe opened, again when a signal broke the wait (EINTR: an alarm
 * while stopped); Linux's open flags: O_RDONLY 0, O_WRONLY 1 *)
let rec opened (h : Host_calls.t) path flags =
  match h.openat None path flags 0 with
  | Error 4 -> opened h path flags
  | r -> ok r

let receive (h : Host_calls.t) path =
  match opened h path 0 with
  | Some fd -> let s = read_all h fd in ignore (h.close fd); Some s
  | None -> None

let send (h : Host_calls.t) path s =
  match opened h path 1 with
  | Some fd -> write_all h fd s; ignore (h.close fd); true
  | None -> false

let serve h ~pid answer =
  let once () =
    match receive h (pipe pid "req") with
    | None -> stopped := false              (* no debugger made the pipes *)
    | Some r ->
        let a, after = try let d, after = answer r in "ok\n" ^ d, after with Failure m -> "error " ^ m ^ "\n", ignore in
        ignore (send h (pipe pid "rep") a);
        after () in
  once ();
  while !stopped do once () done

let forget (h : Host_calls.t) pid = List.iter (fun ext -> ignore (h.unlink (pipe pid ext))) [ "req"; "rep" ]

(* a process of mini-5i: the host's same executable *)
let ours (h : Host_calls.t) pid =
  match h.stat (Printf.sprintf "/proc/%d/exe" pid), h.stat "/proc/self/exe" with
  | Ok a, Ok b -> a.dev = b.dev && a.ino = b.ino
  | _ -> false

let ask (h : Host_calls.t) pid ~stopped request =
  if not (ours h pid) then Error "process exited"
  else begin
    ignore (h.mkdir dir 0o700);
    List.iter (fun ext -> if h.stat (pipe pid ext) |> Result.is_error then ignore (h.mkfifo (pipe pid ext) 0o600)) [ "req"; "rep" ];
    if not stopped then ignore (h.kill pid signal);
    if not (send h (pipe pid "req") request) then Error "process exited"
    else
      match receive h (pipe pid "rep") with
      | None -> Error "process exited"
      | Some a ->
          (match String.index_opt a '\n' with
           | Some i when String.sub a 0 i = "ok" -> Ok (String.sub a (i + 1) (String.length a - i - 1))
           | Some i when String.length a > 6 && String.sub a 0 6 = "error " -> Error (String.sub a 6 (i - 6))
           | _ -> Error "process exited")
  end
