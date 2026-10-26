(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCMachine.mli *)
open TinyCTypes
open TinyCTree
open TinyCLower
open TinyCParser

(*****************************************************************************)
(* The machine: TinyCPU, the stack in r1..r12 *)
(*****************************************************************************)

let out = Buffer.create 65536

(* TinyCPU (TinyMachineCPU.ml) has 32-bit registers, r0 zero, no flags, and
 * no unsigned division; its calling convention is ours, simpler than
 * 7c's: every argument in memory, 4 bytes each, the result in r13. The
 * frame, sp at its bottom: the outgoing arguments from 0(sp), the saved
 * lr, the saves of what is live across a call, the locals at its top;
 * above it, the parameters (the caller's outgoing arguments). A
 * variadic function (print) walks its arguments from its last named
 * one's address. *)

let machine name locals (body : ir list) =
  let sp = ref 0 and saves = ref 0 and outgoing = ref 0
  and dead = ref false in
  let depth_at = Hashtbl.create 16 in
  let top () = !sp in
  let push () =
    incr sp;
    if !sp > 12 then error (name ^ ": an expression too deep");
    !sp in
  let jump l = Hashtbl.replace depth_at l !sp in
  let lab l = !unit_name ^ ".L" ^ string_of_int l in
  (* a register's name, a number's text (old: Printf's formats, %d) *)
  let r k = Printf.sprintf "r%d" k and n k = string_of_int k in
  (* the code, each line a function of the frame's size (known at the
   * end); slot k the k-th save, below the locals; lr above the
   * outgoing arguments *)
  let lines = ref [] in
  let at f = lines := f :: !lines in
  let ins s = at (fun _ -> Printf.sprintf "\t%s\n" s) in
  let slot k = locals + (4 * k) in
  (* a value extended from its type: the registers are 32 bits, so only
   * a char's and a short's need it *)
  let extend t a =
    match t with
    | Int (k, s) when k < 4 ->
        if s then
          (ins ("shli\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k)));
           ins ("sari\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k))))
        else ins ("andi\t" ^ r a ^ ", " ^ r a ^ ", " ^ n ((1 lsl (8 * k)) - 1))
    | _ -> () in
  let lr_at () = !outgoing in
  let epilogue () =
    at (fun f ->
      "\tldw\tlr, " ^ n (lr_at ()) ^ "(sp)\n\taddi\tsp, sp, " ^ n f
      ^ "\n\tret\n") in
  (* an instruction of three registers *)
  let three op a b c = ins (op ^ "\t" ^ r a ^ ", " ^ r b ^ ", " ^ r c) in
  List.iter (fun i ->
    match i with
    | Label l ->
        (match Hashtbl.find_opt depth_at l with
         | Some d when !dead -> sp := d
         | _ -> ());
        dead := false;
        at (fun _ -> lab l ^ ":\n")
    | _ when !dead -> ()
    | Imm v -> let a = push () in ins ("li\t" ^ r a ^ ", " ^ word v)
    | Place (Global s) -> let a = push () in ins ("la\t" ^ r a ^ ", " ^ sym s)
    | Place (Local o) ->
        let a = push () in
        at (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f - o) ^ "\n")
    | Place (Param o) ->
        let a = push () in
        at (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f + (4 * (o / 8))) ^ "\n")
    | Load t ->
        let a = top () in
        (match t with
         | Int (1, _) -> ins ("ldb\t" ^ r a ^ ", 0(" ^ r a ^ ")")
         | Int (2, _) ->
             ins ("ldb\tr13, 0(" ^ r a ^ ")");
             ins ("ldb\t" ^ r a ^ ", 1(" ^ r a ^ ")");
             ins ("shli\t" ^ r a ^ ", " ^ r a ^ ", 8");
             ins ("or\t" ^ r a ^ ", " ^ r a ^ ", r13")
         | _ -> ins ("ldw\t" ^ r a ^ ", 0(" ^ r a ^ ")"));
        extend t a
    | Store t ->
        let v = top () in
        decr sp;
        let a = top () in
        (match size t with
         | 1 -> ins ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")")
         | 2 ->
             ins ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")");
             ins ("shri\tr13, " ^ r v ^ ", 8");
             ins ("stb\tr13, 1(" ^ r a ^ ")")
         | _ -> ins ("stw\t" ^ r v ^ ", 0(" ^ r a ^ ")"));
        ins ("mov\t" ^ r a ^ ", " ^ r v)
    | Op (o, t) -> (
        let b = top () in
        decr sp;
        let a = top () and u = unsigned t in
        let slt = if u then "sltu" else "slt" in
        match o with
        | R Lt -> three slt a a b
        | R Gt -> three slt a b a
        | R Le -> three slt a b a; ins ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Ge -> three slt a a b; ins ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Eq -> three "sub" a a b; ins ("sltiu\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Ne -> three "sub" a a b; ins ("sltu\t" ^ r a ^ ", zero, " ^ r a)
        | A ((Div | Mod) as o) when u ->
            (* TinyCPU divides signed only: the runtime's __udivmod, its
             * operands and the remainder below sp, the quotient in r13 *)
            ins ("stw\t" ^ r a ^ ", -4(sp)"); ins ("stw\t" ^ r b ^ ", -8(sp)");
            ins "call\t__udivmod";
            if o = Div then ins ("mov\t" ^ r a ^ ", r13")
            else ins ("ldw\t" ^ r a ^ ", -4(sp)");
            extend t a
        | A o ->
            three
              (match o with
               | Add -> "add" | Sub -> "sub" | Mul -> "mul" | Div -> "div"
               | Mod -> "rem" | And -> "and" | Or -> "or" | Xor -> "xor"
               | Shl -> "shl" | Shr -> if u then "shr" else "sar")
              a a b;
            extend t a)
    | Unop (o, t) ->
        let a = top () in
        if o = Neg then ins ("sub\t" ^ r a ^ ", zero, " ^ r a)
        else
          (ins "addi\tr13, zero, -1";
           ins ("xor\t" ^ r a ^ ", " ^ r a ^ ", r13"));
        extend t a
    | Ext t -> extend t (top ())
    | Dup ->
        let a = top () in let d = push () in ins ("mov\t" ^ r d ^ ", " ^ r a)
    | Drop -> decr sp
    | Call (f, k, res) ->
        let base = !sp - k - (if f = None then 1 else 0) in
        saves := max !saves base;
        for j = 1 to base do
          at (fun fr -> "\tstw\t" ^ r j ^ ", " ^ n (fr - slot j) ^ "(sp)\n")
        done;
        for j = 0 to k - 1 do
          ins ("stw\t" ^ r (base + 1 + j) ^ ", " ^ n (4 * j) ^ "(sp)")
        done;
        outgoing := max !outgoing (4 * k);
        (match f with
         | Some f -> ins ("call\t" ^ sym f)
         | None -> ins ("jalr\tlr, 0(" ^ r (base + k + 1) ^ ")"));
        for j = 1 to base do
          at (fun fr -> "\tldw\t" ^ r j ^ ", " ^ n (fr - slot j) ^ "(sp)\n")
        done;
        sp := base;
        if res then (let d = push () in ins ("mov\t" ^ r d ^ ", r13"))
    | Jmp l -> jump l; ins ("j\t" ^ lab l); dead := true
    | Jz l ->
        let a = top () in
        decr sp; jump l; ins ("beq\t" ^ r a ^ ", zero, " ^ lab l)
    | Jnz l ->
        let a = top () in
        decr sp; jump l; ins ("bne\t" ^ r a ^ ", zero, " ^ lab l)
    | Ret v ->
        if v then (ins ("mov\tr13, " ^ r (top ())); decr sp);
        epilogue (); dead := true)
    body;
  if not !dead then epilogue ();
  let frame = round (!outgoing + 4 + (4 * !saves) + locals) 8 in
  Buffer.add_string out
    (sym name ^ ":\n\taddi\tsp, sp, " ^ n (- frame) ^ "\n\tstw\tlr, "
     ^ n (lr_at ()) ^ "(sp)\n");
  List.iter (fun f -> Buffer.add_string out (f frame)) (List.rev !lines)
