(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lines_ml.mli *)

let add (caps : < Cap.open_in; .. >) file text (obj : Asm.obj) : Asm.obj =
  let at = Array.make (String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 2 text) 0 in
  let marked = ref false in
  List.iteri (fun i l ->
    let l = String.trim l in
    if String.length l > 8 && String.sub l 0 8 = "// line " then begin
      at.(i + 1) <- (match int_of_string_opt (String.sub l 8 (String.length l - 8)) with Some n -> n | None -> 0);
      if at.(i + 1) > 0 then marked := true
    end
    else if i > 0 then at.(i + 1) <- at.(i)) (String.split_on_char '\n' text);
  if not !marked then { obj with history = [] }
  else
    let last = String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 1 (FS.read caps file) in
    { obj with items = Array.map (fun (it, l) -> (it, if l < Array.length at then at.(l) else 0)) obj.items;
               history = [ Some (Fpath.to_string file), 1; None, last ] }
