(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. GNU Library General Public License, with the linking exception of OCaml's LICENSE. *)

external format_int: string -> int -> string = "format_int"
external format_int32: string -> int32 -> string = "int32_format"
external format_int64: string -> int64 -> string = "int64_format"

let bad_format fmt pos =
  invalid_arg
    ("printf: bad format " ^ String.sub fmt pos (String.length fmt - pos))

(* Format a string given a %s format, e.g. %40s or %-20s.
   To do: ignore other flags (#, +, etc)? *)

let format_string format s =
  let rec parse_format neg i =
    if i >= String.length format then (0, neg) else
    match String.unsafe_get format i with
    | '1'..'9' ->
        (int_of_string (String.sub format i (String.length format - i - 1)),
         neg)
    | '-' ->
        parse_format true (succ i)
    | _ ->
        parse_format neg (succ i) in
  let (p, neg) =
    try parse_format false 1 with Failure _ -> bad_format format 0 in
  if String.length s < p then begin
    let res = Bytes.make p ' ' in
    if neg 
    then String.blit s 0 res 0 (String.length s)
    else String.blit s 0 res (p - String.length s) (String.length s);
    Bytes.unsafe_to_string res
  end else
    s

(* Extract a %format from [fmt] between [start] and [stop] inclusive.
   '*' in the format are replaced by integers taken from the [widths] list.
   The function is somewhat optimized for the "no *" case. *)

let extract_format fmt start stop widths =
  match widths with
  | [] -> String.sub fmt start (stop - start + 1)
  | _  ->
      let b = Buffer.create (stop - start + 10) in
      let rec fill_format i w =
        if i > stop then Buffer.contents b else
          match (String.unsafe_get fmt i, w) with
            ('*', h::t) ->
              Buffer.add_string b (string_of_int h); fill_format (succ i) t
          | ('*', []) ->
              bad_format fmt start (* should not happen *)
          | (c, _) ->
              Buffer.add_char b c; fill_format (succ i) w
      in fill_format start (List.rev widths)

(* Decode a %format and act on it.
   [fmt] is the printf format style, and [pos] points to a [%] character.  
   After consuming the appropriate number of arguments and formatting
   them, one of the three continuations is called:
   [cont_s] for outputting a string (args: string, next pos)
   [cont_a] for performing a %a action (args: fn, arg, next pos)
   [cont_t] for performing a %t action (args: fn, next pos)
   "next pos" is the position in [fmt] of the first character following
   the %format in [fmt]. *)

(* Note: here, rather than test explicitly against [String.length fmt]
   to detect the end of the format, we use [String.unsafe_get] and
   rely on the fact that we'll get a "nul" character if we access
   one past the end of the string.  These "nul" characters are then
   caught by the [_ -> bad_format] clauses below.
   Don't do this at home, kids. *) 

let scan_format fmt pos cont_s cont_a cont_t cont_f =
  let rec scan_flags widths i =
    match String.unsafe_get fmt i with
    | '*' ->
        Obj.magic(fun w -> scan_flags (w :: widths) (succ i))
    | '0'..'9' | '.' | '#' | '-' | ' ' | '+' -> scan_flags widths (succ i)
    | _ -> scan_conv widths i
  and scan_conv widths i =
    match String.unsafe_get fmt i with
    | '%' ->
        cont_s "%" (succ i)
    | 's' ->
        Obj.magic (fun (s: string) ->
          if i = succ pos (* optimize for common case %s *)
          then cont_s s (succ i)
          else cont_s (format_string (extract_format fmt pos i widths) s)
                      (succ i))
    | 'c' ->
        Obj.magic (fun (c: char) ->
          cont_s (String.make 1 c) (succ i))
    | 'd' | 'i' | 'o' | 'x' | 'X' | 'u' ->
        Obj.magic(fun (n: int) ->
          cont_s (format_int (extract_format fmt pos i widths) n) (succ i))
    | 'b' ->
        Obj.magic(fun (b: bool) ->
          cont_s (string_of_bool b) (succ i))
    | 'a' ->
        Obj.magic (fun printer arg ->
          cont_a printer arg (succ i))
    | 't' ->
        Obj.magic (fun printer ->
          cont_t printer (succ i))
    (* ix: %S and %C, OCaml's later ones: as the constant is written *)
    | 'S' ->
        Obj.magic (fun (s: string) ->
          cont_s ("\"" ^ String.escaped s ^ "\"") (succ i))
    | 'C' ->
        Obj.magic (fun (c: char) ->
          cont_s ("'" ^ Char.escaped c ^ "'") (succ i))
    | 'l' ->
        begin match String.unsafe_get fmt (succ i) with
        | 'd' | 'i' | 'o' | 'x' | 'X' | 'u' ->
            Obj.magic(fun (n: int32) ->
              cont_s (format_int32 (extract_format fmt pos (succ i) widths) n)
                     (i + 2))
        | _ ->
            bad_format fmt pos
        end
    | 'L' ->
        begin match String.unsafe_get fmt (succ i) with
        | 'd' | 'i' | 'o' | 'x' | 'X' | 'u' ->
            Obj.magic(fun (n: int64) ->
              cont_s (format_int64 (extract_format fmt pos (succ i) widths) n)
                     (i + 2))
        | _ ->
            bad_format fmt pos
        end
    | '!' ->
        Obj.magic (cont_f (succ i))
    | _ ->
        bad_format fmt pos
  in scan_flags [] (pos + 1)

(* ix: a format applied is its pieces kept, in their order, each to be
 * written on a destination ('d: a channel, a buffer); nothing is
 * written before the last argument is given, and nothing is kept
 * between two uses. So a format with some of its arguments is a
 * function as any other, as OCaml's: List.map (sprintf "R%d") gives
 * R4 then R5, where ocaml-light's wrote the R when the format was
 * applied, once, and 5 alone the second time. *)
let pieces fmt (literal : 'd -> string -> unit) (with_arg : 'd -> Obj.t -> Obj.t -> unit) (without : 'd -> Obj.t -> unit)
    (flushed : 'd -> unit) (finish : ('d -> unit) list -> Obj.t) =
  let fmt = (Obj.magic fmt : string) in
  let len = String.length fmt in
  let rec doprn acc i =
    if i >= len then Obj.magic (finish (List.rev acc))
    else match String.unsafe_get fmt i with
      | '%' ->
          scan_format fmt i
            (fun s i -> doprn ((fun d -> literal d s) :: acc) i)
            (fun printer arg i -> doprn ((fun d -> with_arg d (Obj.repr printer) (Obj.repr arg)) :: acc) i)
            (fun printer i -> doprn ((fun d -> without d (Obj.repr printer)) :: acc) i)
            (fun i -> doprn ((fun d -> flushed d) :: acc) i)
      | _ ->
          let j = (try String.index_from fmt i '%' with Not_found -> len) in
          let s = String.sub fmt i (j - i) in
          doprn ((fun d -> literal d s) :: acc) j
  in
  doprn [] 0

(* on a channel, a buffer: %a's printer takes it *)
let fprintf chan fmt =
  pieces fmt output_string (fun c p a -> (Obj.obj p : out_channel -> Obj.t -> unit) c a) (fun c p -> (Obj.obj p : out_channel -> unit) c) flush
    (fun acts -> List.iter (fun f -> f chan) acts; Obj.repr ())

let printf fmt = fprintf stdout fmt
let eprintf fmt = fprintf stderr fmt

let bprintf dest fmt =
  pieces fmt Buffer.add_string (fun b p a -> (Obj.obj p : Buffer.t -> Obj.t -> unit) b a) (fun b p -> (Obj.obj p : Buffer.t -> unit) b) (fun _ -> ())
    (fun acts -> List.iter (fun f -> f dest) acts; Obj.repr ())

(* a string: in a buffer of its own; %a's printer gives a string *)
let ksprintf kont fmt =
  pieces fmt Buffer.add_string (fun b p a -> Buffer.add_string b ((Obj.obj p : unit -> Obj.t -> string) () a))
    (fun b p -> Buffer.add_string b ((Obj.obj p : unit -> string) ())) (fun _ -> ())
    (fun acts -> let b = Buffer.create 64 in List.iter (fun f -> f b) acts; Obj.repr (kont (Buffer.contents b)))

let sprintf fmt = ksprintf (fun s -> s) fmt
