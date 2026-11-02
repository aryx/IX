(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cil_strings.mli *)

open Tree
open Tree_helpers
open Cil_types
module S = Signature
module W = Writer

(*****************************************************************************)
(* Literals *)
(*****************************************************************************)

(* the literals' bytes, as the typing writes them (Check.outstring) *)
let strings : Buffer.t = Buffer.create 1024

let outstring (s : string) (n : int) : int =
  let r = Buffer.length strings in
  for i = 0 to n - 1 do
    Buffer.add_char strings (if i < String.length s then s.[i] else '\000')
  done;
  r

(* each literal: its bytes, its field (an sbyte[], NUL ended) *)
let literals : (string * int) list ref = ref []

let reset () : unit =
  Buffer.clear strings;
  literals := []

(* a .NET string to C's: its chars' low bytes, then a NUL *)
let cstr (c : c) : int =
  memo c "cstr" (fun () ->
      let m =
        W.method_def c.w c.cls "<cstr>" 0x0091
          (static [ S.String ] (S.SzArray S.I1)) in
      let k = new_code () in
      let a = local k (S.SzArray S.I1) and i = local k S.I4 in
      let top = label k and stop = label k in
      let length = lib c "String" "get_Length" (instance [] S.I4) in
      let chars = lib c "String" "get_Chars" (instance [ S.I4 ] S.Char) in
      emit k (Il.Ldarg 0); emit k (Il.Callvirt length); ldc k 1;
      emit k (Il.Binop Il.Add);
      emit k (Il.Newarr (sys c "SByte")); emit k (Il.Stloc a);
      ldc k 0; emit k (Il.Stloc i);
      place k top;
      emit k (Il.Ldloc i); emit k (Il.Ldarg 0); emit k (Il.Callvirt length);
      emit k (Il.Bcmp (Il.Ge, false, stop));
      emit k (Il.Ldloc a); emit k (Il.Ldloc i);
      emit k (Il.Ldarg 0); emit k (Il.Ldloc i); emit k (Il.Callvirt chars);
      emit k (Il.Conv (Il.K_i1, false, false)); emit k (Il.Stelem Il.K_i1);
      emit k (Il.Ldloc i); ldc k 1; emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
      emit k (Il.Br top);
      place k stop;
      emit k (Il.Ldloc a); emit k Il.Ret;
      finish c k m;
      m)

let literal (c : c) (bytes : string) : int =
  match List.assoc_opt bytes !literals with
  | Some f -> f
  | None ->
      let name = Printf.sprintf "<str>%d" (List.length !literals) in
      let f = W.field_def c.w c.cls name 0x0016 (S.SzArray S.I1) in
      literals := (bytes, f) :: !literals;
      f

(* a literal's bytes, from the typing's .string *)
let literal_bytes (line : int) (t : typ) (off : int) : string =
  if t.etype <> Tarray || (link t).etype <> Tchar then
    refuse line "a literal of wide characters";
  Buffer.sub strings off (t.width - 1)

(* a literal's array: its field, made at its first use *)
let literal_array (c : c) (k : code) (bytes : string) : unit =
  let fld = literal c bytes and l = label k in
  emit k (Il.Ldsfld fld);
  emit k Il.Dup;
  emit k (Il.Brtrue l);
  emit k Il.Pop;
  emit k (Il.Ldstr (W.user_string c.w bytes));
  emit k (Il.Call (cstr c));
  emit k Il.Dup;
  emit k (Il.Stsfld fld);
  place k l

(*****************************************************************************)
(* print's formats *)
(*****************************************************************************)

(* libc.c's functions the compiler calls: their methods, as libc.c
 * defines them (read after the program) *)
let helper (c : c) (name : string) : int =
  let str = ptr_of c S.I1 in
  let ps, r =
    match name with
    | "_begin" | "exits" -> ([ str ], S.Void)
    | "_puts" -> ([ str; S.I4; S.I4 ], S.Void)
    | "_putc" -> ([ S.I4 ], S.Void)
    | "_putint" -> ([ S.I8; S.I4; S.I4; S.I4; S.I4 ], S.Void)
    | "_end" -> ([], S.I4)
    | _ -> failwith ("helper " ^ name) in
  memo c ("fn " ^ name) (fun () -> W.method_def c.w c.cls name 0x0096 (static ps r))

let format (c : c) (k : code) (line : int) (buf : (unit -> unit) option)
    (args : (expr * (unit -> unit)) list) (text : string) : unit =
  let call (name : string) = emit k (Il.Call (helper c name)) in
  let rest = ref args in
  let next () =
    match !rest with
    | x :: tl -> rest := tl; x
    | [] -> refuse line "print: more verbs than arguments" in
  (match buf with Some b -> b () | None -> emit k Il.Ldnull);
  call "_begin";
  let lit (s : string) =
    if s <> "" then begin
      literal_array c k s; ldc k 0;
      emit k (Il.Newobj (ptr_ctor c S.I1));
      ldc k 0; ldc k 0;
      call "_puts"
    end in
  let n = String.length text in
  let rec go (i : int) (start : int) =
    if i >= n then lit (String.sub text start (i - start))
    else if text.[i] <> '%' then go (i + 1) start
    else begin
      lit (String.sub text start (i - start));
      (* flags, width, h and l, then the verb *)
      let j = ref (i + 1) and width = ref 0 in
      let left = ref false and zero = ref false in
      while !j < n && (text.[!j] = '-' || text.[!j] = '0') && !width = 0 do
        if text.[!j] = '-' then left := true else zero := true;
        incr j
      done;
      while !j < n && text.[!j] >= '0' && text.[!j] <= '9' do
        width := !width * 10 + Char.code text.[!j] - 48;
        incr j
      done;
      while !j < n && (text.[!j] = 'h' || text.[!j] = 'l') do incr j done;
      if !j >= n then refuse line "a format ending in %";
      let flags = (if !left then 1 else 0) + if !zero then 2 else 0 in
      (match text.[!j] with
       | '%' -> lit "%"
       | 's' ->
           let a, v = next () in
           if a.t.etype <> Tind then refuse line "%s of no string";
           v (); ldc k !width; ldc k flags; call "_puts"
       | 'c' -> let _, v = next () in v (); call "_putc"
       (* (u a verb, as goken's libc and the tests' have it: %ud the
        * number, then a d) *)
       | ('d' | 'u' | 'x' | 'X' | 'o' | 'b') as verb ->
           let a, v = next () in
           if not (typei a.t.etype) then
             refuse line ("%" ^ String.make 1 verb ^ " of no integer");
           v ();
           if a.t.etype <> Tvlong && a.t.etype <> Tuvlong then begin
             let unsigned = typeu a.t.etype || verb <> 'd' in
             emit k (Il.Conv ((if unsigned then Il.K_u8 else Il.K_i8), false, false))
           end;
           ldc k (match verb with 'x' | 'X' -> 16 | 'o' -> 8 | 'b' -> 2 | _ -> 10);
           ldc k (if verb = 'X' then 1 else 0);
           ldc k !width; ldc k flags;
           call "_putint"
       | v -> refuse line (Printf.sprintf "print's verb %%%c" v));
      go (!j + 1) (!j + 1)
    end in
  go 0 0;
  if !rest <> [] then refuse line "print: more arguments than verbs";
  call "_end"
