(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-stats: Plan 9's stats (principia's apps/misc/stats.c), of which
 * it keeps one graph, the one asked for (the author, 2026-10-12:
 * "an application to display the cpu activity, a bit like xosview on
 * linux", "so we can see the 4 cores activity, whether they are idle
 * or not", "I think plan9 had such an application actually"): a strip
 * for each core of the machine, how busy it was, the newest at the
 * right, the strip moving left five times a second.
 *
 *   cpu0  |        ..::||||::.            |
 *    37%  |__...::||||||||||||||::..______|
 *   cpu1  |                               |
 *     0%  |_______________________________|
 *
 * What it reads is the kernel's /dev/sysstat (Devcons), a line for
 * each core, ten numbers; the ninth is the percent of its time the
 * core had nothing to run. mini-9pi's is of the last fifth of a
 * second, which is why this reads five times a second. The right
 * button's menu has exit.
 *
 * What a core "busy" is here: running a process, or in the kernel,
 * or waiting for the kernel's lock (mini-9pi has one lock for its
 * kernel: plan_multicore.md). Two games that draw much show two cores
 * busy where one of them mostly waits for the other to leave the
 * kernel.
 *
 * Not Plan 9's: the other graphs (memory, the network, interrupts,
 * system calls, the load: mini-9pi's sysstat says 0 for most), the
 * machines over the network, the options.
 *
 * history:
 * xosview (Mike Romberg, 1993) drew its meters for X from Linux's
 * /proc; Plan 9's stats (1990) reads /dev/sysstat and /dev/swap, the
 * same idea three years before: what the kernel counts is a file's
 * text, and the meter a program like any, that could as well be rc
 * and cat. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.open_in; Cap.stderr >

(* each core's percent busy now, in the cores' order *)
let sample (caps : < Cap.open_in; .. >) : int list =
  let fd = FS.open_in_fd caps "/dev/sysstat" in
  let b = Bytes.create 2048 in
  let n = Unix.read fd b 0 2048 in
  Unix.close fd;
  List.filter_map (fun line ->
    let fields = List.filter (fun f -> f <> "") (String.split_on_char ' ' line) in
    if List.length fields >= 9 then Some (100 - int_of_string (List.nth fields 8)) else None)
    (String.split_on_char '\n' (Bytes.sub_string b 0 n))

type event = Mouse of Mouse.state | Tick

(* a sample's width on the screen, in pixels; how many are kept (a
 * screen's width of them) *)
let wide = 2
let kept = 1024

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  if Array.length argv > 1 then begin Console.eprint caps (Printf.sprintf "Usage: %s\n" argv.(0)); Exit.Err "usage" end
  else
    match sample caps with
    | exception Unix.Unix_error _ -> Console.eprint caps "mini-stats: no /dev/sysstat (mini-9pi's)\n"; Exit.Err "sysstat"
    | first ->
        let n = max 1 (List.length first) in
        let display = Display.init caps in
        let font = Font.default display and mouse = Mouse.init caps in
        let ticks = Source.timer caps 0.2 in
        let white = Display.color display Display.white and black = Display.color display Display.black in
        let pale = Display.color display (Display.rgb 0xee 0xff 0xee) and green = Display.color display (Display.rgb 0x33 0x99 0x44) in
        (* the samples: core c's k-th is history.(c).(k mod kept) *)
        let history = Array.init n (fun _ -> Array.make kept 0) in
        let count = ref 0 in
        let left = Font.width font "cpu0 " in
        (* core c's row in the window, and in it the strip's inside *)
        let row (view : Display.image) c : Rectangle.t =
          let r : Rectangle.t = Rectangle.inset view.r 4 in
          let at k = r.min.y + ((r.max.y - r.min.y) * k / n) in
          Rectangle.v r.min.x (at c) r.max.x (at (c + 1) - 2) in
        let strip view c : Rectangle.t =
          let r = row view c in
          Rectangle.inset (Rectangle.v (r.min.x + left) r.min.y r.max.x r.max.y) 1 in
        (* a sample's column, its right side at x: pale above, green for what was busy *)
        let column view (g : Rectangle.t) x busy =
          let x0 = max g.min.x (x - wide) in
          let y = g.max.y - ((g.max.y - g.min.y) * busy / 100) in
          if x > x0 then begin
            Draw.fill view (Rectangle.v x0 g.min.y x y) pale;
            Draw.fill view (Rectangle.v x0 y x g.max.y) green
          end in
        let label (view : Display.image) c busy =
          let r = row view c in
          let text = Printf.sprintf "%3d%% " busy in
          let y = r.min.y + Font.height font in
          Draw.fill view (Rectangle.v r.min.x y (r.min.x + left) (y + Font.height font)) white;
          ignore (Font.string view (Point.v r.min.x y) black font text) in
        (* everything again: a new window, or one of another size *)
        let paint (view : Display.image) =
          Draw.fill view view.r white;
          for c = 0 to n - 1 do
            let r = row view c and g = strip view c in
            ignore (Font.string view r.min black font (Printf.sprintf "cpu%d" c));
            Draw.border view (Rectangle.inset g (-1)) 1 black;
            Draw.fill view g pale;
            let rec back k x =
              if k < !count && k < kept && x > g.min.x then begin
                column view g x history.(c).((!count - 1 - k) mod kept); back (k + 1) (x - wide)
              end in
            back 0 g.max.x;
            if !count > 0 then label view c history.(c).((!count - 1) mod kept)
          done;
          Display.flush display in
        (* a sample more: each strip moved left by the screen's own
         * pixels (as stats: no sample drawn twice), the new one at
         * the right *)
        let step (view : Display.image) busy =
          List.iteri (fun c v ->
            if c < n then begin
              let g = strip view c in
              history.(c).(!count mod kept) <- v;
              if g.max.x - g.min.x > wide then
                Draw.draw view (Rectangle.v g.min.x g.min.y (g.max.x - wide) g.max.y) view None (Point.v (g.min.x + wide) g.min.y);
              column view g g.max.x v;
              label view c v
            end) busy;
          incr count;
          Display.flush display in
        let rec loop view =
          match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive ticks) (fun () -> Tick) ] with
          | Tick -> step view (sample caps); loop view
          | Mouse m ->
              if m.resized then begin let view = Display.screen display in paint view; loop view end
              else if m.buttons = 4 then (match Menu.hit view font mouse 4 [ "exit" ] 0 m.pos with Some _ -> () | None -> loop view)
              else loop view in
        let view = Display.screen display in
        paint view;
        loop view;
        Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
