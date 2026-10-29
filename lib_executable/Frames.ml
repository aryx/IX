(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Frames.mli *)

type frame = { pc : int; func : string; offset : int; line : (string * int) option }

(* each function: its start, its letter, its name, its .frame (the
 * entry after it) *)
let functions (t : Symbols.t) =
  let rec go acc = function
    | (s : Symbols.sym) :: (({ typ = 'm'; name = ".frame"; _ } : Symbols.sym) as m) :: rest when String.contains "TtLl" s.typ ->
        go ((s.value, s.typ, s.name, m.value) :: acc) rest
    | (s : Symbols.sym) :: rest when String.contains "TtLl" s.typ -> go ((s.value, s.typ, s.name, 0) :: acc) rest
    | _ :: rest -> go acc rest
    | [] -> acc in
  List.sort (fun (a, _, _, _) (b, _, _, _) -> compare b a) (go [] t.syms)

(* how a function keeps the caller's address: in the link register (a
 * leaf), or at 0(SP), its frame n bytes, saved by an instruction at
 * [saved] (5l's prologue, the first; mini-ml's, the second or third) *)
type kind = Leaf | Saved of int * int

(* mini-ml's prologue (Gen's and Emit's): SUB $n, R13 (an immediate,
 * rotated, or a constant of the pool in R11), then MOVW R14, 0(R13) *)
let prologue (t : Symbols.t) start =
  let w a = Symbols.word t a in
  let str_lr a = w a = Some (0xe58d, 0xe000) in
  match w start with
  | Some (0xe24d, lo) when lo land 0xf000 = 0xd000 && str_lr (start + 4) ->
      let imm = lo land 0xff and rot = 2 * ((lo lsr 8) land 15) in
      (* (rotated right: the bits below rot to the top; a frame is
       * smaller than 2^30, an int's 31 bits where mini-ml builds for arm) *)
      let n = if rot = 0 then imm else (imm lsr rot) lor ((imm lsl (32 - rot)) land 0x3fffffff) in
      Some (Saved (n, start + 4))
  | Some (0xe59f, lo) when lo land 0xf000 = 0xb000 && w (start + 4) = Some (0xe04d, 0xd00b) && str_lr (start + 8) ->
      (match w (start + 8 + (lo land 0xfff)) with
       | Some (hi, lo) -> Some (Saved ((hi lsl 16) lor lo, start + 8))
       | None -> None)
  | _ -> None

let kind t (start, typ, _, frame) =
  match typ with
  | 'L' | 'l' -> (match prologue t start with Some k -> k | None -> Leaf)
  | _ -> Saved (frame, start)

let walk (t : Symbols.t) ~load ~pc ~sp ~lr =
  let fs = functions t in
  let rec go pc sp n acc =
    match List.find_opt (fun (start, _, _, _) -> start <= pc) fs with
    | Some ((start, _, name, _) as f) when n < 40 && pc < t.text_end ->
        let acc = { pc; func = name; offset = pc - start; line = Symbols.file_line t pc } :: acc in
        if name = "_main" then acc
        else begin
          (* the caller's address, and how far the caller's sp is: the
           * link register before the save (the innermost frame only) *)
          let next = match kind t f with
            | Leaf -> if n = 0 then Some (lr, 0) else None
            | Saved (size, saved) ->
                if pc <= saved then (if n = 0 then Some (lr, if pc > start then size else 0) else None)
                else Option.map (fun ra -> ra, size) (load sp) in
          match next with
          (* the call: one instruction before where it returns *)
          | Some (ra, size) when ra <> 0 && not (ra = pc && size = 0) -> go (ra - 4) (sp + size) (n + 1) acc
          | _ -> acc
        end
    | _ -> acc in
  List.rev (go pc sp 0 [])

let show frames =
  String.concat " < " (List.map (fun f ->
    (if f.offset = 0 then f.func else Printf.sprintf "%s+0x%x" f.func f.offset)
    ^ (match f.line with Some (file, l) -> Printf.sprintf " %s:%d" (Filename.basename file) l | None -> "")) frames)
