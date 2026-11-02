(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Answers.mli *)

module D = Datalog

let fingerprint (p : D.t) : Int64.t =
  let total = ref 0L in
  Hashtbl.iter
    (fun (_ : string) (r : D.relation) ->
      if r.rules > 0 then
        List.iter
          (fun (t : int array) ->
            let h = ref (Fingerprint.basis ()) in
            String.iter
              (fun (ch : char) -> h := Fingerprint.mix !h (Char.code ch))
              (D.show p r t);
            total := Fingerprint.add !total !h)
          (D.tuples r))
    p.relations;
  !total

let hex (x : Int64.t) : string =
  String.init 16 (fun (i : int) ->
      let digit = Int64.logand (Int64.shift_right_logical x (4 * (15 - i))) 15L in
      "0123456789abcdef".[Int64.to_int digit])
