(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The Pi 1's board without mini-qemu's host (no terminal, no window, no
 * Unix but its clock): a kernel loaded at 0x8000, a card kept in
 * memory, and a session on the console, each line typed when the
 * prompt is back. Then the instructions run, the seconds and the speed
 * to each prompt. The same program natively and by js_of_ocaml under
 * node: boot_bench.sh, plan_web.md's stage 1.
 *
 * Usage: Boot_bench kernel.img [card.img] [-usb] [-- line...] *)

let read f = In_channel.with_open_bin f In_channel.input_all

(* the card in memory: what is written is kept there *)
let card image : Sdhost.storage =
  let b = Bytes.unsafe_of_string image in
  { read = (fun off len -> Bytes.sub_string b off len); write = (fun off data -> Bytes.blit_string data 0 b off (String.length data));
    size = Bytes.length b }

let () =
  let rec split acc = function
    | "--" :: lines -> List.rev acc, lines
    | a :: rest -> split (a :: acc) rest
    | [] -> List.rev acc, [] in
  let args, lines = split [] (List.tl (Array.to_list Sys.argv)) in
  let usb = List.mem "-usb" args in
  let files = List.filter (fun a -> a <> "-usb") args in
  let out = Buffer.create 4096 in
  let sd = match files with [ _; c ] -> Some (card (read c)) | _ -> None in
  let board = Board.create { ram_size = 512 * 1024 * 1024; ips = 30; log = ignore; usb_devices = (if usb then [ "usb-kbd"; "usb-mouse" ] else []); sd;
                             serial0 = Buffer.add_char out; serial1 = ignore; console = 0 } in
  Board.load_raw board ~addr:0x8000 (read (List.hd files));
  let start = Unix.gettimeofday () and ran = ref 0 in
  let prompts () =
    let s = Buffer.contents out and n = ref 0 in
    String.iteri (fun i c -> if c = '%' && i + 1 < String.length s && s.[i + 1] = ' ' then incr n) s; !n in
  let until n what =
    let t0 = Unix.gettimeofday () and r0 = !ran in
    while prompts () < n do
      for _ = 1 to 64 do
        Board.run board ~batch:4096;
        List.iter (fun (c : Status.cpu) -> ran := !ran + c.ran) (Board.where board)
      done;
      if Unix.gettimeofday () -. start > 600. then (prerr_endline ("Boot_bench: no prompt after 600 s: " ^ what); exit 1)
    done;
    let s = Unix.gettimeofday () -. t0 in
    Printf.eprintf "%-28s %6.1f s, %5d million instructions, %5.1f a second; the board's time %.1f s\n%!"
      what s ((!ran - r0) / 1_000_000) (float_of_int (!ran - r0) /. s /. 1e6) (float_of_int (Board.now board) /. 1e6) in
  until 1 "to the shell's prompt";
  List.iteri (fun i line ->
    String.iter (Board.input board) (line ^ "\n");
    until (i + 2) line) lines;
  print_string (Buffer.contents out)
