(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The Pi 1's board without mini-qemu's host (no terminal, no window, no
 * Unix but its clock): a kernel loaded at 0x8000, a card kept in
 * memory, and a session on the console, each line typed when the
 * prompt is back. Then the instructions run, the seconds and the speed
 * to each prompt. The same program natively and by js_of_ocaml under
 * node: boot_bench.sh, plan_web.md's stage 1.
 *
 * Usage: Boot_bench kernel.img [card.img] [-usb] [-slow] [-ips N] [-idle S] [-move] [-- line...]
 *   -ips N   the board's instructions to a microsecond (30; the page's
 *            is 6)
 *   -idle S  after the lines, S seconds of the board's time with
 *            nothing typed: what a system that waits costs (a line
 *            "rio &" before it: a screen of windows that waits)
 *   -keys S  typed before them on the page's keyboard (Board.host_key:
 *            small letters, spaces, _ for Enter): a program started on
 *            the screen's console, as rio_ does
 *   -do S    after the lines and -keys, as a page's person (the cursor
 *            the host's), steps apart by ';':
 *              p X Y B   the mouse at (X, Y), its buttons B (1 left, 2
 *                        middle, 4 right)
 *              k KEYS    typed (as -keys)
 *              s N       until the board is quiet (three tenths of a
 *                        second of under 150,000 instructions each),
 *                        N seconds of the board's at most: what the
 *                        steps since the last s cost is printed
 *              shot F    the screen written in F (a PPM)
 *              prof      -prof's counting starts here
 *   -nodraw  memdraw's general loop left to the kernel (Hostdraw not
 *            set: the screens must be the same with and without)
 *   -prof F  where the guest is during them, a line an address with its
 *            count, every 1024th instruction (mini-qemu's -prof), after the
 *            first ten seconds when there are more
 *   -move    the mouse moved during them, 60 times a second: the USB
 *            mouse with -usb, else the page's way (Board.host_pointer,
 *            the cursor the host's: a kernel built for a page)
 *   -slow  the switches of what is only faster off (Arm32_fast.on,
 *          Board.forget_used, Board.keep_decoded): the instructions and
 *          the console must be the same with and without *)

(* (Boot_jit is this file with Jit.attach here: tests/dune) *)
let attach : Board.t -> unit = ignore

let attached () = ""

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
  if List.mem "-slow" args then (Arm32_fast.on := false; Board.forget_used := false; Board.keep_decoded := false);
  let move = List.mem "-move" args in
  let rec opt name default = function a :: v :: _ when a = name -> int_of_string v | _ :: rest -> opt name default rest | [] -> default in
  let ips = opt "-ips" 30 args and idle = opt "-idle" 0 args in
  let rec plain = function ("-ips" | "-idle" | "-prof" | "-keys" | "-do") :: _ :: rest -> plain rest | a :: rest -> a :: plain rest | [] -> [] in
  let files = List.filter (fun a -> a <> "-usb" && a <> "-slow" && a <> "-move" && a <> "-nodraw") (plain args) in
  (* as a page: the cursor the host's (said before the boot: the kernel
   * gives its cursor when it loads one) *)
  if not usb then Board.host_cursor := true;
  if not usb && not (List.mem "-nodraw" args) then Hostdraw.install ();
  let out = Buffer.create 4096 in
  let limit = match Sys.getenv_opt "BOOT_LIMIT" with Some n -> float_of_string n | None -> 600. in
  let sd = match files with [ _; c ] -> Some (card (read c)) | _ -> None in
  let board = Board.create { ram_size = 512 * 1024 * 1024; ips; log = ignore; usb_devices = (if usb then [ "usb-kbd"; "usb-mouse" ] else []); sd;
                             serial0 = Buffer.add_char out; serial1 = ignore; console = 0 } in
  Board.load_raw board ~addr:0x8000 (read (List.hd files));
  attach board;
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
      (* (the console so far, to see why) *)
      if Unix.gettimeofday () -. start > limit then begin
        prerr_endline (Printf.sprintf "Boot_bench: no prompt after %.0f s: %s" limit what);
        print_string (Buffer.contents out); exit 1
      end
    done;
    let s = Unix.gettimeofday () -. t0 in
    Printf.eprintf "%-28s %6.1f s, %5d million instructions, %5.1f a second; the board's time %.1f s\n%!"
      what s ((!ran - r0) / 1_000_000) (float_of_int (!ran - r0) /. s /. 1e6) (float_of_int (Board.now board) /. 1e6) in
  until 1 "to the shell's prompt";
  List.iteri (fun i line ->
    String.iter (Board.input board) (line ^ "\n");
    until (i + 2) line) lines;
  (* (ten seconds a line: the first ones may be a program starting) *)
  let at = ref 0 in
  let rec prof = function "-prof" :: f :: _ -> Some f | _ :: rest -> prof rest | [] -> None in

  let rec keys = function "-keys" :: k :: _ -> k | _ :: rest -> keys rest | [] -> "" in
  (* the board run for so many of its microseconds *)
  let during us =
    let b0 = Board.now board in
    while Board.now board - b0 < us do
      Board.run board ~batch:4096;
      List.iter (fun (c : Status.cpu) -> ran := !ran + c.ran) (Board.where board)
    done in
  let typed =
    String.iter (fun c ->
      let u = match c with '_' -> 40 | ' ' -> 44 | '0' -> 39 | '1' .. '9' -> 30 + Char.code c - Char.code '1' | c -> 4 + Char.code c - Char.code 'a' in
      List.iter (fun down -> Board.host_key u down; during 50_000) [ true; false ]) in
  typed (keys args);
  let shot f =
    match Board.frame board with
    | Some (g, pixels) when g.depth = 16 ->
        Out_channel.with_open_bin f (fun oc ->
          Printf.fprintf oc "P6\n%d %d\n255\n" g.width g.height;
          for y = 0 to g.height - 1 do
            for x = 0 to g.width - 1 do
              let o = (y * g.pitch) + (2 * x) in
              let v = Char.code pixels.[o] lor (Char.code pixels.[o + 1] lsl 8) in
              output_char oc (Char.chr ((v lsr 11) lsl 3)); output_char oc (Char.chr (((v lsr 5) land 63) lsl 2)); output_char oc (Char.chr ((v land 31) lsl 3))
            done
          done)
    | _ -> prerr_endline "Boot_bench: no screen of 16 bits to write" in
  let rec script = function "-do" :: d :: _ -> d | _ :: rest -> script rest | [] -> "" in
  let did = ref [] and r0 = ref !ran and b0 = ref (Board.now board) and t0 = ref (Unix.gettimeofday ()) in
  List.iter (fun step ->
    match List.filter (fun w -> w <> "") (String.split_on_char ' ' step) with
    | [ "p"; x; y; b ] -> Board.host_pointer (int_of_string x) (int_of_string y) (int_of_string b); during 20_000; did := step :: !did
    | [ "k"; k ] -> typed k; did := step :: !did
    | [ "shot"; f ] -> shot f
    | [ "prof" ] -> Prof.start ~every:1024
    | [ "s"; n ] ->
        let quiet = ref 0 and left = ref (10 * int_of_string n) in
        while !quiet < 3 && !left > 0 do
          let r = !ran in
          during 100_000; decr left;
          if !ran - r < 150_000 then incr quiet else quiet := 0
        done;
        Printf.eprintf "%-28s %6.1f s, %5.1f million instructions, %.1f s of the board's%s\n%!"
          (String.concat "; " (List.rev !did)) (Unix.gettimeofday () -. !t0) (float_of_int (!ran - !r0) /. 1e6)
          (float_of_int (Board.now board - !b0) /. 1e6) (if !left = 0 then " (not quiet)" else "");
        prerr_string (attached ());
        did := []; r0 := !ran; b0 := Board.now board; t0 := Unix.gettimeofday ()
    | [] -> ()
    | _ -> prerr_endline ("Boot_bench: -do: " ^ step)) (String.split_on_char ';' (script args));
  let rec idling left =
    if left > 0 then begin
      let n = min 10 left in
      (* (not the first ten seconds of more: a program starting) *)
      if prof args <> None && not !Prof.on && (idle <= 10 || left < idle) then Prof.start ~every:1024;
      let t0 = Unix.gettimeofday () and r0 = !ran and b0 = Board.now board in
      let moved = ref b0 in
      while Board.now board - b0 < n * 1_000_000 do
        Board.run board ~batch:4096;
        List.iter (fun (c : Status.cpu) -> ran := !ran + c.ran) (Board.where board);
        if move && Board.now board - !moved > 16_667 then begin
          moved := Board.now board;
          if usb then Board.pointer board [ Usb.Rel_x 3; Usb.Rel_y 2 ]
          else (at := (!at + 3) mod 400; Board.host_pointer (100 + !at) (100 + (!at * 2 / 3)) 0)
        end
      done;
      let s = Unix.gettimeofday () -. t0 in
      Printf.eprintf "%-28s %6.1f s, %5d million instructions: %.2f million for a second of the board's (of %d)\n%!"
        (Printf.sprintf "%d s%s" n (if move then ", the mouse moving" else ", idle")) s ((!ran - r0) / 1_000_000)
        (float_of_int (!ran - r0) /. float_of_int n /. 1e6) ips;
      idling (left - n)
    end in
  idling idle;
  Option.iter (fun f -> Out_channel.with_open_bin f (fun oc -> Out_channel.output_string oc (Prof.contents ()))) (prof args);
  if !Hostdraw.drawn + !Hostdraw.declined > 0 then
    Printf.eprintf "the host's draws: %d, declined %d\n" !Hostdraw.drawn !Hostdraw.declined;
  prerr_string (attached ());
  print_string (Buffer.contents out)
