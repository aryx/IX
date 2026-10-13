(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ixdoc_syntax.mli *)

let is_letter (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
let is_digit (c : char) : bool = c >= '0' && c <= '9'
let is_alnum (c : char) : bool = is_letter c || is_digit c || Char.code c >= 128

let indent_of (s : string) : int =
  let n = String.length s in
  let rec go (i : int) : int = if i < n && s.[i] = ' ' then go (i + 1) else i in
  go 0

let blank (s : string) : bool = String.trim s = ""
let drop (s : string) (n : int) : string = if n >= String.length s then "" else String.sub s n (String.length s - n)
let ends_with (s : string) (c : char) : bool = s <> "" && s.[String.length s - 1] = c

(* ---------------------------------------------------------------- *)
(* A text's marks *)
(* ---------------------------------------------------------------- *)

(* s.[i] opens ([ or {): where it is closed, what is between two back
 * quotes and what follows a backslash not looked at *)
let closing (s : string) (i : int) (o : char) (c : char) : int option =
  let n = String.length s in
  let rec go (j : int) (depth : int) : int option =
    if j >= n then None
    else if s.[j] = '\\' then go (j + 2) depth
    else if s.[j] = '`' then (match String.index_from_opt s (j + 1) '`' with Some e -> go (e + 1) depth | None -> go (j + 1) depth)
    else if s.[j] = c then (if depth = 1 then Some j else go (j + 1) (depth - 1))
    else if s.[j] = o then go (j + 1) (depth + 1)
    else go (j + 1) depth in
  go (i + 1) 1

(* \name[options]{text}{text} at i: its name, its options, its texts,
 * and where it ends *)
let command_at (s : string) (i : int) : string * string * string list * int =
  let n = String.length s in
  let j = ref (i + 1) in
  while !j < n && is_letter s.[!j] do incr j done;
  let name = String.sub s (i + 1) (!j - i - 1) in
  let options =
    if !j < n && s.[!j] = '[' then
      (match closing s !j '[' ']' with Some e -> let o = String.sub s (!j + 1) (e - !j - 1) in j := e + 1; o | None -> "")
    else "" in
  let args = ref [] in
  let rec more () =
    if !j < n && s.[!j] = '{' then
      (match closing s !j '{' '}' with Some e -> args := String.sub s (!j + 1) (e - !j - 1) :: !args; j := e + 1; more () | None -> ()) in
  more ();
  (name, options, List.rev !args, !j)

(* where the * or the _ opened before [from] is closed: [k] of them,
 * after what is not a space; ** inside *...* is passed over *)
let find_close (s : string) (from : int) (c : char) (k : int) : int option =
  let n = String.length s in
  let rec go (j : int) : int option =
    if j >= n then None
    else if s.[j] = '\\' then go (j + 2)
    else if s.[j] = '`' then (match String.index_from_opt s (j + 1) '`' with Some e -> go (e + 1) | None -> go (j + 1))
    else if s.[j] = c then begin
      let run = ref 0 in
      while j + !run < n && s.[j + !run] = c do incr run done;
      let after = j + !run in
      let fits = j > from && s.[j - 1] <> ' ' && s.[j - 1] <> '\n' && (c = '*' || after >= n || not (is_alnum s.[after])) in
      if not fits then go after
      else if k = 1 then (if !run = 2 then go after else Some (after - 1))
      else if !run >= 2 then Some (after - 2)
      else go after
    end
    else go (j + 1) in
  go from

(* #1, #2 of a \newcommand's text *)
let substitute (body : string) (args : string list) : string =
  let b = Buffer.create 64 and n = String.length body in
  let rec go (i : int) =
    if i < n then
      if body.[i] = '#' && i + 1 < n && is_digit body.[i + 1] then begin
        (match List.nth_opt args (Char.code body.[i + 1] - 49) with Some a -> Buffer.add_string b a | None -> ());
        go (i + 2)
      end
      else begin Buffer.add_char b body.[i]; go (i + 1) end in
  go 0; Buffer.contents b

let block_commands = [ "title"; "author"; "newcommand"; "include"; "figure"; "space"; "keep"; "center"; "indent"; "footnote" ]

(* ---------------------------------------------------------------- *)
(* The lines *)
(* ---------------------------------------------------------------- *)

type kind =
  | Blank
  (* set in by four columns or more *)
  | Code
  (* ``` and the word after it *)
  | Fence of string * string
  | Head of int * string
  | Row
  | Quote
  (* its mark (- or 1.), and the column of its text *)
  | Item of string * int
  (* a line that starts with a colon, and the column of its text *)
  | Define of int
  | Command of string
  | Html
  | Words

let classify (raw : string) : kind =
  let ind = indent_of raw in
  let s = drop raw ind in
  let n = String.length s in
  if n = 0 then Blank
  else if ind >= 4 then Code
  else if n >= 3 && String.sub s 0 3 = "```" then begin
    let k = ref 0 in
    while !k < n && s.[!k] = '`' do incr k done;
    Fence (String.sub s 0 !k, String.trim (drop s !k))
  end
  else if s.[0] = '#' then begin
    let k = ref 0 in
    while !k < n && s.[!k] = '#' do incr k done;
    if !k <= 6 && (!k = n || s.[!k] = ' ') then Head (!k, String.trim (drop s !k)) else Words
  end
  else if s.[0] = '|' then Row
  else if s.[0] = '>' then Quote
  else if s.[0] = ':' && (n = 1 || s.[1] = ' ') then Define (ind + (let r = drop s 1 in 1 + indent_of r))
  else if (s.[0] = '-' || s.[0] = '*' || s.[0] = '+') && (n = 1 || s.[1] = ' ') then Item ("\xe2\x80\xa2", ind + 1 + indent_of (drop s 1))
  else if is_digit s.[0] then begin
    let k = ref 0 in
    while !k < n && is_digit s.[!k] do incr k done;
    if !k < n && (s.[!k] = '.' || s.[!k] = ')') && (!k + 1 = n || s.[!k + 1] = ' ') then Item (String.sub s 0 (!k + 1), ind + !k + 1 + indent_of (drop s (!k + 1)))
    else Words
  end
  else if s.[0] = '\\' then begin
    let name, _, _, _ = command_at s 0 in
    if List.mem name block_commands then Command name else Words
  end
  else if s.[0] = '<' && n > 1 && (is_letter s.[1] || s.[1] = '/' || s.[1] = '!') && not (String.length s > 5 && String.sub s 1 4 = "http") then Html
  else Words
