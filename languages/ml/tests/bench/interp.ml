(* An interpreter's loops, ix's own kind of program (tiny-ml's machine,
 * mini-forth, mini-ml's passes): a stack machine's instructions, a
 * variant of 14 constructors matched at each step; an expression
 * tree evaluated and rewritten, a match on its constructors at each
 * node. What it weighs: the matches (Lower's jump tables), little
 * arithmetic, some allocation. *)

type instr =
  | Push of int | Pop | Dup | Swap | Over
  | Add | Sub | Mul | Lt
  | Load of int | Store of int
  | Jmp of int | Jz of int | Halt

(* for i below n: sum the i * i - i, and count the i below 25 *)
let code = [|
  Push 0; Store 0; Push 0; Store 1; Push 0; Store 2;  (* i, sum, count *)
  Load 0; Load 3; Lt; Jz 32;                          (* 6: i < n? *)
  Load 0; Dup; Mul; Load 0; Sub;                      (* i * i - i *)
  Load 1; Over; Add; Swap; Pop; Store 1;              (* sum + it *)
  Load 0; Push 25; Lt; Load 2; Add; Store 2;          (* count *)
  Load 0; Push 1; Add; Store 0; Jmp 6;
  Halt |]

let run (code : instr array) n =
  let mem = Array.make 4 0 and st = Array.make 16 0 in
  mem.(3) <- n;
  let rec go pc sp =
    match code.(pc) with
    | Push k -> st.(sp) <- k; go (pc + 1) (sp + 1)
    | Pop -> go (pc + 1) (sp - 1)
    | Dup -> st.(sp) <- st.(sp - 1); go (pc + 1) (sp + 1)
    | Swap -> let t = st.(sp - 1) in st.(sp - 1) <- st.(sp - 2); st.(sp - 2) <- t; go (pc + 1) sp
    | Over -> st.(sp) <- st.(sp - 2); go (pc + 1) (sp + 1)
    | Add -> st.(sp - 2) <- st.(sp - 2) + st.(sp - 1); go (pc + 1) (sp - 1)
    | Sub -> st.(sp - 2) <- st.(sp - 2) - st.(sp - 1); go (pc + 1) (sp - 1)
    | Mul -> st.(sp - 2) <- st.(sp - 2) * st.(sp - 1); go (pc + 1) (sp - 1)
    | Lt -> st.(sp - 2) <- (if st.(sp - 2) < st.(sp - 1) then 1 else 0); go (pc + 1) (sp - 1)
    | Load a -> st.(sp) <- mem.(a); go (pc + 1) (sp + 1)
    | Store a -> mem.(a) <- st.(sp - 1); go (pc + 1) (sp - 1)
    | Jmp t -> go t sp
    | Jz t -> if st.(sp - 1) = 0 then go t (sp - 1) else go (pc + 1) (sp - 1)
    | Halt -> mem.(1) + mem.(2)
  in
  go 0 0

type expr =
  | Num of int | Var of int | Neg of expr
  | Plus of expr * expr | Minus of expr * expr | Times of expr * expr
  | Less of expr * expr | If of expr * expr * expr | Let of expr * expr

(* env: the Let's values, the innermost first, by De Bruijn's index *)
let rec eval env e =
  match e with
  | Num n -> n
  | Var k -> List.nth env k
  | Neg a -> - eval env a
  | Plus (a, b) -> eval env a + eval env b
  | Minus (a, b) -> eval env a - eval env b
  | Times (a, b) -> eval env a * eval env b
  | Less (a, b) -> if eval env a < eval env b then 1 else 0
  | If (c, a, b) -> if eval env c <> 0 then eval env a else eval env b
  | Let (a, b) -> eval (eval env a :: env) b

(* a pass of a compiler's: constants folded, x + 0 and x * 1 gone *)
let rec simplify e =
  match e with
  | Num _ | Var _ -> e
  | Neg a -> (match simplify a with Num n -> Num (- n) | a -> Neg a)
  | Plus (a, b) -> (match simplify a, simplify b with Num x, Num y -> Num (x + y) | a, Num 0 | Num 0, a -> a | a, b -> Plus (a, b))
  | Minus (a, b) -> (match simplify a, simplify b with Num x, Num y -> Num (x - y) | a, Num 0 -> a | a, b -> Minus (a, b))
  | Times (a, b) -> (match simplify a, simplify b with Num x, Num y -> Num (x * y) | a, Num 1 | Num 1, a -> a | a, b -> Times (a, b))
  | Less (a, b) -> Less (simplify a, simplify b)
  | If (c, a, b) -> (match simplify c with Num 0 -> simplify b | Num _ -> simplify a | c -> If (c, simplify a, simplify b))
  | Let (a, b) -> Let (simplify a, simplify b)

(* a tree of depth d, of every constructor, with work left to fold *)
let rec tree d =
  if d = 0 then Var 0
  else
    match d mod 4 with
    | 0 -> Plus (tree (d - 1), Times (Num 1, Plus (Num 2, Num 3)))
    | 1 -> If (Less (Var 0, Num 100), Minus (tree (d - 1), Num 0), Neg (Num 4))
    | 2 -> Let (Times (Var 0, Num 2), Plus (tree (d - 1), Var 1))
    | _ -> Times (tree (d - 1), Plus (Num 0, Num 1))

let () =
  let n = ref 0 in
  for i = 1 to 100 do n := !n + run code (50 + i) done;
  let t = tree 12 in
  for i = 1 to 1500 do n := !n + eval [ i ] t + eval [ i ] (simplify t) done;
  Printf.printf "%d\n" !n
