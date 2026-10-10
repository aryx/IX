(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-tee: Plan 9's tee (principia's utilities/pipe/tee.c): the
 * standard input copied to the standard output and to each file, made
 * or emptied; -a: written at their ends; -i: an interrupt is ignored.
 * A file that cannot be opened is said and the others written.
 *
 *     mk | tee log | grep warning      the middle of a pipeline, kept
 *                                      in a file as it goes by
 *
 * terminology:
 * The name is the plumber's: a T, a fitting with one way in and two
 * out. Doug McIlroy's picture of programs joined like lengths of
 * hose is where the pipe comes from (mini-rc's Process tells it),
 * and the words followed: pipe, pipeline, tee, sink, and Plan 9's
 * plumber. -i is there because an interrupt typed at the terminal
 * goes to every process of the pipeline, and the one that keeps the
 * log should be the last to stop. *)

type caps = < Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let append = ref false in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c ->
            if k > 0 then match c with
              | 'a' -> append := true
              | 'i' -> ignore (Sys.signal Sys.sigint Sys.Signal_ignore)
              | 'u' -> ()
              | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    let outs = List.filter_map (fun file ->
      match (if !append then FS.open_append_fd caps file 0o666 else FS.open_out_fd caps file 0o666) with
      | fd -> Some fd
      | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "tee: cannot open %s: %s\n" file (Unix.error_message e)); None)
        (options (List.tl (Array.to_list argv))) in
    let outs = outs @ [ Console.stdout_fd caps ] and buf = Bytes.create 8192 in
    (* (what cannot be written, a pipe closed, is not said: tee.c's) *)
    let rec copy () =
      match Unix.read (Console.stdin_fd caps) buf 0 8192 with
      | n when n > 0 -> List.iter (fun fd -> try ignore (Unix.write fd buf 0 n) with Unix.Unix_error _ -> ()) outs; copy ()
      | _ -> ()
      | exception Unix.Unix_error _ -> () in
    copy ();
    Exit.OK
  with Usage -> Console.eprint caps "usage: tee [-ai] [file ...]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
