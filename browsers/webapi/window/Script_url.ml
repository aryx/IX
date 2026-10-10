(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Script_url.mli *)
open Js_value
open Script_types
open Script_host

let fn (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

(* new URLSearchParams(init): [o], the object new made, given its
 * fields and its methods *)
let make (t : t) (o : obj) (init : value) : unit =
  let fields : (string * string) list ref = ref [] in
  let property v k = Js_eval.get t.engine v k in
  (fields :=
     match init with
     | Undefined | Null -> []
     | String s -> Urlencoded.decode (if String.starts_with ~prefix:"?" s then String.sub s 1 (String.length s - 1) else s)
     (* another one, or pairs: gone through; else an object's properties *)
     | Object _ when property init "@@iterator" <> Undefined ->
         List.map (fun pair -> (str (property pair "0"), str (property pair "1"))) (Js_eval.items t.engine init)
     | Object src -> List.map (fun k -> (k, str (property init k))) (keys src)
     | v -> Urlencoded.decode (str v));
  let set k f = set_own o k (fn k f) in
  let name args = str (arg args 0) in
  let pairs () = List.map (fun (k, v) -> Object (new_array [ String k; String v ])) !fields in
  set "get" (fun args -> match List.assoc_opt (name args) !fields with Some v -> String v | None -> Null);
  set "getAll" (fun args -> Object (new_array (List.filter_map (fun (k, v) -> if k = name args then Some (String v) else None) !fields)));
  set "has" (fun args -> Bool (List.mem_assoc (name args) !fields));
  set "append" (fun args -> fields := !fields @ [ (name args, str (arg args 1)) ]; Undefined);
  set "delete" (fun args -> fields := List.filter (fun (k, _) -> k <> name args) !fields; Undefined);
  (* the first of that name takes the value, the others go; none: added *)
  set "set" (fun args ->
      let k = name args and v = str (arg args 1) in
      let seen = ref false in
      fields := List.filter_map (fun (k', v') -> if k' <> k then Some (k', v') else if !seen then None else (seen := true; Some (k, v))) !fields;
      if not !seen then fields := !fields @ [ (k, v) ];
      Undefined);
  set "toString" (fun _ -> String (Urlencoded.encode !fields));
  set "forEach" (fun args -> List.iter (fun (k, v) -> Script_fetch.call t (arg args 0) ~this:Undefined [ String v; String k ]) !fields; Undefined);
  set "keys" (fun _ -> Js_builtins.iterator (List.map (fun (k, _) -> String k) !fields));
  set "values" (fun _ -> Js_builtins.iterator (List.map (fun (_, v) -> String v) !fields));
  set "entries" (fun _ -> Js_builtins.iterator (pairs ()));
  set "@@iterator" (fun _ -> Js_builtins.iterator (pairs ()))

let install (t : t) (define : string -> value -> unit) : unit =
  define "URLSearchParams"
    (host_function "URLSearchParams" (fun ~this args ->
         (match this with
         | Object o -> make t o (arg args 0)
         | _ -> throw "TypeError" "Failed to construct 'URLSearchParams': Please use the 'new' operator");
         Undefined))
