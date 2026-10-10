(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/library/Js_promise.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_promise.mli *)
open Js_value

type settled = Fulfilled of value | Rejected of value

type t = {
  jobs : (unit -> unit) Queue.t;
  call : value -> this:value -> value list -> value;
  get : value -> string -> value;
  report : value -> unit;
  proto : obj; (* Promise.prototype *)
  (* the promises rejected with nobody listening: each its value, and
   * whether somebody came since *)
  mutable unhandled : (value * bool ref) list;
}

let arg (args : value list) (i : int) : value = (match (List.nth_opt args i) with Some v_ -> v_ | None -> Undefined)
let fn = host_function
let callable (v : value) : bool = match v with Object { kind = Closure _ | Host_function _; _ } -> true | _ -> false

(* where a promise keeps its state: a hidden property, a function that
 * takes who listens. Not a kind of object (Js_value): a promise is a
 * plain object but for it *)
let hidden = "@@promise"

(* a thenable's then, if it has one *)
let then_of (t : t) (v : value) : value option =
  match v with Object _ -> ( match t.get v "then" with f when callable f -> Some f | _ -> None) | _ -> None

(* [f] the first time it is called, nothing after: resolve and reject
 * of a same promise share one *)
let first () : (value -> unit) -> value -> unit =
  let called = ref false in
  fun f v -> if not !called then (called := true; f v)

(*****************************************************************************)
(* A promise *)
(*****************************************************************************)

(* [o] made a promise (a new object by default): its state in the
 * closures of its listener, resolve and reject *)
let make_on (t : t) (o : obj) : value * (value -> unit) * (value -> unit) =
  let state : (settled, (settled -> unit) list) Either.t ref = ref (Either.Right []) in
  let handled = ref false in
  let settle (s : settled) : unit =
    match !state with
    | Right listeners ->
        state := Left s;
        List.iter (fun l -> Queue.add (fun () -> l s) t.jobs) (List.rev listeners);
        (match s with Rejected e when listeners = [] -> t.unhandled <- (e, handled) :: t.unhandled | _ -> ())
    | Left _ -> ()
  in
  let listen (l : settled -> unit) : unit =
    handled := true;
    match !state with Right listeners -> state := Right (l :: listeners) | Left s -> Queue.add (fun () -> l s) t.jobs
  in
  (* the listener as a value: its two arguments are host functions *)
  let listener ~this:_ args =
    let tell f v = match f with Object { kind = Host_function (_, (f : this:value -> value list -> value)); _ } -> ignore (f ~this:Undefined [ v ]) | _ -> () in
    listen (fun s -> match s with Fulfilled v -> tell (arg args 0) v | Rejected e -> tell (arg args 1) e);
    Undefined
  in
  set_own o hidden (fn "promise" listener);
  let reject e = settle (Rejected e) in
  (* a thenable is followed: its then called, in a job, with this
   * promise's own resolve and reject *)
  let rec resolve (v : value) : unit =
    if (match v with Object o' -> o' == o | _ -> false) then reject (error "TypeError" "Chaining cycle detected for promise")
    else
      match (try Ok (then_of t v) with Throw e -> Error e) with
      | Error e -> reject e
      | Ok None -> settle (Fulfilled v)
      | Ok (Some th) ->
          Queue.add
            (fun () ->
              let once = first () in
              try ignore (t.call th ~this:v [ fn "resolve" (fun ~this:_ a -> once resolve (arg a 0); Undefined); fn "reject" (fun ~this:_ a -> once reject (arg a 0); Undefined) ])
              with Throw e -> once reject e)
            t.jobs
  in
  let once = first () in
  (Object o, once resolve, once reject)

let make (t : t) : value * (value -> unit) * (value -> unit) = make_on t { (new_object ()) with proto = Some t.proto }

let is_promise (v : value) : bool = match v with Object o -> get_own o hidden <> None | _ -> false

(* Promise.resolve(v): v if it is a promise, else one of it *)
let of_value (t : t) (v : value) : value =
  if is_promise v then v else let p, resolve, _ = make t in resolve v; p

(* [on_ok] or [on_error] called, in a job, when [v] is settled *)
let listen (t : t) (v : value) ~(on_ok : value -> unit) ~(on_error : value -> unit) : unit =
  match of_value t v with
  | Object o ->
      let f g = fn "listener" (fun ~this:_ a -> g (arg a 0); Undefined) in
      ignore (t.call (Option.get (get_own o hidden)) ~this:Undefined [ f on_ok; f on_error ])
  | _ -> ()

(* p.then(f, g): a promise of what f gives of p's value, or g of its
 * rejection; with no f, or no g, of p's own *)
let then_ (t : t) (p : value) (f : value) (g : value) : value =
  if not (is_promise p) then throw "TypeError" "Promise.prototype.then called on a value that is not a promise";
  let next, resolve, reject = make t in
  let through h v = match t.call h ~this:Undefined [ v ] with r -> resolve r | exception Throw e -> reject e in
  listen t p
    ~on_ok:(fun v -> if callable f then through f v else resolve v)
    ~on_error:(fun e -> if callable g then through g e else reject e);
  next

let drain_each (each : unit -> unit) (t : t) : unit =
  while not (Queue.is_empty t.jobs) do
    try each (); (Queue.pop t.jobs) () with
    | Throw e -> t.report e
    | (Stack_overflow | Invalid_argument _ | Failure _ | Not_found | Division_by_zero) as e -> t.report (error "InternalError" (Printexc.to_string e))
  done;
  let left = List.rev t.unhandled in
  t.unhandled <- [];
  List.iter (fun (e, handled) -> if not !handled then t.report e) left

let drain (t : t) : unit = drain_each ignore t

(*****************************************************************************)
(* async, await *)
(*****************************************************************************)

let async (t : t) (body : unit -> value) : value =
  let p, resolve, reject = make t in
  let run () =
    match body () with
    | v -> resolve v
    | exception Throw e -> reject e
    | exception Stack_overflow -> reject (error "RangeError" "Maximum call stack size exceeded")
    | exception e -> reject (error "InternalError" (Printexc.to_string e))
  in
  Js_coroutine.resume (Js_coroutine.create run);
  p

let await (t : t) (v : value) : value =
  match Js_coroutine.current () with
  | None -> throw "SyntaxError" "await is only valid in async functions"
  | Some co -> (
      let result = ref (Fulfilled Undefined) in
      (* the job that resumes the body: run by drain, in the thread of
       * the one who drains, which then waits for the body's next await *)
      let back s = result := s; Js_coroutine.resume co in
      listen t v ~on_ok:(fun x -> back (Fulfilled x)) ~on_error:(fun e -> back (Rejected e));
      Js_coroutine.suspend ();
      match !result with Fulfilled x -> x | Rejected e -> raise (Throw e))

(*****************************************************************************)
(* Promise *)
(*****************************************************************************)

(* all, allSettled, any: a promise of every item's answer, in the
 * items' order. [each] says what an item's outcome is: an answer
 * kept (Ok), or the end of the whole at once (Error); [whole], the
 * end when every answer is there *)
let combine (t : t) (xs : value list) ~(each : settled -> (value, settled) result) ~(whole : value list -> settled) : value =
  let p, resolve, reject = make t in
  let finish s = match s with Fulfilled v -> resolve v | Rejected e -> reject e in
  let kept = Array.make (List.length xs) Undefined and left = ref (List.length xs) in
  if xs = [] then finish (whole []);
  List.iteri
    (fun i x ->
      let got s =
        match each s with
        | Ok v -> kept.(i) <- v; decr left; if !left = 0 then finish (whole (Array.to_list kept))
        | Error s -> finish s
      in
      listen t x ~on_ok:(fun v -> got (Fulfilled v)) ~on_error:(fun e -> got (Rejected e)))
    xs;
  p

let install ~(call : value -> this:value -> value list -> value) ~get ~items ~report (define : string -> value -> unit) : t =
  let proto = new_object () in
  let t = { jobs = Queue.create (); call; get; report; proto; unhandled = [] } in
  let def o m f = set_own o m (fn m f) in
  let array vs = Object (new_array vs) in
  def proto "then" (fun ~this args -> then_ t this (arg args 0) (arg args 1));
  def proto "catch" (fun ~this args -> then_ t this Undefined (arg args 0));
  (* finally(f): f called either way; then, once what f gave is
   * settled, the promise's own outcome *)
  def proto "finally" (fun ~this args ->
      let after (outcome : value -> value) =
        fn "finally" (fun ~this:_ a ->
            let r = if callable (arg args 0) then call (arg args 0) ~this:Undefined [] else Undefined in
            then_ t (of_value t r) (fn "after" (fun ~this:_ _ -> outcome (arg a 0))) Undefined)
      in
      then_ t this (after (fun v -> v)) (after (fun e -> raise (Throw e))));
  (* new Promise((resolve, reject) => ...): the function called at once *)
  let promise =
    fn "Promise" (fun ~this args ->
        let o = match this with Object o -> o | _ -> throw "TypeError" "Promise constructor cannot be invoked without 'new'" in
        if not (callable (arg args 0)) then throw "TypeError" (Printf.sprintf "Promise resolver %s is not a function" (display (arg args 0)));
        let _, resolve, reject = make_on t o in
        let f name g = fn name (fun ~this:_ a -> g (arg a 0); Undefined) in
        (try ignore (call (arg args 0) ~this:Undefined [ f "resolve" resolve; f "reject" reject ]) with Throw e -> reject e);
        Undefined)
  in
  let c = match promise with Object c -> c | _ -> assert false in
  set_own c "prototype" (Object proto);
  set_own proto "constructor" promise;
  def c "resolve" (fun ~this:_ args -> of_value t (arg args 0));
  def c "reject" (fun ~this:_ args -> let p, _, reject = make t in reject (arg args 0); p);
  def c "all" (fun ~this:_ args ->
      combine t (items (arg args 0)) ~each:(fun s -> match s with Fulfilled v -> Ok v | r -> Error r) ~whole:(fun vs -> Fulfilled (array vs)));
  def c "allSettled" (fun ~this:_ args ->
      let record s =
        let o = new_object () in
        (match s with
        | Fulfilled v -> set_own o "status" (String "fulfilled"); set_own o "value" v
        | Rejected e -> set_own o "status" (String "rejected"); set_own o "reason" e);
        Ok (Object o)
      in
      combine t (items (arg args 0)) ~each:record ~whole:(fun vs -> Fulfilled (array vs)));
  (* the first fulfilled; all rejected: an AggregateError of their reasons *)
  def c "any" (fun ~this:_ args ->
      let all_failed es =
        let e = error "AggregateError" "All promises were rejected" in
        (match e with Object o -> set_own o "errors" (array es) | _ -> ());
        Rejected e
      in
      combine t (items (arg args 0)) ~each:(fun s -> match s with Fulfilled _ -> Error s | Rejected e -> Ok e) ~whole:all_failed);
  (* the first settled, either way *)
  def c "race" (fun ~this:_ args ->
      let p, resolve, reject = make t in
      List.iter (fun x -> listen t x ~on_ok:resolve ~on_error:reject) (items (arg args 0));
      p);
  define "Promise" promise;
  define "queueMicrotask" (fn "queueMicrotask" (fun ~this:_ args -> Queue.add (fun () -> ignore (call (arg args 0) ~this:Undefined [])) t.jobs; Undefined));
  t
