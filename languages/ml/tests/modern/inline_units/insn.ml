type t =
  | Mov of { rd : int; imm : int }
  | Add of { rd : int; rn : int; rm : int }
  | Branch of { target : int; mutable taken : bool }
  | Nop

let show = function
  | Mov { rd; imm } -> "mov r" ^ string_of_int rd ^ ", #" ^ string_of_int imm
  | Add a -> "add r" ^ string_of_int a.rd ^ ", r" ^ string_of_int a.rn ^ ", r" ^ string_of_int a.rm
  | Branch { target; taken } -> "b " ^ string_of_int target ^ (if taken then " (taken)" else "")
  | Nop -> "nop"

let decode w =
  match w lsr 12 with
  | 1 -> Mov { rd = (w lsr 8) land 15; imm = w land 255 }
  | 2 -> Add { rd = (w lsr 8) land 15; rn = (w lsr 4) land 15; rm = w land 15 }
  | 3 -> Branch { target = w land 0xfff; taken = false }
  | _ -> Nop
