(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, its sections Running, A world and The stepper; the machine's fuel and the stepper's limit are said, where they were optional (docs/plans/plan_scheme.md) *)

(* See DrScheme_run.mli *)

open Playground
open DrScheme_model
open DrScheme_draw

let banner (level : level) : entry list =
  [ Banner (Printf.sprintf "Language: %s." (match level with Beginning -> "Beginning Student" | Standard -> "Standard (R5RS)")); Banner "Welcome to DrScheme, version 209." ]

let style (m : model) : Scheme.style = match m.level with Beginning -> Constructor | Standard -> Write
let running (m : model) : bool = match m.status with Idle -> false | Busy _ | World _ -> true

(*****************************************************************************)
(* Running: a budget of steps a frame *)
(*****************************************************************************)

let fuel = 100_000

let add (e : entry) (m : model) : model =
  match (e, m.entries) with
  (* display's pieces, one entry *)
  | Printed s, Printed t :: rest -> { m with entries = Printed (t ^ s) :: rest }
  | _ -> { m with entries = e :: m.entries }

let flush (m : model) (st : Scheme_eval.state) : model =
  let out, st = Scheme_eval.take_output st in
  let m = { m with machine = Some st } in
  if out = "" then m else add (Printed out) m

let fail (m : model) (from_defs : bool) (err : Scheme_eval.error) : model =
  let m = add (Failure err.message) { m with status = Idle } in
  if from_defs then { m with pink = Option.map (fun (sp : Sexpr.span) -> (sp.start, sp.stop)) err.at } else m

let machine (m : model) : Scheme_eval.state = match m.machine with Some st -> st | None -> Scheme_eval.create ()

(* [work m budget]: the job on, until its steps are spent, it waits
   for a world, or it is done *)
let rec work (m : model) (budget : int) : model =
  match m.status with
  | Idle | World _ -> m
  | Busy job when not job.running -> (
      match job.forms with
      | [] -> { m with status = Idle }
      | f :: rest -> (
          match Scheme_syntax.top f with
          | exception Scheme_syntax.Error (message, span) -> fail m job.from_defs { message; at = Some span }
          | e -> work { m with machine = Some (Scheme_eval.start (machine m) e); status = Busy { job with forms = rest; running = true } } budget))
  | Busy job -> (
      let st = machine m in
      let before = Scheme_eval.steps st in
      match Scheme_eval.run ~fuel:budget st with
      | Running, st -> { m with machine = Some st }
      | Done v, st ->
          let m = flush m st in
          let m = if v = Void then m else add (Result v) m in
          let left = budget - (Scheme_eval.steps st - before) in
          let m = { m with status = Busy { job with running = false } } in
          if left > 0 then work m left else m
      | Failed err, st -> fail (flush m st) job.from_defs err
      | World spec, st -> { (flush m st) with status = World { spec; value = spec.init; picture = None; ticks = 0; after = job } })

(* Execute: a new machine, the Interactions cleared, the definitions
   read and queued *)
let execute (m : model) : model =
  let text = Text_edit.to_string m.defs in
  let m = { m with entries = banner m.level; pink = None; executed = Some text; stepper = None; machine = Some (Scheme_eval.create ()); focus = Interactions } in
  match Sexpr_read.read_all Scheme text with
  | forms -> { m with status = Busy { forms; from_defs = true; running = false } }
  | exception Sexpr_read.Error (msg, pos) -> { (add (Failure ("read: " ^ msg)) m) with pink = Some (pos, min (String.length text) (pos + 1)) }

let break (m : model) : model = if running m then add (Failure "user break") { m with status = Idle } else m

(*****************************************************************************)
(* A world, run by the host *)
(*****************************************************************************)

let handler (w : world) (name : string) : Scheme.t option = List.assoc_opt name w.spec.handlers

(* [call m w name args]: the handler on the world, if there is one;
   Error ends the world *)
let call (m : model) (w : world) (name : string) (args : Scheme.t list) : (model * world, model) result =
  match handler w name with
  | None -> Ok (m, w)
  | Some f -> (
      match Scheme_eval.call ~fuel:1_000_000 (machine m) f args with
      | Ok v, st -> Ok ({ m with machine = Some st }, { w with value = v })
      | Error err, st -> Error (fail { m with machine = Some st } false err))

(* the world ended: big-bang returns the last one, the job goes on *)
let finish (m : model) (w : world) : model =
  { m with machine = Some (Scheme_eval.resume (machine m) w.value); status = Busy w.after }

let stopped (m : model) (w : world) : (bool * model, model) result =
  match handler w "stop-when" with
  | None -> Ok (false, m)
  | Some f -> (
      match Scheme_eval.call ~fuel:1_000_000 (machine m) f [ w.value ] with
      | Ok v, st -> Ok (Scheme.truthy v, { m with machine = Some st })
      | Error err, st -> Error (fail { m with machine = Some st } false err))

(* where the scene is: the window's centre, and the scene scaled to
   fit 800 by 760 *)
let world_scale (i : Scheme_image.t) : float = Float.min 1. (Float.min (800. /. Scheme_image.width i) (760. /. Scheme_image.height i))

let update_world (computer : computer) (m : model) (w : world) : model =
  let ( let* ) r f = match r with Ok x -> f x | Error m -> m in
  let w = { w with ticks = w.ticks + 1 } in
  (* a tick every other frame, 30 a second: HtDP's is 28 *)
  let* m, w = if w.ticks mod 2 = 0 then call m w "on-tick" [ w.value ] else Ok (m, w) in
  let pressed, _ = Bigbang.key_events m.keyboard computer.keyboard in
  let* m, w = List.fold_left (fun r k -> match r with Ok (m, w) -> call m w "on-key" [ w.value; Str k ] | e -> e) (Ok (m, w)) pressed in
  let* m, w =
    match (Bigbang.mouse_event m.mouse computer.mouse, w.picture) with
    | Some ev, Some i ->
        let s = world_scale i in
        let x = ((computer.mouse.mx /. s) +. (Scheme_image.width i /. 2.)) and y = ((Scheme_image.height i /. 2.) -. (computer.mouse.my /. s)) in
        call m w "on-mouse" [ w.value; Int (int_of_float x); Int (int_of_float y); Str ev ]
    | _ -> Ok (m, w)
  in
  let* m, w =
    match handler w "to-draw" with
    | None -> Ok (m, w)
    | Some f -> (
        match Scheme_eval.call ~fuel:1_000_000 (machine m) f [ w.value ] with
        | Ok (Image i), st -> Ok ({ m with machine = Some st }, { w with picture = Some i })
        | Ok v, st -> Error (add (Failure ("to-draw: expected an image, given " ^ Scheme.print (style m) v)) { m with machine = Some st; status = Idle })
        | Error err, st -> Error (fail { m with machine = Some st } false err))
  in
  let* stop, m = stopped m w in
  if stop || List.mem "escape" pressed then finish m w else { m with status = World w }

let view_world (w : world) : shape list =
  match w.picture with
  | None -> []
  | Some i ->
      let k = world_scale i in
      let pw = Scheme_image.width i *. k and ph = Scheme_image.height i *. k in
      let x = 500. -. (pw /. 2.) and y = 520. -. (ph /. 2.) in
      [ box black (x -. 6.) (y -. 36.) (pw +. 12.) (ph +. 42.); box title_blue (x -. 4.) (y -. 34.) (pw +. 8.) 30. ]
      @ [ caption white (x +. (pw /. 2.)) (y -. 19.) 15. "big-bang  (Esc closes)" ]
      @ [ box white x y pw ph; Bigbang.to_shape (picture i) |> scale k |> at 500. 520. ]

(*****************************************************************************)
(* The stepper *)
(*****************************************************************************)

let open_stepper (m : model) : model =
  match m.level with
  | Standard -> add (Failure "Step: the stepper knows Beginning Student only (click Language)") m
  | Beginning ->
      let steps, error = Scheme_step.steps ~max:1000 (Text_edit.to_string m.defs) in
      { m with stepper = Some { steps = Array.of_list steps; error; shown = 0 } }

(* the stepper's window, and its buttons *)
let sx = 40.
let sy = 110.
let sw = 920.
let sh = 780.
let prev_button = (sx +. 20., sy +. sh -. 60., 150., 40.)
let next_button = (sx +. sw -. 170., sy +. sh -. 60., 150., 40.)

let update_stepper (computer : computer) (keys : string list) (m : model) (s : stepper) : model =
  let last = Array.length s.steps in
  let click b = computer.mouse.mclick && inside (mouse_at computer) b in
  let s = if List.mem "ArrowRight" keys || click next_button then { s with shown = min last (s.shown + 1) } else s in
  let s = if List.mem "ArrowLeft" keys || click prev_button then { s with shown = max 0 (s.shown - 1) } else s in
  if List.mem "Escape" keys then { m with stepper = None } else { m with stepper = Some s }

let view_stepper (s : stepper) : shape list =
  let pane_w = (sw -. 60.) /. 2. in
  let pcols = int_of_float ((pane_w -. 16.) /. cw) in
  (* the text broken into lines of [pcols], a character's offset kept *)
  let pane x (text : string) (mark : int * int) (shade : color) : shape list =
    let a, b = mark in
    let rows = List.init ((String.length text + pcols - 1) / max 1 pcols) (fun r -> (r * pcols, String.sub text (r * pcols) (min pcols (String.length text - (r * pcols))))) in
    [ box white x (sy +. 70.) pane_w (sh -. 150.) ]
    @ frame (rgb 160 160 150) x (sy +. 70.) pane_w (sh -. 150.)
    @ List.concat
        (List.mapi
           (fun r (start, l) ->
             let ly = sy +. 80. +. (float_of_int r *. lh) in
             let lo = max a start and hi = min b (start + String.length l) in
             (if lo < hi then [ box shade (x +. 8. +. (float_of_int (lo - start) *. cw)) ly (float_of_int (hi - lo) *. cw) lh ] else [])
             @ label black (x +. 8.) ly l)
           rows)
  in
  let n = Array.length s.steps in
  let body =
    if s.shown < n then
      let st = s.steps.(s.shown) in
      pane (sx +. 20.) st.before st.redex (rgb 193 255 193) @ pane (sx +. 40. +. pane_w) st.after st.contractum (rgb 225 200 255)
      @ [ caption dark (sx +. 20. +. (pane_w /. 2.)) (sy +. 55.) 15. "before"; caption dark (sx +. 40. +. (pane_w *. 1.5)) (sy +. 55.) 15. "after" ]
    else
      let msg = match s.error with Some e -> e | None -> "All of the definitions have been successfully evaluated." in
      [ box white (sx +. 20.) (sy +. 70.) (sw -. 40.) (sh -. 150.) ] @ label (if s.error = None then black else error_color) (sx +. 30.) (sy +. 90.) msg
  in
  [ box (rgb 80 80 80) (sx -. 3.) (sy -. 3.) (sw +. 6.) (sh +. 6.); box chrome sx sy sw sh; box title_blue sx sy sw 34. ]
  @ [ caption white (sx +. (sw /. 2.)) (sy +. 17.) 16. "Stepper  (Esc closes)" ]
  @ body
  @ button prev_button [ polygon black [ (6., 8.); (6., -8.); (-8., 0.) ] ] "Step" (s.shown > 0)
  @ button next_button [ polygon black [ (-6., 8.); (-6., -8.); (8., 0.) ] ] "Step" (s.shown < n)
  @ [ caption dark (sx +. (sw /. 2.)) (sy +. sh -. 40.) 15. (Printf.sprintf "step %d of %d" (min (s.shown + 1) n) n) ]
