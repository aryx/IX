(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-test: Plan 9's test (principia's shells/misc/test.c): a
 * question, answered by the status and nothing else ("false" when
 * not): for a script's if.
 *   -e f  -f f  -d f  -s f    f is there; a file; a directory; not empty
 *   -r f  -w f  -x f          may be read, written, run
 *   -A f  -L f  -T f          is append only, exclusive, temporary
 *   -t [fd]                   the descriptor (1) is the console
 *   s   -n s   -z s           the string is not empty; the same; is empty
 *   a = b   a != b            two strings
 *   m -eq n  -ne -gt -lt -ge -le     two numbers
 *   f -older t                f was written before t (seconds since
 *                             1970, or ago: 3h, 2d, 1y, 30s...)
 *   f -nt g   f -ot g         f is newer, older, than g
 *   ! e   e -a e   e -o e   ( e )
 * Run as [ its last argument is ]. Not test.c's way for -r, -w and -x:
 * it tries to open the file; here the file's permissions are read.
 *
 * -A, -L and -T are Plan 9's: three bits of a file's mode that Unix
 * does not have (written at its end only; open by one process at a
 * time; not kept by the backup).
 *
 * cs-history:
 * In the Sixth Edition if was a program, /bin/if: it worked out an
 * expression of this kind itself (-r file, s1 = s2) and ran the rest
 * of its arguments as a command when true. Bourne's shell (the
 * Seventh Edition, 1979) made if a part of the language, whose
 * condition is any command and its status; what was left of the old
 * if, the expression, became test. The name [ with a last ] is so
 * that if [ -f x ] reads as syntax, which it is not: each word is
 * an argument, and the spaces are needed.
 *
 * others:
 * The shells then built test in (it is run at every if of a
 * script), and ksh's [[ ]] is syntax at last. rc has ~, which
 * matches strings against patterns and is built in, so test is left
 * with the files and the numbers. *)

type caps = < Cap.readdir; Cap.stderr >

exception Bad of string

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let argv = if argv.(0) <> "[" then argv
      else if argv.(Array.length argv - 1) = "]" then Array.sub argv 0 (Array.length argv - 1)
      else raise (Bad "] missing") in
    let ac = Array.length argv and ap = ref 1 in
    if ac <= 1 then raise (Bad "");
    (* the next argument; None at the end, when the end may be there *)
    let next may_end =
      if !ap >= ac then begin if may_end then begin incr ap; None end else raise (Bad "argument expected") end
      else begin incr ap; Some argv.(!ap - 1) end in
    let arg () = match next false with Some a -> a | None -> "" in
    let stat f : Sys_plan9.dir option = match Sys_plan9.dirstat caps f with d -> Some d | exception Unix.Unix_error _ -> None in
    let mode f bit = match stat f with Some d -> d.mode_type land bit <> 0 | None -> false in
    let perm f bits = match stat f with Some d -> bits = 0 || d.perm land bits <> 0 | None -> false in
    (* strtol's: a number in decimal, 0x hexadecimal, 0 octal; "" is 0 *)
    let int s = if s = "" then Some 0 else if String.length s > 1 && s.[0] = '0' && s.[1] >= '0' && s.[1] <= '7' then int_of_string_opt ("0o" ^ String.sub s 1 (String.length s - 1)) else int_of_string_opt s in
    let next_int () = if !ap < ac then (match int argv.(!ap) with Some n -> incr ap; Some n | None -> None) else None in
    (* a time: a number of seconds since 1970, or numbers with a unit each, that long ago *)
    let older time f =
      match stat f with
      | None -> false
      | Some d ->
          let n = String.length time in
          let rec go k total relative =
            if k >= n then total, relative
            else begin
              let rec digits j = if j < n && time.[j] >= '0' && time.[j] <= '9' then digits (j + 1) else j in
              let j = digits k in
              let m = if j > k then float_of_string (String.sub time k (j - k)) else 0.0 in
              if j >= n then m, relative
              else begin
                let unit = match time.[j] with
                  | 'y' -> 12.0 *. 30.0 *. 24.0 *. 3600.0 | 'M' -> 30.0 *. 24.0 *. 3600.0 | 'd' -> 24.0 *. 3600.0
                  | 'h' -> 3600.0 | 'm' -> 60.0 | 's' -> 1.0
                  | _ -> raise (Bad ("bad time syntax, " ^ time)) in
                go (j + 1) (total +. (m *. unit)) true
              end
            end in
          let total, relative = go 0 0.0 false in
          d.mtime < (if relative then max 0.0 (Unix.time () -. total) else total) in
    let mtimes a b f = match stat a, stat b with Some x, Some y -> f x.mtime y.mtime | _ -> false in
    let rec e () =
      let p = e1 () in
      if next true = Some "-o" then p || e () else begin decr ap; p end
    and e1 () =
      let p = e2 () in
      if next true = Some "-a" then p && e1 () else begin decr ap; p end
    and e2 () = if next false = Some "!" then not (e2 ()) else begin decr ap; e3 () end
    and e3 () =
      let a = arg () in
      match a with
      | "(" -> let p = e () in if next false <> Some ")" then raise (Bad ") expected"); p
      | "-A" -> mode (arg ()) Sys_plan9.dmappend
      | "-L" -> mode (arg ()) Sys_plan9.dmexcl
      | "-T" -> mode (arg ()) Sys_plan9.dmtmp
      | "-f" -> (match stat (arg ()) with Some d -> d.mode_type land Sys_plan9.dmdir = 0 | None -> false)
      | "-d" -> mode (arg ()) Sys_plan9.dmdir
      | "-r" -> perm (arg ()) 0o444
      | "-w" -> perm (arg ()) 0o222
      | "-x" -> perm (arg ()) 0o111
      | "-e" -> perm (arg ()) 0
      | "-c" | "-b" | "-u" | "-g" -> false
      | "-s" -> (match stat (arg ()) with Some d -> d.length > 0 | None -> false)
      | "-t" ->
          if !ap >= ac then Unix.isatty Unix.stdout
          else (match next_int () with
                | Some fd -> fd >= 0 && fd <= 2 && Unix.isatty (if fd = 0 then Unix.stdin else if fd = 1 then Unix.stdout else Unix.stderr)
                | None -> raise (Bad "not a valid file descriptor number "))
      | "-n" -> arg () <> ""
      | "-z" -> arg () = ""
      | _ ->
          match next true with
          | None -> a <> ""
          | Some "=" -> arg () = a
          | Some "!=" -> arg () <> a
          | Some "-older" -> older (arg ()) a
          | Some "-ot" -> let b = arg () in mtimes b a (fun x y -> x > y)
          | Some "-nt" -> let b = arg () in mtimes b a (fun x y -> x < y)
          | Some op ->
              match int a with
              | None -> raise (Bad ("unexpected operator/operand: " ^ op))
              | Some m ->
                  match next_int (), op with
                  | Some n, "-eq" -> m = n | Some n, "-ne" -> m <> n | Some n, "-gt" -> m > n
                  | Some n, "-lt" -> m < n | Some n, "-ge" -> m >= n | Some n, "-le" -> m <= n
                  | _ -> raise (Bad ("unknown operator " ^ op)) in
    if e () then Exit.OK else Exit.Err "false"
  with Bad msg ->
    if msg = "" then Exit.Err "usage"
    else begin Console.eprint caps ("test: " ^ msg ^ "\n"); Exit.Err "bad syntax" end

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
