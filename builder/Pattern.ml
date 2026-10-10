(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pattern.mli *)

type meta = [%mli]

type t = Literal of string | Meta of meta

type binding = Exact | Stem of string | Groups of string array

let split_at (s : string) (i : int) = String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1)

let of_target ~(regexp : bool) (s : string) : t =
  if regexp then Meta (Regexp (s, Regex.compile s))
  else
    match String.index_opt s '%', String.index_opt s '&' with
    | None, None -> Literal s
    | Some i, Some j when j < i -> let a, b = split_at s j in Meta (Amp (a, b))
    | Some i, _ -> let a, b = split_at s i in Meta (Percent (a, b))
    | None, Some j -> let a, b = split_at s j in Meta (Amp (a, b))

let is_meta (p : t) : bool = match p with Literal _ -> false | Meta _ -> true

let affix (a : string) (b : string) (name : string) : string option =
  let n = String.length name and na = String.length a and nb = String.length b in
  if na + nb <= n && String.sub name 0 na = a && String.sub name (n - nb) nb = b
  then Some (String.sub name na (n - na - nb))
  else None

let matches (m : meta) (name : string) : binding option =
  match m with
  | Percent (a, b) -> Option.map (fun stem -> Stem stem) (affix a b name)
  | Amp (a, b) -> (
      match affix a b name with
      | Some stem when not (String.contains stem '/' || String.contains stem '.') -> Some (Stem stem)
      | _ -> None)
  | Regexp (_, re) -> (
      (* the whole name: the leftmost-longest match is it, if any is *)
      match Regex.exec re name 0 with
      | Some spans when spans.(0) = (0, String.length name) ->
          (* \0 to the last group that matched (Regex always answers 8) *)
          let n = ref (Array.length spans) in
          while !n > 1 && fst spans.(!n - 1) < 0 do decr n done;
          Some (Groups (Array.init !n (fun i -> let a, b = spans.(i) in if a < 0 then "" else String.sub name a (b - a))))
      | _ -> None)

let subst (b : binding) (s : string) : string =
  match b with
  | Exact -> s
  | Stem stem ->
      (* every % and & of a prerequisite is the stem (match.c's subst) *)
      String.concat stem (List.map (fun piece -> String.concat stem (String.split_on_char '&' piece)) (String.split_on_char '%' s))
  | Groups groups ->
      (* \n refers to group n, as in Plan 9's regsub *)
      let buf = Buffer.create (String.length s) in
      let n = String.length s in
      let rec go i =
        if i < n then
          if s.[i] = '\\' && i + 1 < n && s.[i + 1] >= '0' && s.[i + 1] <= '9' then begin
            let g = Char.code s.[i + 1] - Char.code '0' in
            if g < Array.length groups then Buffer.add_string buf groups.(g);
            go (i + 2)
          end else (Buffer.add_char buf s.[i]; go (i + 1))
      in
      go 0;
      Buffer.contents buf
