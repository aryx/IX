(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibExecutable.mli *)

module M = TinyLibMachine

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* does s start with m *)
let starts s m = String.length s >= String.length m
                 && String.sub s 0 (String.length m) = m

(* (Marshal's bytes after it: tiny-ml's Marshal stops the program on
 * bytes it cannot read, so another file is said not an object first.
 * 3: an object is lines, the assembly's type; an older object is
 * refused, not misread) *)
let magic = "tiny-object 3\n"

(* A marshalled value's bytes, the same whichever Marshal wrote them.
 * OCaml 5's sets two bits, a block's colour for its collector, in the
 * header of a block of 8 fields or more, or of a tag of 16 or more;
 * OCaml 4's and tiny-ml's leave them clear, and a reader ignores them.
 * But a file's bytes must not say which OCaml compiled the tool that
 * wrote it: the library the host makes is compared with the one
 * tiny-ml makes on the machine. So the two bits are cleared, in each
 * such header, found by reading the value's codes (Marshal's 20 bytes
 * of header first; no float, no closure). [coloured] asks the Marshal
 * at hand, with an array of 8: tiny-ml's and OCaml 4's have nothing to
 * clear, and their bytes are not read. *)
let coloured () =
  let probe = Marshal.to_string (Array.make 8 0) [ Marshal.No_sharing ] in
  Char.code probe.[23] land 3 <> 0

let plain (s : string) : string =
  if not (coloured ()) then s
  else begin
    let b = Bytes.of_string s in
    let byte k = Char.code s.[k] in
    let i = ref 20 and values = ref 1 in
    while !values > 0 do
      let c = byte !i in
      incr i;
      decr values;
      if c >= 0x80 then values := !values + ((c lsr 4) land 7)
      else if c >= 0x40 then ()
      else if c >= 0x20 then i := !i + c - 0x20
      else if c <= 0x03 then i := !i + (1 lsl c)
      else if c <= 0x06 then i := !i + (1 lsl (c - 4))
      else if c = 0x08 then begin
        Bytes.set b (!i + 2) (Char.chr (byte (!i + 2) land 0xfc));
        values :=
          !values + (byte !i lsl 14) + (byte (!i + 1) lsl 6)
          + (byte (!i + 2) lsr 2);
        i := !i + 4
      end
      else if c = 0x09 then i := !i + 1 + byte !i
      else if c = 0x0A then
        i := !i + 4 + (byte !i lsl 24) + (byte (!i + 1) lsl 16)
             + (byte (!i + 2) lsl 8) + byte (!i + 3)
      else M.error "a marshalled value with a float or a closure"
    done;
    Bytes.to_string b
  end

let to_object (lines : M.line list) =
  magic ^ plain (Marshal.to_string lines [ Marshal.No_sharing ])
let of_object (s : string) : M.line list =
  if not (starts s magic) then
    M.error "not an object of this tiny-as's (tiny-object 3): rebuild it";
  Marshal.from_string s (String.length magic)

(* an archive: its magic line, then each member's name and size on a
 * line, then its bytes, as Unix's ar's header before each member (its
 * 60 bytes, a name, a date, an owner, a mode and a size, the name and
 * the size here) *)
let archive_magic = "tiny-archive 1\n"
let is_archive (s : string) = starts s archive_magic
let to_archive (members : (string * string) list) : string =
  archive_magic
  ^ String.concat ""
      (List.map (fun (name, o) ->
         if not (starts o magic) then M.error (name ^ ": not an object");
         if String.contains name ' ' || String.contains name '\n' then
           M.error (name ^ ": a member's name has no blank");
         name ^ " " ^ string_of_int (String.length o) ^ "\n" ^ o)
         members)
let of_archive (s : string) : (string * string) list =
  if not (is_archive s) then M.error "not an archive";
  let rec from i =
    if i >= String.length s then []
    else
      let nl =
        match String.index_from_opt s i '\n' with
        | Some nl -> nl
        | None -> M.error "a damaged archive" in
      match String.split_on_char ' ' (String.sub s i (nl - i)) with
      | [ name; size ] ->
          let n =
            match int_of_string_opt size with
            | Some n when n >= 0 && nl + 1 + n <= String.length s -> n
            | _ -> M.error "a damaged archive" in
          (name, String.sub s (nl + 1) n) :: from (nl + 1 + n)
      | _ -> M.error "a damaged archive" in
  from (String.length archive_magic)

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

type label = string
type address = int
type symbols = (label * address) array

(* a dot, an L, digits *)
let local name =
  match String.rindex_opt name '.' with
  | Some i when i + 2 < String.length name && name.[i + 1] = 'L' ->
      String.for_all (fun c -> c >= '0' && c <= '9')
        (String.sub name (i + 2) (String.length name - i - 2))
  | _ -> false

(* <unit>.f<number>_<name> *)
let clean name =
  let n = String.length name in
  let digit c = c >= '0' && c <= '9' in
  let rec find i =
    if i + 2 >= n then None
    else if name.[i] = '.' && name.[i + 1] = 'f' && digit name.[i + 2] then
      Some i
    else find (i + 1) in
  match find 0 with
  | Some i ->
      let rec skip j = if j < n && digit name.[j] then skip (j + 1) else j in
      let j = skip (i + 2) in
      if j < n && name.[j] = '_' then
        (let short = String.sub name (j + 1) (n - j - 1) in
         if short = "fun" then name else short)
      else name
  | None -> name

let labels text =
  let l =
    text
    |> String.split_on_char '\n'
    |> List.filter_map (fun line ->
      match String.split_on_char ' ' line with
      | [ a; l ] when not (local l) ->
          (match int_of_string_opt ("0x" ^ a) with
           | Some a -> Some (l, a)
           | None -> None)
      | _ -> None) in
  l |> List.sort (fun (_, a) (_, b) -> compare a b) |> Array.of_list

(* by halves *)
let find funcs pc =
  let rec go lo hi =
    if hi - lo <= 1 then lo
    else
      let mid = (lo + hi) / 2 in
      if snd funcs.(mid) <= pc then go mid hi else go lo mid in
  if Array.length funcs = 0 || pc < snd funcs.(0) then None
  else
    let name, a = funcs.(go 0 (Array.length funcs)) in
    Some (clean name, a)

let address funcs name =
  let rec go i =
    if i >= Array.length funcs then None
    else
      let l, a = funcs.(i) in
      if l = name || clean l = name then Some a else go (i + 1) in
  go 0

(*****************************************************************************)
(* The manifests *)
(*****************************************************************************)

type taken = Command_line | Archive_member of string
type ppath = Ppath of string
type linked = {
  l_object : string;
  l_source : ppath option;
  l_taken : taken;
}
type manifest = { m_program : string; m_units : linked list }

let manifest (program : string) (objects : (string * taken) list)
    (source : string -> taken -> string option) : manifest =
  { m_program = program;
    m_units =
      List.map (fun (o, t) ->
        { l_object = o;
          l_source = (match source o t with Some s -> Some (Ppath s) | None -> None);
          l_taken = t })
        objects }

(* (as an object's: 2, its format's version: a source a ppath since 2) *)
let manifest_magic = "tiny-manifest 2\n"
let to_manifest (m : manifest) =
  manifest_magic ^ plain (Marshal.to_string m [ Marshal.No_sharing ])
