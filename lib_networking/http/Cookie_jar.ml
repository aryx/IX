(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: copied from libs/network/unix/Cookie_jar.ml in the author's
 * mini-chrome (docs/plans/plan_browser.md). It has no lock, because
 * there are no threads, and create's cookies must be given. *)

(* See Cookie_jar.mli *)

type t = { mutable jar : Cookie.jar; mutable changes : int; now : unit -> float }

let create ~(now : unit -> float) (cookies : Cookie.jar) : t =
  { jar = cookies; changes = 0; now }

let cookies (t : t) : Cookie.jar = Cookie.alive ~now:(t.now ()) t.jar
let header (t : t) (url : Url.t) : string option = Cookie.header ~now:(t.now ()) ~script:false url t.jar

(* the jar after [f], counted if it is another *)
let write (t : t) (f : Cookie.jar -> Cookie.jar) : unit =
  let jar = f t.jar in
  if jar <> t.jar then begin
    t.jar <- jar;
    t.changes <- t.changes + 1
  end

let received (t : t) (url : Url.t) (headers : Http.header list) : unit =
  match Http.values "Set-Cookie" headers with
  | [] -> ()
  | values -> write t (fun jar -> List.fold_left (fun jar v -> Cookie.store ~now:(t.now ()) ~script:false url v jar) jar values)

let script_cookies (t : t) (url : Url.t) : string = match Cookie.header ~now:(t.now ()) ~script:true url t.jar with Some h -> h | None -> ""

let set_from_script (t : t) (url : Url.t) (value : string) : unit = write t (Cookie.store ~now:(t.now ()) ~script:true url value)
let changes (t : t) : int = t.changes
let clear (t : t) : unit = write t (fun _ -> [])
