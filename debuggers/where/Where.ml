(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-where: names the addresses of a trace, using the program's own
 * symbol table and pc/line table (written by mini-ld -g, read by
 * lib_executable). Each address gets a function, the offset in it, and
 * the file and the line.
 *
 *     mini-where tinybreakout 9c30 9cf0
 *     9c30 f12_brick_at<>+0x48 Breakout.ml:137
 *     9cf0 f12_move_ball<>+0x1c4 Breakout.ml:150
 *
 * An address is hexadecimal, with or without 0x before it. You can
 * paste what a trace line of mini-9pi has (lr=0x1698) or what an
 * exception has (raised at:); the words that are not addresses are
 * left out. In a mini-ml program, the line is the line of the
 * address's function (plan_debugger.md, stage 1b); in an assembler's
 * program, it is the line of the instruction.
 *
 * design:
 * The names come from the program that ran, not from a file beside it
 * that may come from another link (such as mini-ld -map's map, which
 * scripts/where.sh used to read): an executable says what it is
 * (plan_debugger.md's principles).
 *
 * References: Plan 9's src(1), which names a symbol's file and line
 * through acid. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

(* a word's address: hexadecimal, after an = or 0x *)
let address w =
  let w = match String.index_opt w '=' with Some i -> String.sub w (i + 1) (String.length w - i - 1) | None -> w in
  let w = if String.length w > 0 && w.[String.length w - 1] = ':' then String.sub w 0 (String.length w - 1) else w in
  let w = if String.length w > 2 && String.sub w 0 2 = "0x" then String.sub w 2 (String.length w - 2) else w in
  if w <> "" && String.for_all (fun c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) w then int_of_string_opt ("0x" ^ w)
  else None

(* an a.out's tables, or an ELF's two sections of them (mini-ld -g's, as
 * mini-acid reads them) *)
let tables (bytes : string) : Symbols.t option =
  match Elf_file.read bytes with
  | None -> Symbols.read bytes
  | Some e -> (
      match Elf_file.section e ".plan9.syms", Elf_file.section e ".plan9.lines", Elf_file.text_segment e with
      | Some s, Some l, Some (g : Elf_file.segment) ->
          Some (Symbols.of_tables (Elf_file.bytes bytes s) (Elf_file.bytes bytes l) g.vaddr (g.vaddr + g.filesz))
      | _ -> None)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | prog :: (_ :: _ as words) -> (
      match FS.read caps (Fpath.v prog) with
      | exception Sys_error m -> Console.eprint caps (Printf.sprintf "where: %s: %s\n" prog m); Exit.Err "open"
      | bytes ->
          match tables bytes with
          | None -> Console.eprint caps (Printf.sprintf "where: %s: no symbol table (link it with mini-ld -g)\n" prog); Exit.Err "no table"
          | Some t ->
              List.iter (fun w ->
                match address w with
                | None -> ()
                | Some a ->
                    let name = match Symbols.func t a with Some (n, 0) -> n | Some (n, o) -> Printf.sprintf "%s+0x%x" n o | None -> "?" in
                    let line = match Symbols.file_line t a with Some (f, l) -> Printf.sprintf " %s:%d" (Filename.basename f) l | None -> "" in
                    Console.print caps (Printf.sprintf "%x %s%s\n" a name line)) words;
              Exit.OK)
  | _ -> Console.eprint caps "usage: where program address...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
