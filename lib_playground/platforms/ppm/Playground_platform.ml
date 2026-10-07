(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The platform without a window (docs/plans/plan_playground.md,
 * decision 4): the program is run a number of frames, its keys and its
 * mouse those of a script, and the last frame is written as a picture
 * (PPM). The playground's own tests run its games so (its platforms'
 * -dump-frame, -fixed-time and -script: the same words here, so that a
 * frame is compared with theirs), and ix's run on Linux with no SDL.
 *
 * The pixels are Shape_render_software's, in a Framebuffer of the
 * playground's screen, 1000 by 1000.
 *
 * usage: game -dump-frame n file.ppm [-fixed-time seconds] [-script script] [name=value]...
 *   -dump-frame n file   frame n (the first is 1) written to file, and the end
 *   -fixed-time seconds  the program's clock stays there (else it starts at
 *                        1000 and each frame is a sixtieth of a second)
 *   -script script       what is pressed, frame by frame (Input_script.mli)
 *   name=value           the program's flags (Playground.flags) *)

type cli = {
  mutable frame : int;
  mutable file : string;
  mutable fixed_time : float option;
  mutable script : Input_script.t option;
  mutable args : string list;
}

let usage = "usage: game -dump-frame n file.ppm [-fixed-time seconds] [-script script] [name=value]..."

let parse (argv : string array) : cli =
  let cli = { frame = 0; file = ""; fixed_time = None; script = None; args = [] } in
  let file_next = ref false in
  let anonymous (s : string) : unit = if !file_next then (cli.file <- s; file_next := false) else cli.args <- s :: cli.args in
  let options = [
    (* (two words after it: the second is the next word without a dash; ix's Arg has no Tuple) *)
    "-dump-frame", Arg.Int (fun (n : int) -> cli.frame <- n; file_next := true), " n file: frame n written to file (a PPM), and the end";
    "-fixed-time", Arg.Float (fun (t : float) -> cli.fixed_time <- Some t), " seconds: the program's clock stays there";
    "-script", Arg.String (fun (s : string) ->
        match Input_script.parse s with Ok sc -> cli.script <- Some sc | Error msg -> raise (Arg.Bad msg)),
    " script: what is pressed, frame by frame";
    (* (the playground's tests give it: its debug keys, which are not here) *)
    "-keys", Arg.String (fun (_ : string) -> ()), " keys: nothing";
  ] in
  (* (from the first word each time: flags reads the command line, then run_app) *)
  Arg.current := 0;
  (try Arg.parse_argv argv options anonymous usage with
   | Arg.Bad msg | Arg.Help msg -> failwith msg);
  cli.args <- List.rev cli.args;
  cli

let flags (caps : < Cap.argv ; .. >) : Playground.flags = Playground.flags_of_strings (parse (CapSys.argv caps)).args

(* The playground's platforms write this over a frame, at the bottom
 * left: the window's size and the frames a second (0 when a frame is
 * dumped). Here so that a frame is theirs to the pixel. *)
let fps_counter (fb : Framebuffer.t) : Playground.shape =
  let w = float fb.width and h = float fb.height in
  let text = Printf.sprintf "%dx%d -- 0 fps" fb.width fb.height in
  let _strokes, width = Hershey.layout text in
  let unit = Playground.words_font_size /. Hershey.units_per_em in
  Playground.words Playground.black text
  |> Playground.move (-.(0.45 *. w) +. (width *. unit /. 2.)) (-.(0.45 *. h) +. (9. *. unit))

(* P6: the size, then a pixel's red, green and blue, row after row *)
let ppm (fb : Framebuffer.t) : string =
  let b = Buffer.create ((3 * fb.width * fb.height) + 20) in
  Buffer.add_string b (Printf.sprintf "P6\n%d %d\n255\n" fb.width fb.height);
  for y = 0 to fb.height - 1 do
    for x = 0 to fb.width - 1 do
      let rgb = Framebuffer.get_rgb fb ~x ~y in
      Buffer.add_char b (Char.chr (rgb lsr 16));
      Buffer.add_char b (Char.chr ((rgb lsr 8) land 0xFF));
      Buffer.add_char b (Char.chr (rgb land 0xFF))
    done
  done;
  Buffer.contents b

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  let cli = parse (CapSys.argv caps) in
  if cli.frame <= 0 then failwith ("this program has no window here: " ^ usage);
  let model, cmd = app.init flags in
  let model = ref model in
  (* a command's message is the next frame's (Cmd.mli) *)
  let pending = ref [] in
  let perform (cmd : 'msg Cmd.t) : unit =
    List.iter (fun (c : 'msg Cmd.t) -> match c with Cmd.Msg m -> pending := m :: !pending | Cmd.None | Cmd.Batch _ -> ())
      (Cmd.to_list cmd) in
  let apply (msg : 'msg) : unit =
    let m, cmd = app.update msg !model in
    model := m;
    perform cmd in
  let event (e : Sub.event) : unit =
    match Sub.event_to_msgopt e (app.subscriptions !model) with Some msg -> apply msg | None -> () in
  perform cmd;
  (* a frame: what the script does at it, the commands' answers, then the
   * clock's tick (the order of the playground's loop, Native_loop_2d) *)
  for frame = 1 to cli.frame do
    (match cli.script with
     | None -> ()
     | Some script ->
         List.iter (fun ((key, is_down) : string * bool) -> event (Sub.EKeyChanged (is_down, key))) (Input_script.changes script frame);
         (match Input_script.mouse script frame with
          | Some (x, y) -> event (Sub.EMouseMove (int_of_float x, int_of_float y))
          | None -> ());
         List.iter
           (fun ((right, is_down) : bool * bool) -> event (if right then Sub.ERightMouseButton is_down else Sub.EMouseButton is_down))
           (Input_script.button_changes script frame);
         List.iter (fun (is_down : bool) -> event (Sub.EMiddleMouseButton is_down)) (Input_script.middle_changes script frame);
         (match Input_script.typed script frame with "" -> () | s -> event (Sub.ETyped s)));
    let msgs = List.rev !pending in
    pending := [];
    List.iter apply msgs;
    event (Sub.ETick (match cli.fixed_time with Some t -> t | None -> 1000. +. (float (frame - 1) /. 60.)))
  done;
  let fb = Framebuffer.create ~width:(int_of_float Playground.default_width) ~height:(int_of_float Playground.default_height) in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  Shape_render_software.render ~options ~scale:1. fb (app.view !model);
  Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb [ fps_counter fb ];
  FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc (ppm fb)) (Fpath.v cli.file)
