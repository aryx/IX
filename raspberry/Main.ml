(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-qemu: QEMU's command line, the part the Pi kernels' Makefiles use
 * (plan_pi.md, "The kernels it must boot"); its usage, the options and
 * examples: [help], what mini-qemu -h prints. -smp: the Pi4's cores
 * take turns (plan_pi.md decision 3); QEMU wants 4, mini-qemu defaults
 * to 1, the fastest. *)


let usage = "usage: mini-qemu -M raspi1ap|raspi4b [-m size] [-smp n] [-nographic] (-kernel image | -device loader,file=F,addr=A | -bios F) [-drive file=F,if=sd] [-serial S]... [-ips N] [-d] [-trace N] [-prof F] [-status N] [-symbols ELF]"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A Raspberry Pi 1 (raspi1ap) or 4 (raspi4b), by QEMU's command line; ./mini-pi
gives each kernel its own. For example (Ctrl-A then x quits):
  cd ~/xv6/forks/arm-pi1-bis && mini-qemu -M raspi1ap -kernel kernel.img -nographic
  cd kernel/xv6 && mini-qemu -M raspi1ap -device loader,file=kernel-pi1.img,addr=0x8000 -nographic
  cd ~/xv6/forks/arm64-pi4 && mini-qemu -cpu cortex-a72 -M raspi4b -kernel kernel/kernel -m 2G -smp 1 -nographic
The UART is this terminal, raw. Accepted as QEMU's: -cpu -serial -monitor -append
-netdev -no-reboot, -device usb-kbd, usb-mouse, usb-net (Usernet, QEMU's user net).
Its own: -ips N, instructions a simulated microsecond (30); -d, unassigned I/O and
undefined instructions logged; -trace N, the Pi4's first N instructions (-N: every
N-th); -prof F, every 1024th PC counted into F; -status N, where the guest is,
every N seconds (-symbols ELF: its PCs named), all on standard error.
|}

(* the board run in batches; the host's input polled (raw on a
 * terminal, Ctrl-A x to quit), the console's output written, the
 * screen shown 30 times a second of the host's, QMP served.
 *
 * claude: with a window, the board's time ([now], microseconds) is kept
 * from running ahead of the host's: an idle kernel's time skips to its
 * next tick (the WFI), so without it a key held 100ms of a person's
 * time lasted far longer in the board's, and 9pi's usb/kb repeated it
 * (its repeat starts after 160ms: "ls" gave "lsss"). QEMU keeps its
 * clock the host's too. Behind (a busy kernel), the board does not
 * catch up: the time lost is lost, as a slower machine's. Without a
 * window (the tests, session.py's timed keys), it runs as fast as it
 * can, its time the instructions' only. *)
let loop caps ~out ~graphics ~qmp ~run ~now ~input ~frame ~key ~pointer ~qmp_poll ~status ~where =
  let tty = Unix.isatty Unix.stdin in
  let saved = if tty then Some (Unix.tcgetattr Unix.stdin) else None in
  Option.iter (fun (a : Unix.terminal_io) ->
    Unix.tcsetattr Unix.stdin TCSANOW { a with c_icanon = false; c_echo = false; c_isig = false; c_icrnl = false; c_vmin = 1 }) saved;
  let restore () = Option.iter (fun a -> Unix.tcsetattr Unix.stdin TCSANOW a) saved in
  let open_input = ref true and ctrl_a = ref false in
  let buf = Bytes.create 256 in
  let poll () =
    if !open_input then
      match Unix.select [ Unix.stdin ] [] [] 0.0 with
      | [ _ ], _, _ ->
          let n = try Unix.read Unix.stdin buf 0 256 with Unix.Unix_error _ -> 0 in
          if n = 0 then open_input := false;
          for i = 0 to n - 1 do
            let c = Bytes.get buf i in
            if tty && !ctrl_a && c = 'x' then (restore (); Console.print caps "\nmini-qemu: terminated\n"; exit 0);
            ctrl_a := tty && c = '\001';
            if not !ctrl_a then input c
          done
      | _ -> () in
  let display =
    if graphics && Sys.getenv_opt "DISPLAY" <> None then Sdl_display.create ~title:"mini-qemu" else Display.none in
  let qmp = Option.map Qmp.create qmp in
  let quit () = restore (); exit 0 in
  let last_frame = ref 0. and at_bol = ref true in
  let n = ref 0 in
  let paced = display != Display.none in
  (* the host's time when the board's was 0 *)
  let base = ref (Unix.gettimeofday ()) in
  let pace () =
    let ahead = (float_of_int (now ()) /. 1e6) -. (Unix.gettimeofday () -. !base) in
    if ahead > 0.001 then Unix.sleepf (min ahead 0.02)
    else if ahead < 0. then base := !base -. ahead in
  (try
     while true do
       run ();
       Option.iter (fun st -> Status.sample st (where ())) status;
       if Buffer.length out > 0 then begin
         at_bol := Buffer.nth out (Buffer.length out - 1) = '\n';
         Console.print caps (Buffer.contents out); flush stdout; Buffer.clear out
       end;
       incr n;
       if !n land 15 = 0 then begin
         if paced then pace ();
         (* claude: on its own line, not after a prompt *)
         Option.iter (fun st -> Option.iter (fun l -> Console.eprint caps ((if !at_bol then "" else "\n") ^ "mini-qemu: " ^ l ^ "\n"); at_bol := true)
           (Status.report st ~now:(now ()))) status;
         poll ();
         Usernet.poll_all ();
         Option.iter (fun q -> qmp_poll q ~quit) qmp;
         let now = Unix.gettimeofday () in
         if now -. !last_frame > 1. /. 30. then begin
           last_frame := now;
           Option.iter (fun (g, data) -> display.Display.present g data) (frame ());
           (* the mouse's events of a poll synced as one, as QEMU syncs
            * a window's *)
           let evs = display.poll () in
           List.iter (function Display.Key (u, down) -> key u down | Display.Quit -> quit () | _ -> ()) evs;
           let inputs = List.concat_map (function
             | Display.Motion (dx, dy) -> [ Usb.Rel_x dx; Usb.Rel_y dy ]
             | Display.Button (b, down) -> [ Usb.Button (b, down) ]
             | Display.Wheel v -> [ Usb.Wheel v ]
             | _ -> []) evs in
           if inputs <> [] then pointer inputs
         end
       end
     done
   with e -> restore (); raise e);
  0

let main (caps : < Cap.argv; Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  if List.mem "-h" args || List.mem "--help" args then (Console.print caps help; exit 0);
  let kernel = ref None and machine = ref "" and ips = ref 30 and debug = ref false and usb = ref [] in
  let qmp = ref None and graphics = ref true in
  let serials = ref [] and drive = ref None and loader = ref None in
  let ram = ref (2 * 1024 * 1024 * 1024) and smp = ref 1 and trace = ref 0 and prof = ref None in
  let status = ref 0. and symbols = ref None in
  (* QEMU's sizes: a number of MB, or with a suffix K, M, G *)
  let size s =
    let n = String.length s in
    let num k = int_of_string (String.sub s 0 k) in
    match s.[n - 1] with
    | 'G' | 'g' -> num (n - 1) lsl 30 | 'M' | 'm' -> num (n - 1) lsl 20 | 'K' | 'k' -> num (n - 1) lsl 10
    | _ -> num n lsl 20 in
  (* key=value options, after the first comma-separated word *)
  let options s = List.filter_map (fun kv -> match String.index_opt kv '=' with
    | Some i -> Some (String.sub kv 0 i, String.sub kv (i + 1) (String.length kv - i - 1)) | None -> None) (String.split_on_char ',' s) in
  let rec parse = function
    | [] -> ()
    | ("-M" | "-machine") :: m :: rest -> machine := List.hd (String.split_on_char ',' m); parse rest
    | "-kernel" :: k :: rest -> kernel := Some k; parse rest
    | "-ips" :: n :: rest -> ips := int_of_string n; parse rest
    | "-d" :: rest -> debug := true; parse rest
    | "-trace" :: n :: rest -> trace := int_of_string n; parse rest
    | "-prof" :: f :: rest -> prof := Some f; parse rest
    | "-status" :: n :: rest -> status := float_of_string n; parse rest
    | "-symbols" :: f :: rest -> symbols := Some f; parse rest
    | "-device" :: d :: rest when List.mem (List.hd (String.split_on_char ',' d)) [ "usb-kbd"; "usb-mouse"; "usb-net" ] ->
        usb := !usb @ [ List.hd (String.split_on_char ',' d) ]; parse rest
    | "-device" :: d :: rest when List.hd (String.split_on_char ',' d) = "loader" ->
        let o = options d in
        (match List.assoc_opt "file" o, List.assoc_opt "addr" o with
         | Some f, Some a -> loader := Some (f, int_of_string a)
         | _ -> Console.eprint caps "mini-qemu: -device loader needs file= and addr=\n"; exit 2);
        parse rest
    | "-bios" :: f :: rest -> loader := Some (f, 0x8000); parse rest
    | "-drive" :: d :: rest ->
        let o = options ("drive," ^ d) in
        drive := Some (List.assoc "file" o, List.assoc_opt "snapshot" o = Some "on"); parse rest
    | "-serial" :: s :: rest -> serials := !serials @ [ s ]; parse rest
    | "-qmp" :: q :: rest -> qmp := Some q; parse rest
    | "-display" :: "none" :: rest -> graphics := false; parse rest
    | "-nographic" :: rest -> graphics := false; parse rest
    | "-m" :: m :: rest -> ram := size (List.hd (String.split_on_char ',' m)); parse rest
    | "-smp" :: n :: rest -> smp := int_of_string (List.hd (String.split_on_char ',' n)); parse rest
    | ("-monitor" | "-device" | "-append" | "-D" | "-display" | "-cpu" | "-netdev") :: _ :: rest -> parse rest
    | ("-no-reboot" | "-S") :: rest -> parse rest
    | a :: _ -> Console.eprint caps (Printf.sprintf "mini-qemu: unknown option %s\n%s   (-h: how)\n" a usage); exit 2 in
  parse args;
  match !kernel, !loader with
  | None, None -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  | _ when !machine <> "raspi1ap" && !machine <> "raspi4b" ->
      Console.eprint caps (Printf.sprintf "mini-qemu: machine %s not (yet) supported\n" !machine); 2
  | _ when !machine = "raspi4b" && (!smp < 1 || !smp > 4) ->
      Console.eprint caps "mini-qemu: raspi4b: -smp 1 to 4\n"; 2
  | kernel, loader ->
      (* the profile written at any exit: Ctrl-A x, QMP's quit, the
       * window closed, and SIGTERM (a test script's kill) made one *)
      Option.iter (fun f ->
        Prof.start ~every:1024;
        at_exit (fun () -> Out_channel.with_open_bin f (fun oc -> output_string oc (Prof.contents ())));
        Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> exit 0))) !prof;
      let log s = if !debug || !trace <> 0 then Console.eprint caps ("mini-qemu: " ^ s ^ "\n") in
      let out = Buffer.create 256 in
      (* claude: -symbols ELF, for -status: none when not an ELF (9pi's
       * Plan 9 a.out) *)
      let symbols = match !symbols with
        | None -> []
        | Some f ->
            (try Elf.symbols (FS.read caps (Fpath.v f)) with
             | Sys_error m | Elf.Bad m -> Console.eprint caps ("mini-qemu: -symbols: " ^ m ^ "\n"); []
             | Invalid_argument _ | Not_found -> Console.eprint caps ("mini-qemu: -symbols " ^ f ^ ": no symbols read\n"); []) in
      let status = if !status > 0. then Some (Status.create ~every:!status ~symbols) else None in
      (* the serials, QEMU's order: the PL011, the mini UART; stdio (or
       * mon:stdio) the console, null or absent nowhere; with none said,
       * the PL011 on stdio *)
      let serials = if !serials = [] then [ "stdio" ] else !serials in
      let target i = match List.nth_opt serials i with
        | Some ("stdio" | "mon:stdio") -> Buffer.add_char out
        | Some "null" | None -> ignore
        | Some s -> Console.eprint caps ("mini-qemu: -serial " ^ s ^ ": only stdio, mon:stdio, null\n"); exit 2 in
      let read f = match FS.read caps (Fpath.v f) with
        | image -> image
        | exception Sys_error m -> Console.eprint caps ("mini-qemu: " ^ m ^ "\n"); exit 1 in
      if !machine = "raspi4b" then begin
        let sd = Option.map (fun (f, snapshot) -> Storage.file f ~snapshot) !drive in
        let board = Pi4.create { ram_size = !ram; ips = !ips; log; serial = target 0; trace = !trace; cores = !smp; usb_devices = !usb; sd } in
        (match kernel with
         | Some k ->
             let image = read k in
             if String.length image >= 4 && String.sub image 0 4 = "\127ELF" then
               (try Pi4.load_elf board image with Elf.Bad m -> Console.eprint caps ("mini-qemu: " ^ k ^ ": " ^ m ^ "\n"); exit 1)
             else Pi4.load_raw board image
         | None -> Console.eprint caps "mini-qemu: raspi4b: -kernel only\n"; exit 2);
        (* claude: the Pi4's framebuffer in the window and QMP's
         * screendump; the USB keyboard and mouse on its DWC2 *)
        let machine = { Qmp.screen = (fun () -> Pi4.screen board); send_keys = Pi4.send_keys board;
                        key = Pi4.key board; pointer = Pi4.pointer board } in
        loop caps ~out ~graphics:!graphics ~qmp:!qmp ~run:(fun () -> Pi4.run board ~batch:4096) ~now:(fun () -> Pi4.now board) ~input:(Pi4.input board)
          ~frame:(fun () -> Pi4.frame board) ~key:(Pi4.key board) ~pointer:(Pi4.pointer board)
          ~qmp_poll:(fun q ~quit -> Qmp.poll q machine ~quit) ~status ~where:(fun () -> Pi4.where board)
      end
      else begin
        let console = match List.nth_opt serials 1 with Some ("stdio" | "mon:stdio") -> 1 | _ -> 0 in
        let sd = Option.map (fun (f, snapshot) -> Storage.file f ~snapshot) !drive in
        let board = Board.create { ram_size = 512 * 1024 * 1024; ips = !ips; log; usb_devices = !usb; sd;
                                   serial0 = target 0; serial1 = target 1; console } in
        (match kernel, loader with
         | _, Some (f, addr) -> Board.load_raw board ~addr (read f)
         | Some k, None -> Board.load_kernel board (read k)
         | None, None -> ());
        loop caps ~out ~graphics:!graphics ~qmp:!qmp ~run:(fun () -> Board.run board ~batch:4096) ~now:(fun () -> Board.now board) ~input:(Board.input board)
          ~frame:(fun () -> Board.frame board) ~key:(Board.key board) ~pointer:(Board.pointer board) ~qmp_poll:(fun q ~quit ->
            Qmp.poll q { Qmp.screen = (fun () -> Board.screen board); send_keys = Board.send_keys board;
                         key = Board.key board; pointer = Board.pointer board } ~quit)
          ~status ~where:(fun () -> Board.where board)
      end

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
