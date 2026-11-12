(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tokens.mli *)

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

type token =
  | Text of string
  | Open of string * (string * string) list
  | Close of string

(* The attributes the browser uses. The others (like Parsoid's large
 * data-mw, or ids) are skipped without being copied. *)
let wanted =
  [ "href"; "class"; "style"; "src"; "alt"; "width"; "height"; "colspan";
    "start"; "id"; "http-equiv"; "content" ]

(* s is the text between a tag's < and its >. *)
let tag s =
  let n = String.length s in
  let rec word i =
    if i < n && not (Strings.is_space s.[i]) && s.[i] <> '/' && s.[i] <> '='
       && s.[i] <> '>' then word (i + 1)
    else i in
  let rec skip i =
    if i < n && (Strings.is_space s.[i] || s.[i] = '/') then skip (i + 1) else i in
  if n > 0 && s.[0] = '/' then
    let e = word 1 in Close (String.lowercase_ascii (String.sub s 1 (e - 1)))
  else begin
    let e = word 0 in
    let name = String.lowercase_ascii (String.sub s 0 e) in
    let rec attrs i acc =
      let i = skip i in
      if i >= n then List.rev acc
      else begin
        let e = word i in
        let a = String.lowercase_ascii (String.sub s i (e - i)) in
        let rec sp j = if j < n && Strings.is_space s.[j] then sp (j + 1) else j in
        let j = sp e in
        if j < n && s.[j] = '=' then begin
          let j = sp (j + 1) in
          let q = if j < n then s.[j] else ' ' in
          let v0, v1, next =
            if q = '"' || q = '\'' then
              (match String.index_from_opt s (j + 1) q with
               | Some k -> j + 1, k, k + 1
               | None -> j + 1, n, n)
            else
              let rec un k =
                if k < n && not (Strings.is_space s.[k]) then un (k + 1) else k in
              let k = un j in
              j, k, k in
          if List.mem a wanted then
            attrs next ((a, Charset.ascii (String.sub s v0 (v1 - v0))) :: acc)
          else attrs next acc
        end
        else
          attrs (if e = i then i + 1 else e)
            (if List.mem a wanted then (a, "") :: acc else acc)
      end in
    Open (name, attrs e [])
  end

type reader = { mutable tail : string; mutable raw : string }

(* Finds the > that ends a tag, starting just after its <. A > inside
 * quotes does not count. None if the tag is not complete yet. *)
let tag_end s i : int option =
  let n = String.length s in
  let rec go j q =
    if j >= n then None
    else
      let c = s.[j] in
      if q <> ' ' then go (j + 1) (if c = q then ' ' else q)
      else if c = '>' then Some j
      else if c = '"' || c = '\'' then go (j + 1) c
      else go (j + 1) ' ' in
  go i ' '

(* [last] is true when no message follows, so nothing is kept. *)
let scan (r : reader) chunk last =
  let s = if r.tail = "" then chunk else r.tail ^ chunk in
  let n = String.length s in
  r.tail <- "";
  let keep i = if not last then r.tail <- String.sub s i (n - i) in
  let rec go i acc =
    if i >= n then acc
    else if r.raw <> "" then begin
      match Strings.find s ("</" ^ r.raw) i with
      | None -> keep (max i (n - 10)); acc
      | Some j ->
        (match String.index_from_opt s j '>' with
         | Some k ->
           let name = r.raw in r.raw <- ""; go (k + 1) (Close name :: acc)
         | None -> keep j; acc)
    end
    else if s.[i] = '<' then begin
      if i + 3 < n && s.[i + 1] = '!' && s.[i + 2] = '-' && s.[i + 3] = '-'
      then begin
        match Strings.find s "-->" (i + 4) with
        | None -> keep i; acc
        | Some j -> go (j + 3) acc
      end
      else begin
        match tag_end s (i + 1) with
        | None -> keep i; acc
        | Some k when i + 1 < n && (s.[i + 1] = '!' || s.[i + 1] = '?') ->
          go (k + 1) acc
        | Some k ->
          let t = tag (String.sub s (i + 1) (k - i - 1)) in
          (match t with
           | Open (name, _) when name = "style" || name = "script" ->
             r.raw <- name
           | _ -> ());
          go (k + 1) (t :: acc)
      end
    end
    else begin
      let j =
        match String.index_from_opt s i '<' with Some j -> j | None -> n in
      let e = if j = n && not last then Charset.safe_end s i n else j in
      if e < j then keep e;
      let acc =
        if e > i then Text (Charset.ascii (String.sub s i (e - i))) :: acc else acc in
      if e < j then acc else go j acc
    end in
  List.rev (go 0 [])

let tokens r chunk = scan r chunk false
let tokens_end r = scan r "" true
