(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Session.mli *)

type cli = {
  mutable frames : int;
  mutable file : string;
  mutable fixed_time : float option;
  mutable script : Input_script.t option;
  mutable args : string list;
}

let usage = "usage: game [-dump-frame n file.ppm | -frames n] [-fixed-time seconds] [-script script] [name=value]..."

let parse (argv : string array) : cli =
  let cli = { frames = 0; file = ""; fixed_time = None; script = None; args = [] } in
  let file_next = ref false in
  let anonymous (s : string) : unit = if !file_next then (cli.file <- s; file_next := false) else cli.args <- s :: cli.args in
  let options = [
    (* (two words after it: the second is the next word without a dash; ix's Arg has no Tuple) *)
    "-dump-frame", Arg.Int (fun (n : int) -> cli.frames <- n; file_next := true), " n file: frame n written to file (a PPM), and the end";
    "-frames", Arg.Int (fun (n : int) -> cli.frames <- n), " n: n frames, then the picture stays";
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

type ('model, 'msg) t = {
  app : ('model, 'msg) Playground.app;
  mutable model : 'model;
  (* a command's message is the next frame's (Cmd.mli); the last first *)
  mutable pending : 'msg list;
}

let perform (run : ('model, 'msg) t) (cmd : 'msg Cmd.t) : unit =
  List.iter (fun (c : 'msg Cmd.t) -> match c with Cmd.Msg m -> run.pending <- m :: run.pending | Cmd.None | Cmd.Batch _ -> ())
    (Cmd.to_list cmd)

let start (app : ('model, 'msg) Playground.app) (flags : Playground.flags) : ('model, 'msg) t =
  let model, cmd = app.init flags in
  let run = { app; model; pending = [] } in
  perform run cmd;
  run

let apply (run : ('model, 'msg) t) (msg : 'msg) : unit =
  let model, cmd = run.app.update msg run.model in
  run.model <- model;
  perform run cmd

let event (run : ('model, 'msg) t) (e : Sub.event) : unit =
  match Sub.event_to_msgopt e (run.app.subscriptions run.model) with Some msg -> apply run msg | None -> ()

let frame (run : ('model, 'msg) t) (script : Input_script.t option) (n : int) (time : float) : unit =
  (match script with
   | None -> ()
   | Some script ->
       List.iter (fun ((key, is_down) : string * bool) -> event run (Sub.EKeyChanged (is_down, key))) (Input_script.changes script n);
       (match Input_script.mouse script n with
        | Some (x, y) -> event run (Sub.EMouseMove (int_of_float x, int_of_float y))
        | None -> ());
       List.iter
         (fun ((right, is_down) : bool * bool) -> event run (if right then Sub.ERightMouseButton is_down else Sub.EMouseButton is_down))
         (Input_script.button_changes script n);
       List.iter (fun (is_down : bool) -> event run (Sub.EMiddleMouseButton is_down)) (Input_script.middle_changes script n);
       (match Input_script.typed script n with "" -> () | s -> event run (Sub.ETyped s)));
  let msgs = List.rev run.pending in
  run.pending <- [];
  List.iter (apply run) msgs;
  event run (Sub.ETick time)

let view (run : ('model, 'msg) t) : Playground.shape list = run.app.view run.model

let time_of_frame (cli : cli) (n : int) : float =
  match cli.fixed_time with Some t -> t | None -> 1000. +. (float (n - 1) /. 60.)

(* (left-aligned, its baseline 5% above the bottom: words are centred on
 * their position, so half their width to the right, and up by the 9
 * font units from Hershey's middle to its baseline; all of it in
 * pixels, so divided by the scale the view is drawn with) *)
let fps_counter ~(width : int) ~(height : int) ~(scale : float) (fps : int) : Playground.shape =
  let w = float width and h = float height in
  let text = Printf.sprintf "%dx%d -- %d fps" width height fps in
  let _strokes, length = Hershey.layout text in
  let unit = Playground.words_font_size /. Hershey.units_per_em in
  Playground.words Playground.black text
  |> Playground.scale (1. /. scale)
  |> Playground.move ((-.(0.45 *. w) +. (length *. unit /. 2.)) /. scale) ((-.(0.45 *. h) +. (9. *. unit)) /. scale)

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
