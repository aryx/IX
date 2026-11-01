(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_printf.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types
open Il_functions

type piece =
  | Text of string
  | Conv of string * char       (* its spec, %-5d, and its letter *)
  | Flush                       (* %! *)

(* [format]: Format's, its @ directives text: @. and @\n a newline,
 * @  and @; a space, @@ an @, the boxes and the rest nothing (no
 * pretty-printing: a string is made) *)
let parse (loc : int) (format : bool) (f : string) : piece list =
  let n = String.length f in
  let b = Buffer.create 16 and out = ref [] in
  let text () = if Buffer.length b > 0 then (out := Text (Buffer.contents b) :: !out; Buffer.clear b) in
  let i = ref 0 in
  (* (a directive's <...>, skipped) *)
  let skip_angle () = if !i < n && f.[!i] = '<' then (while !i < n && f.[!i] <> '>' do incr i done; incr i) in
  while !i < n do
    if format && f.[!i] = '@' && !i + 1 < n then begin
      let ch = f.[!i + 1] in
      i := !i + 2;
      match ch with
      | '@' -> Buffer.add_char b '@'
      | '.' | '\n' -> Buffer.add_char b '\n'
      | ' ' -> Buffer.add_char b ' '
      | ';' -> Buffer.add_char b ' '; skip_angle ()
      | '[' -> skip_angle ()
      | '{' -> skip_angle ()
      | _ -> ()
    end
    else if f.[!i] <> '%' then (Buffer.add_char b f.[!i]; incr i)
    else if !i + 1 < n && f.[!i + 1] = '%' then (Buffer.add_char b '%'; i := !i + 2)
    else if !i + 1 < n && f.[!i + 1] = '!' then (text (); out := Flush :: !out; i := !i + 2)
    else begin
      let j = ref (!i + 1) in
      while !j < n && String.contains "-0+ #.123456789" f.[!j] do incr j done;
      while !j < n && (f.[!j] = 'l' || f.[!j] = 'L' || f.[!j] = 'n') do incr j done;
      if !j >= n then refuse loc "a format ending in %" "3c";
      text ();
      out := Conv (String.sub f !i (!j - !i + 1), f.[!j]) :: !out;
      i := !j + 1
    end
  done;
  text ();
  List.rev !out

let printers =
  [ "Printf.printf"; "Printf.eprintf"; "Printf.sprintf"; "Printf.fprintf"; "Printf.bprintf"; "Printf.ksprintf";
    "Format.asprintf"; "Format.sprintf" ]

(* the arguments before the format: fprintf's channel, bprintf's
 * buffer, ksprintf's continuation *)
let before (sym : string) : int = match sym with "Printf.fprintf" | "Printf.bprintf" | "Printf.ksprintf" -> 1 | _ -> 0

let applies (sym : string) (args : Scope.expr list) : bool =
  List.mem sym printers
  && (match List.nth_opt args (before sym) with Some { e = Econst (String _); _ } -> true | _ -> false)

let call (env : env) (k : code) (sym : string) =
  match Hashtbl.find_opt env.by_sym sym with
  | Some f -> emit k (Il.Call f.tok)
  | None -> refuse 0 (sym ^ ", a printf's, its unit not compiled") "3c"

let compile (c : c) (env : env) (k : code) (expr : Scope.expr -> unit) (e : Scope.expr) (sym : string) (args : Scope.expr list) : unit =
  let pre = before sym in
  let fmt = match List.nth args pre with { e = Econst (String s); _ } -> s | _ -> "" in
  let pieces = parse e.loc (String.length sym > 7 && String.sub sym 0 7 = "Format.") fmt in
  let convs = List.filter (fun (p : piece) -> match p with Conv _ -> true | _ -> false) pieces in
  let rest = List.filteri (fun (i : int) (_ : Scope.expr) -> i > pre) args in
  if List.length rest <> List.length convs then
    refuse e.loc (sym ^ " given fewer or more arguments than its format's conversions") "3c";
  (* (the channel, buffer or continuation, then the arguments: in locals,
   * in order) *)
  let into (a : Scope.expr) : int option =
    let t = cts_of c a in
    expr a;
    if t = S.Void then None else (let v = local k t in emit k (Il.Stloc v); Some v) in
  let target = if pre = 1 then into (List.hd args) else None in
  let values = List.map (fun (a : Scope.expr) -> (a, into a)) rest in
  let load (v : int option) = match v with Some v -> emit k (Il.Ldloc v) | None -> () in
  (* the string, piece by piece *)
  let first = ref true in
  let joined () =
    if !first then first := false
    else emit k (Il.Call (lib c "String" "Concat" (static [ S.String; S.String ] S.String))) in
  let values = ref values in
  List.iter
    (fun (p : piece) ->
      match p with
      | Text s -> emit k (Il.Ldstr (W.user_string c.w s)); joined ()
      | Flush -> ()
      | Conv (spec, ch) ->
          let a, v = match !values with x :: r -> values := r; x | [] -> assert false in
          let t = cts_of c a in
          let arg (into_t : S.t) = load v; Il_externals.convert c k t into_t in
          let runtime (name : string) (into_t : S.t) =
            emit k (Il.Ldstr (W.user_string c.w spec)); arg into_t; call env k ("Runtime." ^ name) in
          (match ch with
           | 'd' | 'i' | 'u' | 'x' | 'X' | 'o' -> runtime "format_int" S.I8
           | 'f' | 'e' | 'E' | 'g' | 'G' -> runtime "format_float" S.R8
           | 's' when spec = "%s" -> load v
           | 's' -> runtime "format_string" S.String
           | 'c' -> runtime "format_char" S.I4
           | 'b' | 'B' -> runtime "format_bool" S.Bool
           | ch -> refuse a.loc (Printf.sprintf "%%%c in a format compiled (a printer, %%a or %%t: the library's Printf)" ch) "3c");
          joined ())
    pieces;
  if !first then emit k (Il.Ldstr (W.user_string c.w ""));
  let flushes = List.exists (fun (p : piece) -> p = Flush) pieces in
  let channel (name : string) =
    match Hashtbl.find_opt env.fields name with
    | Some (f, _) -> emit k (Il.Ldsfld f)
    | None -> refuse e.loc (name ^ ", its unit not compiled") "3c" in
  match sym with
  | "Printf.sprintf" | "Format.asprintf" | "Format.sprintf" -> ()
  | "Printf.printf" ->
      call env k "Pervasives.print_string";
      if flushes then (channel "Pervasives.stdout"; call env k "Runtime.caml_flush")
  | "Printf.eprintf" ->
      call env k "Pervasives.prerr_string";
      if flushes then (channel "Pervasives.stderr"; call env k "Runtime.caml_flush")
  | "Printf.fprintf" | "Printf.bprintf" ->
      let s = local k S.String in
      emit k (Il.Stloc s);
      load target;
      emit k (Il.Ldloc s);
      call env k (if sym = "Printf.fprintf" then "Pervasives.output_string" else "Buffer.add_string");
      if flushes && sym = "Printf.fprintf" then (load target; call env k "Runtime.caml_flush")
  | _ ->
      (* ksprintf: k's Invoke of the string, its result the call's *)
      let s = local k S.String in
      emit k (Il.Stloc s);
      load target;
      emit k (Il.Ldloc s);
      let kt = cts_of c (List.hd args) in
      emit k (Il.Callvirt (invoke c kt));
      if cts_of c e = S.Void then emit k Il.Pop
