(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-xd: Plan 9's xd (principia's utilities/byte/xd.c): a file's
 * bytes shown, 16 a line after their address; without an option as
 * numbers of 4 bytes in hexadecimal, the high byte first.
 * A format, and a line for each one given: -c the characters (a byte
 * that is none in hexadecimal); or a size, b or 1, w or 2, l or 4, v
 * or 8 bytes, with a base, o, d or x (-bx: bytes in hexadecimal).
 * -ao, -ad, -ax: the address's base; -r: lines the same as the one
 * before are a single *; -s: the bytes of each 4 turned around first;
 * -u is xd.c's (its output not kept). Not xd.c's -R (characters of
 * several bytes). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage

type format = Chars | Numbers of int * int   (* how many bytes, the base *)

(* bytes as one number, the high one first, in a base, with at least
 * so many digits: divided by the base a byte at a time (8 bytes are
 * past any int) *)
let number (bytes : int list) base width =
  let rec digits bytes acc =
    if List.for_all (fun b -> b = 0) bytes then acc
    else begin
      let rem = ref 0 in
      let quotient = List.map (fun b -> let v = (!rem * 256) + b in rem := v mod base; v / base) bytes in
      digits quotient (String.make 1 "0123456789abcdef".[!rem] ^ acc)
    end in
  let s = digits bytes "" in
  String.make (max 0 (width - String.length s)) '0' ^ s

(* the digits a number of so many bytes has at most, in each base *)
let width size base = match size, base with
  | 1, 8 -> 3 | 1, 10 -> 3 | 1, _ -> 2 | 2, 8 -> 6 | 2, 10 -> 5 | 2, _ -> 4
  | 4, 8 -> 11 | 4, 10 -> 10 | 4, _ -> 8 | _, 8 -> 22 | _, 10 -> 20 | _ -> 16

let character c =
  match c with
  | '\t' -> " \\t" | '\r' -> " \\r" | '\n' -> " \\n" | '\b' -> " \\b"
  | c when c >= '\127' || c < ' ' -> Printf.sprintf " %02x" (Char.code c)
  | c -> Printf.sprintf "  %c" c

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let repeats = ref false and swizzle = ref false and abase = ref 16 and formats = ref [] in
    let rec options = function
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let letters = String.sub a 1 (String.length a - 1) in
          (match letters with
           | "r" -> repeats := true
           | "s" -> swizzle := true
           | "u" -> ()
           | "ao" -> abase := 8
           | "ad" -> abase := 10
           | "ax" -> abase := 16
           | "c" -> formats := !formats @ [ Chars, !abase ]
           | _ ->
               (* a size and a base, each the last said; 4 bytes in hexadecimal when not *)
               let size = ref 4 and base = ref 16 in
               String.iter (function
                 | 'o' -> base := 8 | 'd' -> base := 10 | 'x' -> base := 16
                 | 'b' | '1' -> size := 1 | 'w' | '2' -> size := 2 | 'l' | '4' -> size := 4 | 'v' | '8' -> size := 8
                 | _ -> raise Usage) letters;
               formats := !formats @ [ Numbers (!size, !base), !abase ]);
          options rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    let formats = if !formats = [] then [ Numbers (4, 16), !abase ] else !formats in
    let out = Buffer.create 8192 in
    (* an address: 7 digits, zeros before on a line's first format, spaces on the others *)
    let address addr base fill =
      let s = number [ (addr lsr 24) land 0xff; (addr lsr 16) land 0xff; (addr lsr 8) land 0xff; addr land 0xff ] base 1 in
      String.make (max 0 (7 - String.length s)) fill ^ s ^ " " in
    let dump name title =
      match (match name with Some n -> FS.open_in_fd caps n | None -> Console.stdin_fd caps) with
      | exception Unix.Unix_error _ -> Console.eprint caps (Printf.sprintf "xd: can't open %s\n" (Option.get name)); true
      | fd ->
          let all = Buffer.create 8192 and buf = Bytes.create 8192 in
          let rec go () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; go () | exception Unix.Unix_error _ -> () in
          go ();
          if name <> None then Unix.close fd;
          let data = Buffer.contents all in
          if title then Buffer.add_string out (Option.get name ^ "\n");
          let len = String.length data in
          (* 16 bytes at an address, zeros after the file's end; turned around by 4 when asked *)
          let line addr =
            let at k = if addr + k < len then Char.code data.[addr + k] else 0 in
            List.init 16 (fun k -> at (if !swizzle then (k land lnot 3) + (3 - (k land 3)) else k)) in
          let rec lines addr before star =
            let n = min 16 (len - addr) in
            let bytes = line addr in
            if n = 16 && !repeats && addr > 0 && before = Some bytes then begin
              if not star then Buffer.add_string out "*\n";
              lines (addr + 16) before true
            end
            else begin
              List.iteri (fun k (format, base) ->
                Buffer.add_string out (address addr base (if k = 0 then '0' else ' '));
                let shown = List.filteri (fun j _ -> j < n) bytes in
                (match format with
                 | Chars -> List.iter (fun b -> Buffer.add_string out (character (Char.chr b))) shown
                 | Numbers (size, base) ->
                     (* (a number that starts before the end is whole, with the zeros after) *)
                     List.iteri (fun j _ -> if j mod size = 0 then Buffer.add_string out (" " ^ number (List.filteri (fun i _ -> i >= j && i < j + size) bytes) base (width size base))) shown);
                Buffer.add_char out '\n') formats;
              (* the end: a line shorter than 16 (an empty one, after a file of whole lines), then the address alone *)
              if n < 16 then Buffer.add_string out (address (addr + n) !abase '0' ^ "\n")
              else lines (addr + 16) (if !repeats then Some bytes else before) false
            end in
          lines 0 None false;
          Console.print caps (Buffer.contents out); Buffer.clear out;
          false in
    let failed = match files with
      | [] -> dump None false
      | [ file ] -> dump (Some file) false
      | files -> List.fold_left (fun failed file -> dump (Some file) true || failed) false files in
    if failed then Exit.Err "error" else Exit.OK
  with Usage -> Console.eprint caps "usage: xd [-u] [-r] [-s] [-a{odx}] [-c|{b1w2l4v8}{odx}] ... file ...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
