(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Show_ast.mli *)
open Ast

(* a word needs quotes if it has a character rc would read otherwise
 * (fmt.c's needsrcquote), or is empty *)
let quote (s : string) : string =
  let special c = c <= ' ' || String.contains "`^#*[]=|\\?${}()'<>&;~!@\"" c in
  if s <> "" && not (String.exists special s) then s
  else "'" ^ String.concat "''" (String.split_on_char '\'' s) ^ "'"

let rec word (b : Buffer.t) (w : word) : unit =
  let p = Buffer.add_string b in
  match w with
  | Word (s, quoted) -> p (if quoted then quote s else s)
  | Dollar w -> p "$"; word b w
  | Count w -> p "$#"; word b w
  | Join w -> p "$\""; word b w
  | Sub (w, ws) -> p "$"; word b w; p "("; words b ws; p ")"
  | Paren ws -> p "("; words b ws; p ")"
  | Concat (a, c) -> word b a; p "^"; word b c
  | Backquote (sep, c) -> p "`"; Option.iter (word b) sep; p "{"; cmd b c; p "}"
  | Pipefd (side, c) -> p (match side with Reads -> "<{" | Writes -> ">{"); cmd b c; p "}"

(* a redirection's arrow, and the fd it means without [n] *)
and arrow (k : rkind) = match k with Write -> ">", 1 | Append -> ">>", 1 | Read -> "<", 0 | RdWr -> "<>", 0

and words b ws = List.iteri (fun i w -> if i > 0 then Buffer.add_char b ' '; word b w) ws

and redir b (r : redir) =
  let p = Buffer.add_string b in
  match r with
  | Open (k, fd, w) ->
      let arr, default = arrow k in
      p arr;
      if fd <> default then p (Printf.sprintf "[%d]" fd);
      word b w
  | Here (fd, h) ->
      p "<<";
      if fd <> 0 then p (Printf.sprintf "[%d]" fd);
      p (if h.expand then h.tag else quote h.tag)
  | Dup (a, c) -> p (Printf.sprintf ">[%d=%d]" a c)
  | Close a -> p (Printf.sprintf ">[%d=]" a)

and cmd (b : Buffer.t) (c : cmd) : unit =
  let p = Buffer.add_string b in
  match c with
  | Empty -> ()
  | Simple ws -> words b ws
  | Redirect ((Dup _ | Close _) as r, c) -> redir b r; cmd b c
  | Redirect (r, Empty) -> redir b r
  | Redirect (r, c) -> redir b r; p " "; cmd b c
  | Seq (Empty, c) | Seq (c, Empty) -> cmd b c
  | Seq (c1, c2) -> cmd b c1; p ";"; cmd b c2
  | Async c -> cmd b c; p "&"
  | And (c1, c2) -> cmd b c1; p " && "; cmd b c2
  | Or (c1, c2) -> cmd b c1; p " || "; cmd b c2
  | Not c -> p "! "; cmd b c
  | Pipe (l, r, c1, c2) ->
      cmd b c1; p "|";
      if r = 0 then (if l <> 1 then p (Printf.sprintf "[%d]" l))
      else p (Printf.sprintf "[%d=%d]" l r);
      cmd b c2
  | Brace c -> p "{"; cmd b c; p "}"
  | Subshell c -> p "@ "; cmd b c
  | If (cond, c) -> p "if("; cmd b cond; p ")"; cmd b c
  | IfNot c -> p "if not "; cmd b c
  | While (cond, c) -> p "while("; cmd b cond; p ")"; cmd b c
  | For (w, ws, c) ->
      p "for("; word b w;
      Option.iter (fun ws -> p " in "; words b ws) ws;
      p ")"; cmd b c
  | Switch (w, c) -> p "switch "; word b w; p " "; cmd b c
  | Match (w, ws) -> p "~ "; word b w; p " "; words b ws
  | Fn (ws, Some c) -> p "fn "; words b ws; p " "; cmd b c
  | Fn (ws, None) -> p "fn "; words b ws
  | Assign (x, v, None) -> word b x; p "="; word b v
  | Assign (x, v, Some c) -> word b x; p "="; word b v; p " "; cmd b c

let to_string (f : Buffer.t -> 'a -> unit) (x : 'a) : string =
  let b = Buffer.create 80 in
  f b x;
  Buffer.contents b
