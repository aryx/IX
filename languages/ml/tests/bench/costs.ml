(* What one operation costs in mini-ml's code, in instructions: each is
 * a loop of its own, run n times (tests/costs.sh counts two runs and
 * divides: no clock). The operations are those a game's frame is made
 * of (docs/plans/plan_playground_speed.md): a float's arithmetic and
 * comparison, a block made, a byte stored, a function of another unit
 * called, a division. *)
let () =
  let what = Sys.argv.(1) and n = int_of_string Sys.argv.(2) in
  (* (y is 3, one is 1: neither known when compiled; the float is not
   * printed at the end, its digits would cost by its value) *)
  let y : float = float (Array.length Sys.argv) and x = ref 1.5 and acc = ref 0 in
  let one = y /. y in
  let b = Bytes.create 64 and buf = Buffer.create 64 and l = ref [] and p = ref (0, 0) in
  (match what with
   | "loop" -> for i = 1 to n do acc := !acc + i done
   | "float_mul" -> for i = 1 to n do acc := !acc + i; x := !x *. one done
   | "float_add" -> for i = 1 to n do acc := !acc + i; x := !x +. y done
   | "float_neg" -> for i = 1 to n do acc := !acc + i; x := -. !x done
   | "float_less" -> for i = 1 to n do acc := !acc + i; if !x < y then incr acc done
   | "float_of_int" -> for i = 1 to n do acc := !acc + i; x := float i done
   | "int_of_float" -> for i = 1 to n do acc := !acc + i; acc := !acc + int_of_float y done
   | "float_floor" -> for i = 1 to n do acc := !acc + i; x := Float.floor y done
   | "float_min" -> for i = 1 to n do acc := !acc + i; x := Float.min !x y done
   | "tuple" -> for i = 1 to n do acc := !acc + i; p := (i, i) done
   | "cons" -> for i = 1 to n do acc := !acc + i; l := [ i ] done
   | "byte_set" -> for i = 1 to n do acc := !acc + i; Bytes.unsafe_set b (i land 63) 'x' done
   | "byte_set_checked" -> for i = 1 to n do acc := !acc + i; Bytes.set b (i land 63) 'x' done
   | "buffer_add_char" -> for i = 1 to n do acc := !acc + i; if i land 63 = 0 then Buffer.clear buf; Buffer.add_char buf 'x' done
   | "call_other_unit_2" -> for i = 1 to n do acc := !acc + i; acc := !acc + Int.max i 3 done
   | "call_other_unit_3" -> for i = 1 to n do acc := !acc + i; Bytes.fill b 0 0 'x' done
   | "divide" -> for i = 1 to n do acc := !acc + i; acc := !acc + (i / 7) done
   | "string_compare" -> for i = 1 to n do acc := !acc + i; if what < "zz" then incr acc done
   | _ -> prerr_endline ("costs: no operation " ^ what); exit 2);
  ignore !l; ignore !p;
  if !x > 0. then incr acc;
  Printf.printf "%d %d\n" (!acc land 0xff) (Buffer.length buf)
