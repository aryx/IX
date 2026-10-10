(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-tr: Plan 9's tr (principia's utilities/text/misc/tr.c): the
 * standard input's characters (UTF-8's, not its bytes), each of
 * string1 written as the one at its place in string2 (the last one of
 * string2 when it is shorter), the others as they are.
 * In a string: a-z, the characters from a to z; \ooo and \xhhhh, one by
 * its number, in octal or hexadecimal; \c, c itself.
 * -d: the characters of string1 are taken out; -c: string1 is every
 * character it does not have; -s: of the same character several times
 * in a row in the output, one, when it is of string2. *)

type caps = < Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage
exception Fatal of string

(* a string's characters, its ranges and its escapes made what they
 * say (tr.c's canon, all at once) *)
let expand (spec : string) : int list =
  let n = String.length spec in
  (* the character at k, and where the next one is *)
  let rune k =
    let r, w = Utf8.decode spec k in
    let k = k + w in
    if r <> Char.code '\\' || k >= n then r, k
    else if spec.[k] = 'x' then begin
      let digit c = match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | 'A' .. 'F' -> Char.code c - 55 | _ -> -1 in
      let rec hex j v count = if count < 4 && j < n && digit spec.[j] >= 0 then hex (j + 1) ((16 * v) + digit spec.[j]) (count + 1) else v, j, count in
      let v, j, count = hex (k + 1) 0 0 in
      if count = 0 then Char.code 'x', k + 1 else v, j
    end
    else begin
      let rec oct j v count = if count < 3 && j < n && spec.[j] >= '0' && spec.[j] <= '7' then oct (j + 1) ((8 * v) + Char.code spec.[j] - 48) (count + 1) else v, j, count in
      let v, j, count = oct k 0 0 in
      if count = 0 then (let r, w = Utf8.decode spec k in r, k + w)
      else if v > 0o377 then raise (Fatal "character > 0377")
      else v, j
    end in
  let rec go k last acc =
    if k >= n then List.rev acc
    else if spec.[k] = '-' && last >= 0 && k + 1 < n then begin
      let r, k = rune (k + 1) in
      if r < last then raise (Fatal "invalid range specification");
      go k r (List.rev_append (List.init (r - last) (fun i -> last + 1 + i)) acc)
    end
    else let r, k = rune k in go k r (r :: acc) in
  go 0 (-1) []

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let complement = ref false and delete = ref false and squeeze = ref false in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with 'c' -> complement := true | 'd' -> delete := true | 's' -> squeeze := true | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    let args = options (List.tl (Array.to_list argv)) in
    let from, into = match args with
      | [ a ] when !delete && not !squeeze -> expand a, []
      | [ a; b ] when not !delete || !squeeze -> expand a, expand b
      | _ -> raise Usage in
    let set l = let h = Hashtbl.create 64 in List.iter (fun c -> Hashtbl.replace h c ()) l; h in
    let in_from = set from and in_into = set into in
    let last_of l d = match List.rev l with c :: _ -> c | [] -> d in
    (* what a character becomes: None, taken out *)
    let become : int -> int option =
      if !delete then (fun c -> if Hashtbl.mem in_from c <> !complement then None else Some c)
      else if !complement then begin
        (* each character string1 does not have, in their order, takes
         * the next of string2 (its last when it has no more); those past
         * string1's highest all take that last *)
        let high = List.fold_left max 0 (from @ into) in
        let map = Hashtbl.create 64 and left = ref into and last = ref 0 in
        for c = 0 to high do
          if not (Hashtbl.mem in_from c) then begin
            (match !left with t :: rest -> last := t; left := rest | [] -> ());
            Hashtbl.replace map c !last
          end
        done;
        (fun c -> if c > high then Some !last else Some (match Hashtbl.find_opt map c with Some t -> t | None -> c))
      end
      else begin
        let map = Hashtbl.create 64 in
        let rec pair from into last =
          match from with
          | [] -> ()
          | f :: from ->
              let t, into = match into with t :: rest -> t, rest | [] -> last, [] in
              (match Hashtbl.find_opt map f with Some t' when t' <> t -> raise (Fatal "ambiguous translation") | _ -> ());
              Hashtbl.replace map f t;
              pair from into t in
        pair from into 0;
        ignore (last_of into 0);
        (fun c -> Some (match Hashtbl.find_opt map c with Some t -> t | None -> c))
      end in
    let all = Buffer.create 8192 and buf = Bytes.create 8192 in
    let fd = Console.stdin_fd caps in
    let rec read () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; read () in
    (try read () with Unix.Unix_error (e, _, _) -> raise (Fatal ("read error: " ^ Unix.error_message e)));
    let text = Buffer.contents all and out = Buffer.create 8192 in
    let rec go k last =
      if k < String.length text then begin
        let c, w = Utf8.decode text k in
        match become c with
        | Some c when not (!squeeze && c = last && Hashtbl.mem in_into c) -> Utf8.add out c; go (k + w) c
        | _ -> go (k + w) last
      end in
    go 0 (-1);
    Console.print caps (Buffer.contents out);
    Exit.OK
  with
  | Usage -> Console.eprint caps (Printf.sprintf "usage: %s [-cds] [string1 [string2]]\n" argv.(0)); Exit.Err "usage"
  | Fatal msg -> Console.eprint caps (Printf.sprintf "%s: %s\n" argv.(0) msg); Exit.Err msg

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
