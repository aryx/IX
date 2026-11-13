(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-stats: Plan 9's stats (principia's profilers/misc/stats.c). It
 * keeps one of its graphs, the one that was asked for (the author,
 * 2026-10-12: "an application to display the cpu activity, a bit like
 * xosview on linux", "so we can see the 4 cores activity, whether they
 * are idle or not", "I think plan9 had such an application actually").
 * That graph is a strip for each core of the machine that shows how
 * busy it was, with the newest sample at the right, and the strip moves
 * left five times a second. There are also (the author, 2026-11-01:
 * "not just display cpu stats but also memory, disk, etc.") a strip for
 * the memory taken, one for the network's packets, and one for the
 * bytes of the disk, for those that the machine has.
 *
 *   cpu0  37% |        ..::||||::.            |
 *   mem   41% |______________________________.|
 *   net   12  |     .       ...               |
 *   disk 340K |  ...||..     .                |
 *
 * usage: stats [-cmed]. The letters choose the strips: the cores, the
 * memory, the ethernet, the disk; all of them by default.
 *
 * It reads the kernel's /dev/sysstat (Devcons), which has a line for
 * each core with ten numbers; the ninth is the percent of its time
 * that the core had nothing to run. In mini-9pi this covers the last
 * fifth of a second, which is why mini-stats reads it five times a
 * second. It also reads /dev/swap, /net/ether0/stats and /dev/sdM0/ctl;
 * Sysinfo says what each one says. The network and the disk are drawn
 * on a scale of powers of ten (Sysinfo says why); the number beside a
 * strip is the real one, for one second. The right button's menu has
 * exit.
 *
 * Here is what "busy" means for a core: running a process, being in
 * the kernel, or waiting for the kernel's lock (mini-9pi has one lock
 * for its whole kernel: plan_multicore.md). Two games that draw a lot
 * show two cores busy, where one of them mostly waits for the other to
 * leave the kernel.
 *
 * What is not kept from Plan 9's stats: its other graphs (interrupts,
 * system calls, the load; mini-9pi's sysstat says 0 for most of them),
 * the machines over the network, and its letters (its -c is for the
 * context switches and -l for the load, where here -c gives the
 * cores). Its graphs have no disk; the
 * disk's counter here is ours.
 *
 * cs-history:
 * xosview (Mike Romberg, 1993) drew its meters for X from Linux's
 * /proc. Plan 9's stats (1990) reads /dev/sysstat and /dev/swap, which
 * is the same idea three years earlier: what the kernel counts is the
 * text of a file, and the meter is a program like any other, which
 * could just as well be rc and cat. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.open_in; Cap.stderr >

(* A file kept open and read again from its start, as Plan 9's stats: under
 * mini-rio each open of /dev/... asks rio's file server first, and is told
 * no, 5 times a second a file (old: opened at each sample: 32% of the
 * processor under QEMU, alone, against 17% for /dev/sysstat alone). None
 * when the machine has no such file. *)
let reader (caps : < Cap.open_in; .. >) path : (unit -> string option) option =
  match FS.open_in_fd caps path with
  | exception (Unix.Unix_error _ | Sys_error _) -> None
  | fd ->
      let b = Bytes.create 4096 in
      Some (fun () ->
        try
          ignore (Unix.lseek fd 0 Unix.SEEK_SET);
          Some (Bytes.sub_string b 0 (Unix.read fd b 0 4096))
        with Unix.Unix_error _ -> None)

type event = Mouse of Mouse.state | Tick

(* a strip: its name, and at each sample how high (0 to 100) and what to say *)
type meter = { name : string; sample : unit -> int * string }

(* samples a second: a counter's growth is that many times a second's *)
let rate = 5

(* a counter's meter: how much it grew since the last sample *)
let counter (read : unit -> int option) name top : meter =
  let last = ref (match read () with Some v -> v | None -> 0) in
  { name;
    sample = (fun () ->
      match read () with
      | Some now ->
          let v = Sysinfo.grew !last now * rate in
          last := now;
          (Sysinfo.log_percent top v, Sysinfo.short v)
      | None -> (0, "?")) }

(* those of the machine, among those asked: a letter each *)
let meters (caps : < Cap.open_in; .. >) (asked : string) : meter list =
  let wants c = String.contains asked c in
  (* a file's meters when it is wanted, there, and says what is looked for *)
  let from c path (make : (unit -> string option) -> meter list) =
    if not (wants c) then []
    else match reader caps path with Some read -> make read | None -> [] in
  let percent name (value : unit -> int option) =
    { name;
      sample = (fun () ->
        match value () with
        | Some v -> (v, Printf.sprintf "%d%%" v)
        | None -> (0, "?")) } in
  let cpu = from 'c' "/dev/sysstat" (fun read ->
      let now () = match read () with Some t -> Sysinfo.cores t | None -> [] in
      List.mapi (fun c _ -> percent (Printf.sprintf "cpu%d" c) (fun () -> List.nth_opt (now ()) c)) (now ())) in
  let mem = from 'm' "/dev/swap" (fun read ->
      let now () = Option.bind (read ()) Sysinfo.memory in
      if now () = None then [] else [ percent "mem" now ]) in
  (* (a counter the file has, or no meter) *)
  let growing read parse name top =
    let now () = Option.bind (read ()) parse in
    if now () = None then [] else [ counter now name top ] in
  let net = from 'e' "/net/ether0/stats" (fun read ->
      growing read (fun t -> Option.map (fun (i, o) -> i + o) (Sysinfo.ether t)) "net" 10000) in
  let disk = from 'd' "/dev/sdM0/ctl" (fun read ->
      growing read (fun t -> Option.map (fun (r, w) -> r + w) (Sysinfo.disk t)) "disk" 10000000) in
  cpu @ mem @ net @ disk

(* a sample's width on the screen, in pixels; how many are kept (a
 * screen's width of them) *)
let wide = 2
let kept = 1024

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let usage () = Console.eprint caps (Printf.sprintf "usage: %s [-cmed]\n" argv.(0)); Exit.Err "usage" in
  let asked =
    if Array.length argv = 1 then Some "cmed"
    else if Array.length argv = 2 && String.length argv.(1) > 1 && argv.(1).[0] = '-' then Some argv.(1)
    else None in
  match asked with
  | None -> usage ()
  | Some asked ->
    match meters caps asked with
    | [] -> Console.eprint caps "mini-stats: none of those here (mini-9pi's /dev/sysstat...)\n"; Exit.Err "no files"
    | all ->
        let n = List.length all in
        let display = Display.init caps in
        let font = Font.default display and mouse = Mouse.init caps in
        let ticks = Source.timer caps (1. /. float rate) in
        let white = Display.color display Display.white and black = Display.color display Display.black in
        let pale = Display.color display (Display.rgb 0xee 0xff 0xee) and green = Display.color display (Display.rgb 0x33 0x99 0x44) in
        (* the samples: meter c's k-th is history.(c).(k mod kept) *)
        let history = Array.init n (fun _ -> Array.make kept 0) in
        let said = Array.make n "" in
        let count = ref 0 in
        let left = Font.width font "cpu0 100%  " in
        (* meter c's row in the window, and in it the strip's inside *)
        let row (view : Display.image) c : Rectangle.t =
          let r : Rectangle.t = Rectangle.inset view.r 4 in
          let at k = r.min.y + ((r.max.y - r.min.y) * k / n) in
          Rectangle.v r.min.x (at c) r.max.x (at (c + 1) - 2) in
        let strip view c : Rectangle.t =
          let r = row view c in
          Rectangle.inset (Rectangle.v (r.min.x + left) r.min.y r.max.x r.max.y) 1 in
        (* a sample's column, its right side at x: pale above, green for how high *)
        let column view (g : Rectangle.t) x high =
          let x0 = max g.min.x (x - wide) in
          let y = g.max.y - ((g.max.y - g.min.y) * high / 100) in
          if x > x0 then begin
            Draw.fill view (Rectangle.v x0 g.min.y x y) pale;
            Draw.fill view (Rectangle.v x0 y x g.max.y) green
          end in
        (* its name and what it says now, in the row's middle *)
        let label (view : Display.image) c (m : meter) =
          let r = row view c in
          let y = r.min.y + (max 0 (Rectangle.dy r - Font.height font) / 2) in
          Draw.fill view (Rectangle.v r.min.x r.min.y (r.min.x + left - 2) r.max.y) white;
          ignore (Font.string view (Point.v r.min.x y) black font m.name);
          let w = Font.width font said.(c) in
          ignore (Font.string view (Point.v (r.min.x + left - 6 - w) y) black font said.(c)) in
        (* everything again: a new window, or one of another size *)
        let paint (view : Display.image) =
          Draw.fill view view.r white;
          List.iteri (fun c m ->
            let g = strip view c in
            label view c m;
            Draw.border view (Rectangle.inset g (-1)) 1 black;
            Draw.fill view g pale;
            let rec back k x =
              if k < !count && k < kept && x > g.min.x then begin
                column view g x history.(c).((!count - 1 - k) mod kept); back (k + 1) (x - wide)
              end in
            back 0 g.max.x) all;
          Display.flush display in
        (* a sample more: each strip moved left by the screen's own
         * pixels (as stats: no sample drawn twice), the new one at
         * the right *)
        let step (view : Display.image) =
          List.iteri (fun c (m : meter) ->
            let high, words = m.sample () in
            let g = strip view c in
            history.(c).(!count mod kept) <- high;
            said.(c) <- words;
            if g.max.x - g.min.x > wide then
              Draw.draw view (Rectangle.v g.min.x g.min.y (g.max.x - wide) g.max.y) view None (Point.v (g.min.x + wide) g.min.y);
            column view g g.max.x high;
            label view c m) all;
          incr count;
          Display.flush display in
        let rec loop view =
          match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive ticks) (fun () -> Tick) ] with
          | Tick -> step view; loop view
          | Mouse m ->
              if m.resized then begin let view = Display.screen display in paint view; loop view end
              else if m.buttons = 4 then (match Menu.hit view font mouse 4 [ "exit" ] 0 m.pos with Some _ -> () | None -> loop view)
              else loop view in
        let view = Display.screen display in
        paint view;
        loop view;
        Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
