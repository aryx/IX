(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Follow.mli *)

open Link

(* the code in the order its flow goes, from the first TEXT: a branch
 * to code already placed becomes a copy of it when it is short and
 * ends the flow, else a B to it; a conditional branch is inverted when
 * that makes its target the next instruction; and what the flow never
 * reaches (code after a RET) is dropped. 5l's and 7l's xfol (not in
 * xix): [ends] says what ends the flow (a B, a RET), [invert] inverts
 * a conditional branch. xfol builds the new order in the progs' own
 * links: once placed, an instruction's next is what was placed after
 * it. Here the links and the marks are tables, by an id in pc (unused
 * yet) *)
let follow t ~ends =
  let invert (p : _ prog) =
    match p.op with
    | Bcond c -> Bcond (invert c)
    | Func | Nop | B | Bl | Bcase | Ins _ -> let f, l = p.where in error "%s:%d: unknown relation" f l in
  let link = Hashtbl.create 4096 and marked = Hashtbl.create 4096 in
  let ids = ref 0 in
  let fresh (p : _ prog) = p.pc <- !ids; incr ids in
  let rec links = function
    | (p : _ prog) :: (q :: _ as rest) -> fresh p; Hashtbl.replace link p.pc q; links rest
    | [ p ] -> fresh p
    | [] -> ()
  in
  links t.progs;
  let next (p : _ prog) = Hashtbl.find_opt link p.pc in
  let is_marked (p : _ prog) = Hashtbl.mem marked p.pc in
  let mark (p : _ prog) = Hashtbl.replace marked p.pc () in
  (* a TEXT's target is the next TEXT (5l's ldobj) *)
  let texts = List.filter (fun (p : _ prog) -> p.op = Func) t.progs in
  List.iteri (fun i (p : _ prog) -> p.target <- List.nth_opt (List.tl texts) i) texts;
  let rec chain (p : _ prog option) i =
    if i >= 20 then None else match p with Some (q : _ prog) when q.op = B -> chain q.target (i + 1) | _ -> p
  in
  let out = ref [] in
  let last () = match !out with q :: _ -> Some q | [] -> None in
  let emit (p : _ prog) =
    (match !out with l :: _ -> Hashtbl.replace link l.pc p | [] -> ());
    out := p :: !out
  in
  let rec xfol (p : _ prog option) =
    match p with
    | None -> ()
    | Some ({ op = B; target = Some q; _ } as p) when not (is_marked q) -> mark p; xfol (Some q)
    | Some p ->
        let p = match p.op, p.target with B, Some q -> mark p; q | _ -> p in
        if is_marked p then begin
          (* up to 4 instructions from p, if they end the flow *)
          let rec find (q : _ prog) i =
            if i >= 4 || (match last () with Some l -> l == q | None -> false) then None
            (* claude: a NOP (5c -O0's) doesn't count *)
            else if q.op = Nop then (match next q with Some r -> find r i | None -> None)
            else if ends q then Some q
            else if (q.op = Bcond EQ || q.op = Bcond NE) && (match q.target with Some c -> not (is_marked c) | None -> false) then Some q
            else match next q with Some r -> find r (i + 1) | None -> None
          in
          match find p 0 with
          | Some q ->
              let rec copy (p : _ prog) =
                let r = { p with pc = p.pc } (* a copy *) in
                fresh r;
                mark r;
                Option.iter (Hashtbl.replace link r.pc) (next p);
                emit r;
                if p != q then copy (Option.get (next p))
                else if not (ends q) then begin
                  r.op <- invert q;
                  r.target <- next q;
                  Option.iter (Hashtbl.replace link r.pc) q.target;
                  match q.target with Some l when not (is_marked l) -> xfol (Some l) | _ -> ()
                end
              in
              copy p
          | None ->
              let b = { p with op = B; suffixes = []; args = [ Asm.Target 0 ]; target = Some p } in
              fresh b;
              Hashtbl.remove link b.pc;
              mark b;
              emit b
        end
        else begin
          mark p;
          emit p;
          if not (ends p) then
            match p.target, next p with
            | Some _, Some l when p.op <> Bl ->
                let q = chain (Some l) 0 in
                (match q with
                 | Some q when p.op <> Func && p.op <> Bcase && is_marked q ->
                     p.op <- invert p;
                     Hashtbl.replace link p.pc (Option.get p.target);
                     p.target <- Some q
                 | _ -> ());
                xfol (next p);
                let q = match chain p.target 0 with None -> Option.get p.target | Some q -> q in
                if is_marked q then p.target <- Some q else xfol (Some q)
            | _ -> xfol (next p)
        end
  in
  (match t.progs with p :: _ -> xfol (Some p) | [] -> ());
  List.iter (fun (p : _ prog) -> if p.op = Func then p.target <- None) texts;
  t.progs <- List.rev !out
