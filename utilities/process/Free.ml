(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-free: the memory, who has it. Not one of Plan 9's programs (there
 * it is cat /dev/swap and ps); the name is Unix's. The board's memory
 * as the kernel divides it (its own, the processes', the swap: all,
 * taken, left), then a line a process: the memory it holds (the pages
 * it touched: /proc/n/segment's last column, mini-9pi's own), what it
 * asked for (its segments' sizes, as ps says), its name. A page shared
 * (a program's text, rfork's RFMEM) is counted for each that has it.
 * All of it read in /dev/swap and /proc: on another system there is
 * none. *)

type caps = < Cap.readdir; Cap.open_in; Cap.stdout; Cap.stderr >

exception Fatal of string * string

(* a small file's text; None when it cannot be read *)
let contents (caps : < caps; .. >) file =
  match FS.open_in_fd caps file with
  | exception Unix.Unix_error _ -> None
  | fd ->
      let buf = Bytes.create 8192 in
      let n = try Unix.read fd buf 0 8192 with Unix.Unix_error _ -> -1 in
      Unix.close fd;
      if n < 0 then None else Some (Bytes.sub_string buf 0 n)

let number s = match int_of_string_opt s with Some n -> n | None -> 0
let words s = List.filter (fun x -> x <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) s))
let lines s = List.filter (fun x -> x <> "") (String.split_on_char '\n' s)

(* /dev/swap's line named [name]: "n name" is (n, n), "a/b name" (a, b) *)
let said swap name =
  let rec find l =
    match l with
    | [] -> (0, 0)
    | line :: rest ->
        (match words line with
         | v :: what when String.concat " " what = name ->
             (match String.split_on_char '/' v with
              | [ a; b ] -> (number a, number b)
              | _ -> (number v, number v))
         | _ -> find rest) in
  find (lines swap)

let main (caps : < caps; .. >) (_argv : string array) : Exit.t =
  try
    let failed what e = raise (Fatal (what, Unix.error_message e)) in
    let swap = match contents caps "/dev/swap" with Some s -> s | None -> raise (Fatal ("/dev/swap", "cannot be read")) in
    let page = max 1 (fst (said swap "pagesize")) in
    let mb = 1024 * 1024 in
    let out = Buffer.create 4096 in
    (* megabytes, of pages or of bytes: 31 bits hold neither the board's
     * bytes times anything nor need to *)
    let pages n = n / (mb / page) in
    let row name all used = Buffer.add_string out (Printf.sprintf "%-8s %7dM %7dM %7dM\n" name all used (all - used)) in
    Buffer.add_string out (Printf.sprintf "%-8s %8s %8s %8s\n" "" "total" "used" "free");
    Buffer.add_string out (Printf.sprintf "%-8s %7dM\n" "memory" (fst (said swap "memory") / mb));
    let taken, limit = said swap "kernel malloc" in
    row "kernel" (limit / mb) (taken / mb);
    let used, all = said swap "user" in
    row "user" (pages all) (pages used);
    let used, all = said swap "swap" in
    row "swap" (pages all) (pages used);
    let entries = try Sys_plan9.dirread caps "/proc" with Unix.Unix_error (e, _, _) -> failed "/proc" e in
    let pids = List.sort (fun a b -> compare (number a) (number b)) (List.map (fun (d : Sys_plan9.dir) -> d.name) entries) in
    Buffer.add_string out (Printf.sprintf "\n%8s %8s %8s  %s\n" "pid" "held" "asked" "name");
    List.iter (fun pid ->
      match contents caps ("/proc/" ^ pid ^ "/status"), contents caps ("/proc/" ^ pid ^ "/segment") with
      | Some status, Some segment when status <> "" ->
          let w = Array.of_list (words (String.map (fun c -> if c = '\n' then ' ' else c) status)) in
          (* a segment's line: its kind, R if it is read only, its two
           * ends, how many have it, its pages in memory *)
          let held = List.fold_left (fun n line ->
              match List.rev (words line) with
              | p :: _ :: _ :: _ :: _ -> n + number p
              | _ -> n) 0 (lines segment) in
          if Array.length w >= 9 then
            Buffer.add_string out (Printf.sprintf "%8s %7dK %7dK  %s\n" pid (held * (page / 1024)) (number w.(8)) w.(0))
      | _ -> ()) pids;
    Console.print caps (Buffer.contents out);
    Exit.OK
  with Fatal (what, why) ->
    Console.eprint caps (Printf.sprintf "free: %s: error: %s\n" what why);
    Exit.Err what

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
