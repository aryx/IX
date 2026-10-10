(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Prolog_builtins.mli *)

module P = Prolog
module M = Prolog_machine

(*****************************************************************************)
(* An argument as what a built-in wants *)
(*****************************************************************************)

let int_of (t : P.term) : int =
  match P.deref t with
  | P.Int n -> n
  | P.Var _ -> raise (M.instantiation_error ())
  | t -> raise (M.type_error "integer" t)

let atom_of (t : P.term) : string =
  match P.deref t with
  | P.Atom s -> s
  | P.Var _ -> raise (M.instantiation_error ())
  | t -> raise (M.type_error "atom" t)

(* an atom's or a number's text, or a list of codes' or characters' *)
let text (t : P.term) : string =
  match P.deref t with
  | P.Var _ -> raise (M.instantiation_error ())
  | t -> ( match P.text_of t with Some s -> s | None -> raise (M.type_error "atomic" t))

(* a list of codes' or of characters' text ([] is the empty one) *)
let codes (t : P.term) : string = match P.deref t with P.Atom "[]" -> "" | t -> text t

let list_of (t : P.term) : P.term list =
  match P.to_list t with
  | Some items -> items
  | None -> ( match P.deref t with P.Var _ -> raise (M.instantiation_error ()) | t -> raise (M.type_error "list" t))

let is_var (t : P.term) : bool = match P.deref t with P.Var _ -> true | _ -> false
let show (m : M.t) (t : P.term) : string = P.to_string m.ops ~quoted:true t

let syntax_error (msg : string) : exn = M.error (P.Struct ("syntax_error", [ P.Atom msg ]))

(*****************************************************************************)
(* Arithmetic *)
(*****************************************************************************)

let zero_divisor () : exn = M.error (P.Struct ("evaluation_error", [ P.Atom "zero_divisor" ]))

let rec power (a : int) (b : int) : int = if b = 0 then 1 else if b mod 2 = 0 then power (a * a) (b / 2) else a * power a (b - 1)
let rec gcd (a : int) (b : int) : int = if b = 0 then abs a else gcd b (a mod b)

let rec eval (t : P.term) : int =
  match P.deref t with
  | P.Int n -> n
  | P.Var _ -> raise (M.instantiation_error ())
  | P.Atom "max_integer" -> max_int
  | P.Atom "min_integer" -> min_int
  | P.Struct (".", [ x; _ ]) -> eval x
  | P.Struct (name, [ a ]) as t -> (
      let a = eval a in
      match name with
      | "-" -> -a
      | "+" -> a
      | "abs" -> abs a
      | "sign" -> Int.compare a 0
      | "\\" -> lnot a
      | "random" -> if a <= 0 then raise (M.type_error "evaluable" t) else Random.int a
      | _ -> raise (M.type_error "evaluable" (M.indicator name 1)))
  | P.Struct (name, [ a; b ]) -> (
      let a = eval a and b = eval b in
      match name with
      | "+" -> a + b
      | "-" -> a - b
      | "*" -> a * b
      (* (no floats: / is // here) *)
      | "//" | "/" -> if b = 0 then raise (zero_divisor ()) else a / b
      | "rem" -> if b = 0 then raise (zero_divisor ()) else a mod b
      | "mod" ->
          if b = 0 then raise (zero_divisor ())
          else
            let r = a mod b in
            if r <> 0 && r < 0 <> (b < 0) then r + b else r
      | "div" ->
          if b = 0 then raise (zero_divisor ())
          else
            let q = a / b in
            if a mod b <> 0 && a < 0 <> (b < 0) then q - 1 else q
      | "min" -> if a < b then a else b
      | "max" -> if a > b then a else b
      | "**" | "^" -> if b < 0 then raise (M.type_error "float" (P.Int a)) else power a b
      | ">>" -> a asr b
      | "<<" -> a lsl b
      | "/\\" -> a land b
      | "\\/" -> a lor b
      | "xor" -> a lxor b
      | "gcd" -> gcd a b
      | _ -> raise (M.type_error "evaluable" (M.indicator name 2)))
  | P.Atom name -> raise (M.type_error "evaluable" (M.indicator name 0))
  | t -> raise (M.type_error "evaluable" t)

(*****************************************************************************)
(* Clauses written *)
(*****************************************************************************)

(* a clause as listing writes it: a goal a line *)
let portray (m : M.t) (t : P.term) : string =
  let t = P.copy t in
  List.iteri
    (fun (i : int) (v : P.term) -> match v with P.Var x -> x.value <- Some (P.Struct ("$VAR", [ P.Int i ])) | _ -> ())
    (P.variables t);
  let goal (g : P.term) : string =
    let s = show m g in
    match P.deref g with
    | P.Struct (name, [ _; _ ]) when (match Hashtbl.find_opt m.ops.infix name with Some (p, _) -> p > 999 | None -> false) ->
        "(" ^ s ^ ")"
    | _ -> s in
  let rec goals (b : P.term) : string list =
    match P.deref b with
    | P.Struct (",", [ x; y ]) -> goal x :: goals y
    | g -> [ goal g ] in
  match P.deref t with
  | P.Struct (":-", [ h; b ]) -> (
      match P.deref b with
      | P.Atom "true" -> show m h ^ ".\n"
      | b -> show m h ^ " :-\n    " ^ String.concat ",\n    " (goals b) ^ ".\n")
  | t -> show m t ^ ".\n"

(*****************************************************************************)
(* An error said *)
(*****************************************************************************)

let message (m : M.t) (ball : P.term) : string =
  match P.deref ball with
  | P.Struct ("error", [ formal; _ ]) -> (
      match P.deref formal with
      | P.Struct ("existence_error", [ kind; what ]) -> (
          match P.deref kind with
          | P.Atom "procedure" -> "unknown procedure " ^ show m what
          | kind -> Printf.sprintf "no such %s: %s" (show m kind) (show m what))
      | P.Struct ("type_error", [ kind; culprit ]) ->
          Printf.sprintf "type error: %s expected, found %s" (show m kind) (show m culprit)
      | P.Atom "instantiation_error" -> "a variable is not bound where a value is needed"
      | P.Struct ("evaluation_error", [ what ]) -> "arithmetic: " ^ show m what
      | P.Struct ("syntax_error", [ what ]) -> "syntax error: " ^ P.to_string m.ops ~quoted:false what
      | P.Struct ("permission_error", [ action; _; what ]) ->
          Printf.sprintf "no permission to %s %s" (show m action) (show m what)
      | formal -> "error: " ^ show m formal)
  | ball -> "uncaught exception: " ^ show m ball

(*****************************************************************************)
(* Consulting *)
(*****************************************************************************)

let add_loaded (m : M.t) (t : P.term) : unit =
  let head : P.term = match P.deref t with P.Struct (":-", [ h; _ ]) -> h | t -> t in
  (* a predicate's first clause in this text replaces what an earlier
   * text gave it: a file consulted again is read anew *)
  (match Prolog_db.functor_of head with
   | Some (name, arity) ->
       let k = M.key name arity in
       if not (Hashtbl.mem m.loading k) then begin
         Hashtbl.replace m.loading k ();
         match M.find_pred m name arity with
         | Some p when not p.dynamic ->
             p.clauses <- [];
             p.added <- []
         | _ -> ()
       end
   | None -> ());
  M.add_clause m ~front:false t

let consult_text (m : M.t) (from : string) (text : string) : unit =
  let r = Prolog_read.make m.ops text in
  let loading = m.loading and inits = m.inits in
  m.loading <- Hashtbl.create 61;
  m.inits <- [];
  let complain (pos : int) (what : string) : unit =
    m.errors <- m.errors + 1;
    m.warn (Printf.sprintf "%s:%d: %s\n" from (Prolog_read.line r pos) what) in
  let directive (pos : int) (goal : P.term) : unit =
    match M.once m goal with
    | true -> ()
    | false -> complain pos ("the directive failed: " ^ show m goal)
    | exception M.Throw ball -> complain pos (message m ball) in
  let stop = ref false in
  while not !stop do
    match Prolog_read.next r with
    | None -> stop := true
    | exception Prolog_read.Error (msg, pos) ->
        complain pos msg;
        Prolog_read.skip r
    | Some (t, _) -> (
        let pos = Prolog_read.position r in
        match P.deref t with
        | P.Struct ((":-" | "?-"), [ goal ]) -> directive pos goal
        | P.Struct ("-->", [ _; _ ]) -> (
            let clause = P.fresh () in
            match M.once m (P.Struct ("$dcg", [ t; clause ])) with
            | true -> add_loaded m clause
            | false -> complain pos "this grammar rule cannot be translated"
            | exception M.Throw ball -> complain pos (message m ball))
        | t -> ( try add_loaded m t with M.Throw ball -> complain pos (message m ball)))
  done;
  let pos = String.length text in
  List.iter (fun (goal : P.term) -> directive pos goal) (List.rev m.inits);
  m.loading <- loading;
  m.inits <- inits

let consult_file (m : M.t) (name : string) : unit =
  let text : string =
    try m.read_file name
    with Failure _ -> (
      try m.read_file (name ^ ".pl")
      with Failure _ ->
        raise (M.error (P.Struct ("existence_error", [ P.Atom "file"; P.Atom name ])))) in
  consult_text m name text

(*****************************************************************************)
(* format/2 *)
(*****************************************************************************)

let format (m : M.t) (fmt : string) (args : P.term list) : string =
  let b = Buffer.create 80 in
  let args : P.term list ref = ref args in
  let arg () : P.term =
    match !args with
    | a :: rest ->
        args := rest;
        a
    | [] -> raise (M.error (P.Struct ("format", [ P.Atom "not enough arguments" ]))) in
  let n = String.length fmt in
  let i = ref 0 in
  while !i < n do
    let c = fmt.[!i] in
    incr i;
    if c <> '~' || !i >= n then Buffer.add_char b c
    else begin
      (* (a number before the letter: a column's or a count's, passed) *)
      while !i < n && (Prolog.is_digit fmt.[!i] || fmt.[!i] = '*') do
        incr i
      done;
      let d = if !i < n then fmt.[!i] else '~' in
      incr i;
      match d with
      | 'w' -> Buffer.add_string b (P.to_string m.ops ~quoted:false (arg ()))
      | 'a' -> Buffer.add_string b (text (arg ()))
      | 'q' | 'p' -> Buffer.add_string b (show m (arg ()))
      | 'd' -> Buffer.add_string b (string_of_int (eval (arg ())))
      | 's' -> Buffer.add_string b (codes (arg ()))
      | 'c' -> Buffer.add_char b (Char.chr (int_of (arg ()) land 255))
      | 'n' -> Buffer.add_char b '\n'
      | '~' -> Buffer.add_char b '~'
      | 'i' -> ignore (arg ())
      | 't' | '|' | '+' -> ()
      | d -> raise (M.error (P.Struct ("format", [ P.Atom (Printf.sprintf "~%c is not known" d) ])))
    end
  done;
  Buffer.contents b

(*****************************************************************************)
(* The built-ins *)
(*****************************************************************************)

let install (m : M.t) : unit =
  let def (name : string) (arity : int) (f : M.t -> P.term array -> bool) : unit = M.define m name arity f in
  let test (name : string) (p : P.term -> bool) : unit =
    def name 1 (fun (_ : M.t) (a : P.term array) -> p (P.deref a.(0))) in
  let order (name : string) (p : int -> bool) : unit =
    def name 2 (fun (_ : M.t) (a : P.term array) -> p (P.compare a.(0) a.(1))) in
  let arith (name : string) (p : int -> int -> bool) : unit =
    def name 2 (fun (_ : M.t) (a : P.term array) -> p (eval a.(0)) (eval a.(1))) in
  let output (name : string) (f : M.t -> P.term -> string) : unit =
    def name 1 (fun (m : M.t) (a : P.term array) -> m.print (f m a.(0)); true) in

  (* terms *)
  def "=" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(0) a.(1));
  def "\\=" 2 (fun (m : M.t) (a : P.term array) -> not (M.unifiable m a.(0) a.(1)));
  order "==" (fun (c : int) -> c = 0);
  order "\\==" (fun (c : int) -> c <> 0);
  order "@<" (fun (c : int) -> c < 0);
  order "@>" (fun (c : int) -> c > 0);
  order "@=<" (fun (c : int) -> c <= 0);
  order "@>=" (fun (c : int) -> c >= 0);
  def "compare" 3 (fun (m : M.t) (a : P.term array) ->
      let c = P.compare a.(1) a.(2) in
      M.unify m a.(0) (P.Atom (if c < 0 then "<" else if c > 0 then ">" else "=")));
  test "var" (fun (t : P.term) -> match t with P.Var _ -> true | _ -> false);
  test "nonvar" (fun (t : P.term) -> match t with P.Var _ -> false | _ -> true);
  test "atom" (fun (t : P.term) -> match t with P.Atom _ -> true | _ -> false);
  test "number" (fun (t : P.term) -> match t with P.Int _ -> true | _ -> false);
  test "integer" (fun (t : P.term) -> match t with P.Int _ -> true | _ -> false);
  test "atomic" (fun (t : P.term) -> match t with P.Atom _ | P.Int _ -> true | _ -> false);
  test "compound" (fun (t : P.term) -> match t with P.Struct _ -> true | _ -> false);
  test "callable" (fun (t : P.term) -> match t with P.Atom _ | P.Struct _ -> true | _ -> false);
  test "is_list" (fun (t : P.term) -> match P.to_list t with Some _ -> true | None -> false);
  test "ground" (fun (t : P.term) -> match P.variables t with [] -> true | _ -> false);
  def "functor" 3 (fun (m : M.t) (a : P.term array) ->
      match P.deref a.(0) with
      | P.Var _ -> (
          let n = int_of a.(2) in
          match P.deref a.(1) with
          | P.Var _ -> raise (M.instantiation_error ())
          | name when n = 0 -> M.unify m a.(0) name
          | P.Atom name -> M.unify m a.(0) (P.Struct (name, List.init n (fun (_ : int) -> P.fresh ())))
          | name -> raise (M.type_error "atom" name))
      | P.Struct (name, args) -> M.unify m a.(1) (P.Atom name) && M.unify m a.(2) (P.Int (List.length args))
      | t -> M.unify m a.(1) t && M.unify m a.(2) (P.Int 0));
  def "$arg" 3 (fun (m : M.t) (a : P.term array) ->
      let n = int_of a.(0) in
      match P.deref a.(1) with
      | P.Struct (_, args) -> n >= 1 && n <= List.length args && M.unify m a.(2) (List.nth args (n - 1))
      | P.Var _ -> raise (M.instantiation_error ())
      | t -> raise (M.type_error "compound" t));
  def "=.." 2 (fun (m : M.t) (a : P.term array) ->
      match P.deref a.(0) with
      | P.Struct (name, args) -> M.unify m a.(1) (P.of_list (P.Atom name :: args))
      | P.Var _ -> (
          match list_of a.(1) with
          | [] -> raise (M.type_error "list" P.nil)
          | [ t ] -> M.unify m a.(0) t
          | f :: args -> M.unify m a.(0) (P.Struct (atom_of f, args)))
      | t -> M.unify m a.(1) (P.of_list [ t ]));
  def "copy_term" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.copy a.(0)));
  def "term_variables" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.of_list (P.variables a.(0))));
  def "unify_with_occurs_check" 2 (fun (m : M.t) (a : P.term array) ->
      let mark = m.trail_size and young = m.young in
      m.young <- max_int;
      (* (bound, then looked at: a variable inside its own value makes
       * a term that has itself among its variables' values) *)
      let rec cyclic (t : P.term) (inside : int list) : bool =
        match t with
        | P.Var v -> (
            match v.value with
            | Some t' -> List.mem v.id inside || cyclic t' (v.id :: inside)
            | None -> false)
        | P.Struct (_, args) -> List.exists (fun (x : P.term) -> cyclic x inside) args
        | _ -> false in
      let ok = M.unify m a.(0) a.(1) && not (cyclic a.(0) []) in
      M.undo m mark;
      m.young <- young;
      ok && M.unify m a.(0) a.(1));

  (* arithmetic *)
  def "is" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(0) (P.Int (eval a.(1))));
  arith "=:=" (fun (x : int) (y : int) -> x = y);
  arith "=\\=" (fun (x : int) (y : int) -> x <> y);
  arith "<" (fun (x : int) (y : int) -> x < y);
  arith ">" (fun (x : int) (y : int) -> x > y);
  arith "=<" (fun (x : int) (y : int) -> x <= y);
  arith ">=" (fun (x : int) (y : int) -> x >= y);
  def "succ" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then begin
        let y = int_of a.(1) in
        y > 0 && M.unify m a.(0) (P.Int (y - 1))
      end
      else M.unify m a.(1) (P.Int (int_of a.(0) + 1)));
  def "plus" 3 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(2) then M.unify m a.(2) (P.Int (int_of a.(0) + int_of a.(1)))
      else if is_var a.(1) then M.unify m a.(1) (P.Int (int_of a.(2) - int_of a.(0)))
      else M.unify m a.(0) (P.Int (int_of a.(2) - int_of a.(1))));

  (* atoms and their characters *)
  let chars (s : string) : P.term = P.of_list (List.init (String.length s) (fun (i : int) -> P.Atom (String.make 1 s.[i]))) in
  def "atom_codes" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then M.unify m a.(0) (P.Atom (codes a.(1))) else M.unify m a.(1) (P.of_string (text a.(0))));
  def "atom_chars" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then M.unify m a.(0) (P.Atom (codes a.(1))) else M.unify m a.(1) (chars (text a.(0))));
  def "char_code" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then M.unify m a.(0) (P.Atom (String.make 1 (Char.chr (int_of a.(1) land 255))))
      else M.unify m a.(1) (P.Int (Char.code (atom_of a.(0)).[0])));
  def "atom_length" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.Int (String.length (text a.(0)))));
  let number (s : string) : P.term =
    match int_of_string_opt (String.trim s) with
    | Some n -> P.Int n
    | None -> raise (syntax_error ("not a number: " ^ s)) in
  def "number_codes" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then M.unify m a.(0) (number (codes a.(1))) else M.unify m a.(1) (P.of_string (text a.(0))));
  def "atom_number" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then M.unify m a.(0) (P.Atom (string_of_int (int_of a.(1))))
      else match int_of_string_opt (text a.(0)) with Some n -> M.unify m a.(1) (P.Int n) | None -> false);
  def "$atom_concat" 3 (fun (m : M.t) (a : P.term array) -> M.unify m a.(2) (P.Atom (text a.(0) ^ text a.(1))));
  def "upcase_atom" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.Atom (String.uppercase_ascii (text a.(0)))));
  def "atomic_list_concat" 2 (fun (m : M.t) (a : P.term array) ->
      M.unify m a.(1) (P.Atom (String.concat "" (List.map text (list_of a.(0))))));
  def "atomic_list_concat" 3 (fun (m : M.t) (a : P.term array) ->
      let sep = text a.(1) in
      let joinable : bool =
        match P.to_list a.(0) with Some items -> List.for_all (fun (t : P.term) -> not (is_var t)) items | None -> false in
      if joinable then M.unify m a.(2) (P.Atom (String.concat sep (List.map text (list_of a.(0)))))
      else begin
        (* the other way: the atom split at each separator *)
        if sep = "" then raise (M.instantiation_error ());
        let s = text a.(2) in
        let k = String.length sep in
        let parts : P.term list ref = ref [] in
        let from = ref 0 and i = ref 0 in
        while !i + k <= String.length s do
          if String.sub s !i k = sep then begin
            parts := P.Atom (String.sub s !from (!i - !from)) :: !parts;
            i := !i + k;
            from := !i
          end
          else incr i
        done;
        parts := P.Atom (String.sub s !from (String.length s - !from)) :: !parts;
        M.unify m a.(0) (P.of_list (List.rev !parts))
      end);
  def "term_to_atom" 2 (fun (m : M.t) (a : P.term array) ->
      if is_var a.(0) then
        match Prolog_read.term m.ops (text a.(1)) with
        | t, _ -> M.unify m a.(0) t
        | exception Prolog_read.Error (msg, _) -> raise (syntax_error msg)
      else M.unify m a.(1) (P.Atom (show m a.(0))));

  (* lists *)
  def "$list_length" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.Int (List.length (list_of a.(0)))));
  def "msort" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.of_list (List.stable_sort P.compare (list_of a.(0)))));
  def "sort" 2 (fun (m : M.t) (a : P.term array) -> M.unify m a.(1) (P.of_list (List.sort_uniq P.compare (list_of a.(0)))));
  def "keysort" 2 (fun (m : M.t) (a : P.term array) ->
      let key (t : P.term) : P.term =
        match P.deref t with
        | P.Struct ("-", [ k; _ ]) -> k
        | P.Var _ -> raise (M.instantiation_error ())
        | t -> raise (M.type_error "pair" t) in
      M.unify m a.(1)
        (P.of_list (List.stable_sort (fun (x : P.term) (y : P.term) -> P.compare (key x) (key y)) (list_of a.(0)))));
  (* bagof's: the goal without its X^, and the variables it leaves free *)
  def "$bagof_split" 4 (fun (m : M.t) (a : P.term array) ->
      let rec strip (g : P.term) (bound : P.term list) : P.term * P.term list =
        match P.deref g with
        | P.Struct ("^", [ v; g ]) -> strip g (v :: bound)
        | g -> (g, bound) in
      let goal, bound = strip a.(1) [ a.(0) ] in
      let taken = P.variables (P.of_list bound) in
      let same (x : P.term) (y : P.term) : bool = P.compare x y = 0 in
      let free = List.filter (fun (v : P.term) -> not (List.exists (same v) taken)) (P.variables goal) in
      M.unify m a.(2) goal && M.unify m a.(3) (P.of_list free));

  (* the program *)
  def "assert" 1 (fun (m : M.t) (a : P.term array) -> M.add_clause m ~front:false a.(0); true);
  def "assertz" 1 (fun (m : M.t) (a : P.term array) -> M.add_clause m ~front:false a.(0); true);
  def "asserta" 1 (fun (m : M.t) (a : P.term array) -> M.add_clause m ~front:true a.(0); true);
  def "$clauses" 2 (fun (m : M.t) (a : P.term array) ->
      let clauses : P.term list =
        match P.deref a.(0) with
        | P.Var _ -> raise (M.instantiation_error ())
        | head -> (
            match Prolog_db.functor_of head with
            | None -> raise (M.type_error "callable" head)
            | Some (name, arity) -> (
                match M.find_pred m name arity with
                | None -> []
                | Some p ->
                    List.map
                      (fun (c : Prolog_db.clause) ->
                        Hashtbl.replace m.refs c.id (p, c);
                        let vars = Array.make c.nvars Prolog_db.unset in
                        let h = Prolog_db.instantiate vars c.head in
                        P.Struct ("$clause", [ h; Prolog_db.instantiate vars c.body; P.Int c.id ]))
                      (Prolog_db.clauses p))) in
      M.unify m a.(1) (P.of_list clauses));
  def "$erase" 1 (fun (m : M.t) (a : P.term array) ->
      match Hashtbl.find_opt m.refs (int_of a.(0)) with
      | Some (p, c) when not c.erased ->
          Prolog_db.erase p c;
          Hashtbl.remove m.refs c.id;
          true
      | _ -> false);
  def "$dynamic" 2 (fun (m : M.t) (a : P.term array) ->
      (M.pred m (atom_of a.(0)) (int_of a.(1))).dynamic <- true;
      true);
  def "abolish" 1 (fun (m : M.t) (a : P.term array) ->
      (match P.deref a.(0) with
       | P.Struct ("/", [ name; arity ]) -> (
           match M.find_pred m (atom_of name) (int_of arity) with
           | Some p ->
               p.clauses <- [];
               p.added <- []
           | None -> ())
       | t -> raise (M.type_error "predicate_indicator" t));
      true);
  def "$predicates" 1 (fun (m : M.t) (a : P.term array) ->
      let found : P.term list ref = ref [] in
      Hashtbl.iter
        (fun (_ : string) (proc : M.proc) ->
          match proc with
          | M.Pred p when p.dynamic || (match Prolog_db.clauses p with [] -> false | _ -> true) ->
              if not (String.length p.name > 0 && p.name.[0] = '$') then found := M.indicator p.name p.arity :: !found
          | _ -> ())
        m.procs;
      M.unify m a.(0) (P.of_list (List.sort P.compare !found)));
  def "$initialization" 1 (fun (m : M.t) (a : P.term array) -> m.inits <- P.copy a.(0) :: m.inits; true);
  def "consult" 1 (fun (m : M.t) (a : P.term array) ->
      (match P.to_list a.(0) with
       | Some files -> List.iter (fun (f : P.term) -> consult_file m (text f)) files
       | None -> consult_file m (text a.(0)));
      true);
  def "ensure_loaded" 1 (fun (m : M.t) (a : P.term array) -> consult_file m (text a.(0)); true);
  def "." 2 (fun (m : M.t) (a : P.term array) ->
      List.iter (fun (f : P.term) -> consult_file m (text f)) (list_of (P.cons a.(0) a.(1)));
      true);
  def "listing" 1 (fun (m : M.t) (a : P.term array) ->
      let name, arity =
        match P.deref a.(0) with
        | P.Struct ("/", [ name; arity ]) -> (atom_of name, Some (int_of arity))
        | t -> (atom_of t, None) in
      let found : Prolog_db.pred list ref = ref [] in
      Hashtbl.iter
        (fun (_ : string) (proc : M.proc) ->
          match proc with
          | M.Pred p when p.name = name && (match arity with Some n -> n = p.arity | None -> true) -> found := p :: !found
          | _ -> ())
        m.procs;
      List.iter
        (fun (p : Prolog_db.pred) ->
          if p.dynamic then m.print (Printf.sprintf ":- dynamic %s/%d.\n\n" (P.atom_text true p.name) p.arity);
          List.iter
            (fun (c : Prolog_db.clause) -> m.print (portray m (P.Struct (":-", [ c.head; c.body ]))))
            (Prolog_db.clauses p);
          m.print "\n")
        (List.sort (fun (p : Prolog_db.pred) (q : Prolog_db.pred) -> Int.compare p.arity q.arity) !found);
      true);
  def "portray_clause" 1 (fun (m : M.t) (a : P.term array) -> m.print (portray m a.(0)); true);
  def "op" 3 (fun (m : M.t) (a : P.term array) ->
      let priority = int_of a.(0) in
      let kind = atom_of a.(1) in
      let fixity : P.fixity =
        match P.fixity_of_string kind with Some f -> f | None -> raise (M.type_error "operator_specifier" a.(1)) in
      let names : P.term list = match P.to_list a.(2) with Some names -> names | None -> [ a.(2) ] in
      List.iter (fun (name : P.term) -> P.add_op m.ops priority fixity (atom_of name)) names;
      true);
  def "$ops" 1 (fun (m : M.t) (a : P.term array) ->
      let found : P.term list ref = ref [] in
      let collect (name : string) ((p, fixity) : int * P.fixity) : unit =
        found := P.Struct ("op", [ P.Int p; P.Atom (P.string_of_fixity fixity); P.Atom name ]) :: !found in
      Hashtbl.iter collect m.ops.prefix;
      Hashtbl.iter collect m.ops.infix;
      M.unify m a.(0) (P.of_list (List.sort P.compare !found)));

  (* input and output *)
  output "write" (fun (m : M.t) (t : P.term) -> P.to_string m.ops ~quoted:false t);
  output "print" show;
  output "writeq" show;
  output "write_canonical" show;
  output "writeln" (fun (m : M.t) (t : P.term) -> P.to_string m.ops ~quoted:false t ^ "\n");
  output "put_char" (fun (_ : M.t) (t : P.term) -> atom_of t);
  output "tab" (fun (_ : M.t) (t : P.term) -> String.make (max 0 (eval t)) ' ');
  def "nl" 0 (fun (m : M.t) (_ : P.term array) -> m.print "\n"; true);
  def "format" 1 (fun (m : M.t) (a : P.term array) -> m.print (format m (text a.(0)) []); true);
  def "format" 2 (fun (m : M.t) (a : P.term array) ->
      let args : P.term list = match P.to_list a.(1) with Some args -> args | None -> [ a.(1) ] in
      m.print (format m (text a.(0)) args);
      true);
  def "read" 1 (fun (m : M.t) (a : P.term array) ->
      let b = Buffer.create 80 in
      let rec lines () : P.term =
        match m.read_line () with
        | None -> if String.trim (Buffer.contents b) = "" then P.Atom "end_of_file" else parse ()
        | Some line ->
            Buffer.add_string b line;
            Buffer.add_char b '\n';
            if Prolog_read.complete (Buffer.contents b) then parse () else lines ()
      and parse () : P.term =
        match Prolog_read.next (Prolog_read.make m.ops (Buffer.contents b)) with
        | Some (t, _) -> t
        | None -> P.Atom "end_of_file"
        | exception Prolog_read.Error (msg, _) -> raise (syntax_error msg) in
      M.unify m a.(0) (lines ()));

  (* the system *)
  def "halt" 0 (fun (_ : M.t) (_ : P.term array) -> raise (M.Halt 0));
  def "halt" 1 (fun (_ : M.t) (a : P.term array) -> raise (M.Halt (int_of a.(0))));
  def "trace" 0 (fun (m : M.t) (_ : P.term array) -> m.trace <- true; m.depth <- 0; true);
  def "notrace" 0 (fun (m : M.t) (_ : P.term array) -> m.trace <- false; true);
  def "statistics" 2 (fun (m : M.t) (a : P.term array) ->
      match atom_of a.(0) with
      | "inferences" -> M.unify m a.(1) (P.Int m.steps)
      | "runtime" | "cputime" | "walltime" | "real_time" -> M.unify m a.(1) (P.of_list [ P.Int (m.clock ()); P.Int 0 ])
      | _ -> false);
  def "nb_setval" 2 (fun (m : M.t) (a : P.term array) -> Hashtbl.replace m.globals (atom_of a.(0)) (P.copy a.(1)); true);
  def "b_setval" 2 (fun (m : M.t) (a : P.term array) -> Hashtbl.replace m.globals (atom_of a.(0)) (P.copy a.(1)); true);
  let getval (m : M.t) (a : P.term array) : bool =
    match Hashtbl.find_opt m.globals (atom_of a.(0)) with
    | Some v -> M.unify m a.(1) (P.copy v)
    | None -> raise (M.error (P.Struct ("existence_error", [ P.Atom "variable"; a.(0) ]))) in
  def "nb_getval" 2 getval;
  def "b_getval" 2 getval;
  (* said and not done: what another Prolog's files ask at their top *)
  List.iter
    (fun ((name, arity) : string * int) -> def name arity (fun (_ : M.t) (_ : P.term array) -> true))
    [ ("use_module", 1); ("use_module", 2); ("set_prolog_flag", 2); ("style_check", 1); ("garbage_collect", 0);
      ("module", 2) ]

let create () : M.t =
  let m = M.create () in
  install m;
  let said = Buffer.create 80 in
  m.warn <- Buffer.add_string said;
  consult_text m "prelude" Prolog_prelude.text;
  if m.errors > 0 then failwith ("mini-prolog's prelude: " ^ Buffer.contents said);
  m.warn <- (fun (_ : string) -> ());
  m
