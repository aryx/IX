(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Run.mli *)
open Ast

type caps = Io.caps

exception Exit_program
(* the C's jumps: a cell every statement gives back to the one around it *)
exception Next_record
exception Next_file
exception Break_loop
exception Continue_loop
exception Return_value of cell

let status = ref ""
let position = ref 0

let fatal fmt = Printf.ksprintf (fun s -> raise (Cell.Fatal s)) fmt
let warning fmt = Printf.ksprintf (fun s -> !Cell.warning s) fmt

(* the call being run: its arguments' cells, then its locals' *)
let frame : cell array ref = ref [||]

let number f = Cell.temp (Cell.of_float f)
let text s = Cell.temp (Cell.of_string s)
let truth b = number (if b then 1. else 0.)

(* (an integer exponent by multiplications: pow is not always exact) *)
let rec ipow x n = if n <= 0 then 1. else let v = ipow x (n / 2) in if n mod 2 = 0 then v *. v else x *. v *. v

(* a library function's result: a warning and 1 for a NaN or an infinity *)
let errcheck x name =
  if x <> x then (warning "%s argument out of domain" name; 1.)
  else if x = infinity || x = neg_infinity then (warning "%s result out of range" name; 1.)
  else x

let power x y = if y >= 0. && Float.trunc y = y then ipow x (int_of_float y) else errcheck (x ** y) "pow"
let modulo x y = x -. (y *. Float.trunc (x /. y))

(* libc's frand: Mitchell and Reeds' additive generator, of 607 numbers
 * of 31 bits (floats here: a small machine's int has 31 bits in all) *)
let rng = Array.make 607 0.
let rng_tap = ref 0
let rng_feed = ref (607 - 273)
let seed = ref 1.

let srand s =
  let m = 2147483647. in
  let s = Float.rem (Float.trunc s) m in
  let x = ref (if s < 0. then s +. m else if s = 0. then 89482311. else s) in
  for k = -20 to 606 do
    let hi = Float.trunc (!x /. 44488.) in
    let lo = !x -. (hi *. 44488.) in
    x := (48271. *. lo) -. (3399. *. hi);
    if !x < 0. then x := !x +. m;
    if k >= 0 then rng.(k) <- !x
  done;
  rng_tap := 0;
  rng_feed := 607 - 273

let () = srand 1.

let lrand () =
  rng_tap := if !rng_tap = 0 then 606 else !rng_tap - 1;
  rng_feed := if !rng_feed = 0 then 606 else !rng_feed - 1;
  let x = rng.(!rng_feed) +. rng.(!rng_tap) in
  let x = if x >= 2147483648. then x -. 2147483648. else x in
  rng.(!rng_feed) <- x;
  x

let rec frand () =
  let norm = 1. /. 2147483648. in
  let x = lrand () *. norm in
  let x = (x +. lrand ()) *. norm in
  if x >= 1. then frand () else x

(* a character's other case: ASCII's and Latin-1's letters *)
let change_case upper s =
  let chars, rest = Utf8.chars s in
  let b = Buffer.create (String.length s) in
  List.iter (fun ch ->
    let c = Utf8.code ch in
    let lower_letter = (c >= 97 && c <= 122) || (c >= 0xE0 && c <= 0xFE && c <> 0xF7) in
    let upper_letter = (c >= 65 && c <= 90) || (c >= 0xC0 && c <= 0xDE && c <> 0xD7) in
    Utf8.add b (if upper && lower_letter then c - 32 else if (not upper) && upper_letter then c + 32 else c)) chars;
  Buffer.contents b ^ rest

(* an expression's regexps, compiled once each *)
let compiled : (string, Regex.t) Hashtbl.t = Hashtbl.create 16

let compile s =
  match Hashtbl.find_opt compiled s with
  | Some re -> re
  | None -> let re = Re.compile s in Hashtbl.replace compiled s re; re

(* sub's replacement: & is what matched, \& an &, \\& a \ then what matched *)
let replacement b repl matched =
  let n = String.length repl in
  let at k = if k < n then repl.[k] else '\000' in
  let rec go k =
    if k < n then
      if repl.[k] = '\\' then begin
        if at (k + 1) = '\\' then begin
          if at (k + 2) = '\\' && at (k + 3) = '&' then (Buffer.add_string b "\\&"; go (k + 4))
          else if at (k + 2) = '&' then (Buffer.add_char b '\\'; go (k + 2))
          else (Buffer.add_string b "\\\\"; go (k + 2))
        end
        else if at (k + 1) = '&' then (Buffer.add_char b '&'; go (k + 2))
        else (Buffer.add_char b '\\'; go (k + 1))
      end
      else if repl.[k] = '&' then (Buffer.add_string b matched; go (k + 1))
      else (Buffer.add_char b repl.[k]; go (k + 1)) in
  go 0

let rec eval (caps : < caps; .. >) (e : expr) : cell =
  match e with
  | Const c | Var c -> c
  | Arg n -> !frame.(n)
  | Nf -> Cell.build_fields (); Cell.nf
  | Field_of e ->
      let x = eval caps e in
      let m = int_of_float (Cell.getfval x) in
      if m = 0 && Cell.to_number (Cell.getsval x) = None then fatal "illegal field $(%s), name \"%s\"" (Cell.getsval x) x.name;
      Cell.field m
  | Elem (a, subs) ->
      let x = eval caps a in
      let key = subscript caps subs in
      Cell.install (Cell.array x) key Cell.unset
  | Assign (op, left, right) ->
      (* (the right side first) *)
      let y = eval caps right in
      let x = eval caps left in
      (match op with
       | Set ->
           (* x = x changes nothing, but of a field: the record is made again *)
           if not (x == y && (match x.kind with Field _ -> false | _ -> true)) then begin
             let v = Cell.value y in
             if v.num && v.str then begin
               let f = Cell.getfval y in
               let s = Cell.getsval y in
               Cell.setsval x s;
               x.v <- Scalar { num = true; str = true; f; s }
             end
             else if v.str then Cell.setsval x (Cell.getsval y)
             else Cell.setfval x (Cell.getfval y)
           end
       | Add_to | Sub_to | Mul_to | Div_to | Mod_to | Pow_to ->
           let xf = Cell.getfval x in
           let yf = Cell.getfval y in
           Cell.setfval x
             (match op with
              | Add_to -> xf +. yf
              | Sub_to -> xf -. yf
              | Mul_to -> xf *. yf
              | Div_to -> if yf = 0. then fatal "division by zero in /="; xf /. yf
              | Mod_to -> if yf = 0. then fatal "division by zero in %%="; modulo xf yf
              | Pow_to | Set -> power xf yf));
      x
  | Cond (c, yes, no) -> if test caps c then eval caps yes else eval caps no
  | Or _ | And _ | Not _ | Compare _ | Match _ | In _ -> truth (test caps e)
  | Getline (var, from) -> getline caps var from
  | Cat (a, b) ->
      let x = eval caps a in
      let y = eval caps b in
      let s = Cell.getsval x in
      text (s ^ Cell.getsval y)
  | Arith (op, a, b) ->
      let i = Cell.getfval (eval caps a) in
      let j = Cell.getfval (eval caps b) in
      number
        (match op with
         | Add -> i +. j
         | Sub_ -> i -. j
         | Mul -> i *. j
         | Div -> if j = 0. then fatal "division by zero"; i /. j
         | Mod -> if j = 0. then fatal "division by zero in mod"; modulo i j
         | Pow -> power i j)
  | Neg e -> number (-. (Cell.getfval (eval caps e)))
  | Step (e, delta, new_value) ->
      let x = eval caps e in
      let old = Cell.getfval x in
      Cell.setfval x (old +. delta);
      if new_value then x else number old
  | Builtin (f, args) -> builtin caps f args
  | Call (f, args) -> call caps f args
  | Index (a, b) ->
      let s = Cell.getsval (eval caps a) in
      let t = Cell.getsval (eval caps b) in
      let n = String.length s and m = String.length t in
      let rec find k = if k >= n then 0 else if k + m <= n && String.sub s k m = t then Utf8.length (String.sub s 0 k) + 1 else find (k + 1) in
      number (float_of_int (find 0))
  | Match_fn (e, re) ->
      let s = Cell.getsval (eval caps e) in
      let re = regex caps re in
      let start, len = match Re.find re s 0 with
        | Some (at, len) -> (Utf8.length (String.sub s 0 at) + 1, Utf8.length (String.sub s at len))
        | None -> (0, 0) in
      Cell.setfval Cell.rstart (float_of_int start);
      Cell.setfval Cell.rlength (float_of_int len);
      number (float_of_int start)
  | Split (e, arr, sep) -> split caps e arr sep
  (* (the C's string ends at a character 0: sprintf("%c", 0) is empty) *)
  | Sprintf args -> let s = format caps args in text (match String.index_opt s '\000' with Some k -> String.sub s 0 k | None -> s)
  | Sub (global, re, repl, target) -> substitute caps global re repl target
  | Substr (e, from, len) ->
      let x = eval caps e in
      let y = eval caps from in
      let z = Option.map (eval caps) len in
      let s = Cell.getsval x in
      let k = Utf8.length s + 1 in
      if k <= 1 then text ""
      else begin
        let m = max 1 (min k (int_of_float (Cell.getfval y))) in
        let n = match z with Some z -> int_of_float (Cell.getfval z) | None -> k - 1 in
        let n = max 0 (min (k - m) n) in
        text (Utf8.sub s (m - 1) n)
      end

(* is the expression true: for what is true or false by itself, at
 * once; any other is compared with the empty constant in the grammar *)
and test (caps : < caps; .. >) (e : expr) : bool =
  match e with
  | Or (a, b) -> test caps a || test caps b
  | And (a, b) -> test caps a && test caps b
  | Not e -> not (test caps e)
  | Compare (op, a, b) ->
      let x = eval caps a in
      let y = eval caps b in
      let vx = Cell.value x in
      let vy = Cell.value y in
      (* as numbers only if both have one *)
      let i =
        if vx.num && vy.num then (let j = vx.f -. vy.f in if j < 0. then -1 else if j > 0. then 1 else 0)
        else (let sx = Cell.getsval x in compare sx (Cell.getsval y)) in
      (match op with Lt -> i < 0 | Le -> i <= 0 | Ne -> i <> 0 | Eq -> i = 0 | Ge -> i >= 0 | Gt -> i > 0)
  | Match (negated, e, re) ->
      let s = Cell.getsval (eval caps e) in
      Re.matches (regex caps re) s <> negated
  | In (subs, arr) ->
      (* (the subscripts first: a split among them makes the array anew) *)
      let a = eval caps arr in
      let key = subscript caps subs in
      Cell.lookup (Cell.array a) key <> None
  | _ -> Cell.getfval (eval caps e) <> 0.

and regex (caps : < caps; .. >) (re : regex) =
  match re with Static re -> re | Dynamic e -> compile (Cell.getsval (eval caps e))

(* a[i, j]'s key: the subscripts with SUBSEP between them *)
and subscript (caps : < caps; .. >) subs =
  let sep = Cell.getsval Cell.subsep in
  String.concat sep (List.rev (List.fold_left (fun acc e -> Cell.getsval (eval caps e) :: acc) [] subs))

and getline (caps : < caps; .. >) var from =
  Io.flush Io.stdout;     (* in case someone is waiting for a prompt *)
  let n =
    match from with
    | Some (source, name) ->
        let x = eval caps name in
        (match Io.open_ caps (if source = From_command then Io.Command_in else Io.Read) (Cell.getsval x) with
         | None -> -1.
         | Some stream ->
             match Io.read_record stream with
             | None -> 0.
             | Some r ->
                 (match var with
                  | Some v -> Cell.setsval (eval caps v) r
                  (* (assigned, not read: END finds it) *)
                  | None -> Cell.setsval (Cell.field 0) r; (Cell.field 0).v <- Scalar (Cell.of_input r));
                 1.)
    | None ->
        match Io.next_record caps with
        | None -> if var = None then Cell.end_of_input (); 0.
        | Some r ->
            (match var with
             | Some v -> Cell.setsval (eval caps v) r
             | None -> Cell.set_record r);
            1. in
  number n

and builtin (caps : < caps; .. >) f args =
  let record = Field_of (Const Cell.zero) in
  let first, rest = match args with [] -> (record, []) | a :: rest -> (a, rest) in
  let x = eval caps first in
  let extra = ref rest in
  let result =
    match f with
    | Length -> (match x.v with Array t -> number (float_of_int t.count) | _ -> number (float_of_int (Utf8.length (Cell.getsval x))))
    | Log -> number (errcheck (log (Cell.getfval x)) "log")
    | Int -> number (Float.trunc (Cell.getfval x))
    | Exp -> number (errcheck (exp (Cell.getfval x)) "exp")
    | Sqrt -> number (errcheck (sqrt (Cell.getfval x)) "sqrt")
    | Sin -> number (sin (Cell.getfval x))
    | Cos -> number (cos (Cell.getfval x))
    | Atan2 ->
        (match rest with
         | [] -> warning "atan2 requires two arguments; returning 1.0"; number 1.
         | second :: more ->
             let y = eval caps second in
             extra := more;
             number (atan2 (Cell.getfval x) (Cell.getfval y)))
    | System -> number (float_of_int (Io.system caps (Cell.getsval x)))
    | Rand -> number (frand ())
    | Srand ->
        let s = if args = [] then Float.trunc (Unix.time ()) else Cell.getfval x in
        srand s;
        let old = !seed in
        seed := s;
        number old
    | Toupper -> text (change_case true (Cell.getsval x))
    | Tolower -> text (change_case false (Cell.getsval x))
    | Fflush ->
        if args = [] || Cell.getsval x = "" then (Io.flush_all (); number 0.)
        else (match Io.written (Cell.getsval x) with Some s -> Io.flush s; number 0. | None -> number (-1.))
    | Utf ->
        let b = Buffer.create 4 in
        let f = Cell.getfval x in
        Utf8.add b (if f <> f || f < 1. then 0 else if f > 1114111. then 0xFFFD else int_of_float f);
        text (Buffer.contents b) in
  (match f with
   | Toupper | Tolower | Utf -> ()
   | _ ->
       if !extra <> [] then begin
         warning "warning: function has too many arguments";
         List.iter (fun e -> ignore (eval caps e)) !extra
       end);
  result

(* a call: a scalar is given as a copy, an array as itself; the
 * parameters not given are the function's locals *)
and call (caps : < caps; .. >) (f : cell) args =
  let def = match f.v with Function def -> def | Scalar _ | Array _ -> fatal "calling undefined function %s" f.name in
  let given = List.length args in
  if given > def.params then warning "function %s called with %d args, uses only %d" f.name given def.params;
  let given = min given def.params in
  if def.params + given > 50 then fatal "function %s has %d arguments, limit %d" f.name (def.params + given) 50;
  let cells = Array.init def.params (fun _ -> Cell.temp { num = true; str = true; f = 0.; s = "" }) in
  (* the variable a copy was made of: if the function uses the copy
   * as an array, the variable is that array after the call *)
  let copied = Array.make def.params None in
  List.iteri (fun k arg ->
    if k < given then begin
      let y = eval caps arg in
      match y.v with
      | Function _ -> fatal "can't use function %s as argument in %s" y.name f.name
      | Array _ -> cells.(k) <- y
      | Scalar _ ->
          if y.kind = Temporary then cells.(k) <- y
          else (cells.(k) <- Cell.temp (Cell.value y); copied.(k) <- Some y)
    end) args;
  let caller = !frame in
  frame := cells;
  let leave () =
    frame := caller;
    Array.iteri (fun k (original : cell option) ->
      match original, cells.(k).v with
      | Some o, (Array _ as a) -> o.v <- a
      | _ -> ()) copied in
  let result =
    try exec caps def.body; Cell.temp { num = true; str = true; f = 0.; s = "" }
    with
    | Return_value v -> v
    | e -> leave (); raise e in
  leave ();
  result

and split (caps : < caps; .. >) e arr sep =
  let s = Cell.getsval (eval caps e) in
  let fs, re = match sep with
    | Default -> (Cell.getsval Cell.fs, None)
    | Sep_string e -> (Cell.getsval (eval caps e), None)
    | Sep_regex re -> ("(regexpr)", Some re) in
  let a = eval caps arr in
  let t = Cell.table () in
  a.v <- Array t;
  let n = String.length s in
  let count = ref 0 in
  let add piece =
    incr count;
    ignore (Cell.install t (string_of_int !count) (Scalar (Cell.of_input piece))) in
  let blank c = c = ' ' || c = '\t' || c = '\n' in
  if (n > 0 && String.length fs > 1) || re <> None then begin
    let re = match re with Some re -> re | None -> compile fs in
    let rec go from =
      match Re.find_nonempty re s from with
      | Some (start, len) ->
          add (String.sub s from (start - from));
          (* a separator at the very end: an empty last piece *)
          if start + len >= n then add "" else go (start + len)
      | None -> add (String.sub s from (n - from)) in
    go 0
  end
  else if fs = "" then begin
    let chars, rest = Utf8.chars s in
    List.iter add chars;
    if rest <> "" then add rest
  end
  else if fs.[0] = ' ' then begin
    let rec go k =
      let rec skip k = if k < n && blank s.[k] then skip (k + 1) else k in
      let start = skip k in
      if start < n then begin
        let rec word k = if k < n && not (blank s.[k]) then word (k + 1) else k in
        let stop = word start in
        add (String.sub s start (stop - start));
        go stop
      end in
    go 0
  end
  else if n > 0 then begin
    let rec go start k =
      if k >= n then add (String.sub s start (k - start))
      else if s.[k] = fs.[0] || s.[k] = '\n' then (add (String.sub s start (k - start)); go (k + 1) (k + 1))
      else go start (k + 1) in
    go 0 0
  end;
  number (float_of_int !count)

(* run.c's format: the first argument's text, each of its conversions
 * done by print's on the next argument *)
and format (caps : < caps; .. >) args =
  let fmt, args = match args with first :: rest -> (Cell.getsval (eval caps first), ref rest) | [] -> ("", ref []) in
  let n = String.length fmt in
  let b = Buffer.create (n + 32) in
  let next what =
    match !args with
    | a :: rest -> args := rest; eval caps a
    | [] -> fatal "not enough args in printf(%s)" what in
  let rec go k =
    if k < n then
      if fmt.[k] <> '%' then (Buffer.add_char b fmt.[k]; go (k + 1))
      else if k + 1 < n && fmt.[k + 1] = '%' then (Buffer.add_char b '%'; go (k + 2))
      else begin
        (* the conversion's text, to its letter; a * is the next argument *)
        let d = Buffer.create 8 in
        let letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') in
        let rec directive j =
          if j >= n then j
          else begin
            let c = fmt.[j] in
            if c = '*' then (Buffer.add_string d (string_of_int (int_of_float (Cell.getfval (next fmt)))); directive (j + 1))
            else if letter c && c <> 'l' && c <> 'h' && c <> 'L' then (Buffer.add_char d c; j)
            else (Buffer.add_char d c; directive (j + 1))
          end in
        let stop = directive k in
        let text = Buffer.contents d in
        let verb = if stop < n then fmt.[stop] else '\000' in
        let spec = Cformat.parse (if text = "" then "%" else text) in
        (match verb with
         | 'f' | 'e' | 'g' | 'E' | 'G' -> Buffer.add_string b (Cformat.float spec (Cell.getfval (next fmt)))
         | 'd' | 'i' -> Buffer.add_string b (Cformat.int { spec with verb = 'd' } (Cell.getfval (next fmt)))
         | 'u' | 'o' | 'x' | 'X' -> Buffer.add_string b (Cformat.int spec (Cell.getfval (next fmt)))
         | 's' | 'q' -> Buffer.add_string b (Cformat.string spec (Cell.getsval (next fmt)))
         | 'c' ->
             (* a number's character, or a string's first *)
             let x = next fmt in
             if (Cell.value x).num then begin
               (* (a negative number is 0, as the machine converts it) *)
               let f = Cell.getfval x in
               Utf8.add b (if f <> f || f < 1. then 0 else if f > 1114111. then 0xFFFD else int_of_float f)
             end
             else (match Utf8.chars (Cell.getsval x) with c :: _, _ -> Buffer.add_string b c | [], rest -> Buffer.add_string b rest)
         | _ ->
             warning "weird printf conversion %s" text;
             Buffer.add_string b text;
             Buffer.add_string b (Cell.getsval (next fmt)));
        go (stop + 1)
      end in
  go 0;
  (* (the arguments left are evaluated all the same) *)
  List.iter (fun a -> ignore (eval caps a)) !args;
  Buffer.contents b

and substitute (caps : < caps; .. >) global re repl target =
  let x = eval caps target in
  let t = Cell.getsval x in
  let re = regex caps re in
  let y = eval caps repl in
  let n = String.length t in
  let b = Buffer.create (n + 16) in
  if not global then begin
    match Re.find re t 0 with
    | None -> truth false
    | Some (start, len) ->
        Buffer.add_string b (String.sub t 0 start);
        replacement b (Cell.getsval y) (String.sub t start len);
        Buffer.add_string b (String.sub t (start + len) (n - start - len));
        Cell.setsval x (Buffer.contents b);
        truth true
  end else begin
    let count = ref 0 in
    (match Re.find re t 0 with
     | None -> ()
     | Some first ->
         let repl = Cell.getsval y in
         (* c: where the text is copied from; after a match that was not
          * empty, an empty one at the same place is not replaced *)
         let rec go (start, len) c after_match =
           let again c after_match = match Re.find re t c with Some m -> go m c after_match | None -> c in
           if len = 0 && start < n then begin
             if not after_match then (incr count; replacement b repl "");
             if c >= n then c
             else (Buffer.add_char b t.[c]; again (c + 1) false)
           end else begin
             incr count;
             Buffer.add_string b (String.sub t c (start - c));
             replacement b repl (String.sub t start len);
             let c = start + len in
             if c >= n then c else again c true
           end in
         let c = go first 0 false in
         Buffer.add_string b (String.sub t c (n - c));
         Cell.setsval x (Buffer.contents b));
    number (float_of_int !count)
  end

and exec (caps : < caps; .. >) (s : stmt) : unit =
  match s with
  | At (offset, s) -> position := offset; exec caps s
  (* (a name or a constant alone is no statement: the C finds no code to run for it) *)
  | Expr (Var _ | Const _) -> fatal "illegal statement"
  | Expr e -> ignore (eval caps e)
  | Print (args, out) ->
      let stream = redirect caps out in
      let rec go = function
        | [] -> ()
        | [ last ] -> Io.write stream (Cell.getsval (eval caps last)); Io.write stream (Cell.getsval Cell.ors)
        | a :: rest -> Io.write stream (Cell.getsval (eval caps a)); Io.write stream (Cell.getsval Cell.ofs); go rest in
      go args;
      Io.flush stream
  | Printf (args, out) ->
      let s = format caps args in
      let stream = redirect caps out in
      Io.write stream s;
      if not (Io.is_stdout stream) then Io.flush stream
  | Delete (a, subs) ->
      let x = eval caps a in
      (match x.v, subs with
       | Array _, None -> x.v <- Array (Cell.table ())
       | Array t, Some subs -> Cell.remove t (subscript caps subs)
       | (Scalar _ | Function _), _ -> ())
  | Close e -> Io.close caps (Cell.getsval (eval caps e))
  | If (cond, yes, no) -> if test caps cond then exec caps yes else Option.iter (exec caps) no
  | While (cond, body) -> (try while test caps cond do loop_body caps body done with Break_loop -> ())
  | Do (body, cond) ->
      (* (a nextfile is a continue in a while and a for, not here) *)
      let rec go () = (try exec caps body with Continue_loop -> ()); if test caps cond then go () in
      (try go () with Break_loop -> ())
  | For (init, cond, step, body) ->
      Option.iter (exec caps) init;
      (try
         while (match cond with Some c -> test caps c | None -> true) do
           (try exec caps body with Continue_loop | Next_file -> ());
           Option.iter (exec caps) step
         done
       with Break_loop -> ())
  | For_in (var, arr, body) ->
      let v = eval caps var in
      let a = eval caps arr in
      (match a.v with
       | Array t ->
           (try Cell.iter t (fun (c : cell) -> Cell.setsval v c.name; (try exec caps body with Continue_loop | Next_file -> ()))
            with Break_loop -> ())
       | Scalar _ | Function _ -> ())
  | Block stmts -> List.iter (exec caps) stmts
  | Break -> raise Break_loop
  | Continue -> raise Continue_loop
  | Next -> raise Next_record
  | Nextfile -> Io.next_file (); raise Next_file
  | Exit e ->
      Option.iter (fun e ->
        let y = eval caps e in
        let v = Cell.value y in
        if v.str && not v.num then status := Cell.getsval y
        else if int_of_float (Cell.getfval y) <> 0 then status := "error") e;
      raise Exit_program
  | Return e ->
      let result = Cell.temp { num = true; str = true; f = 0.; s = "" } in
      Option.iter (fun e ->
        let y = eval caps e in
        let v = Cell.value y in
        if v.num && v.str then (let f = Cell.getfval y in result.v <- Scalar { num = true; str = true; f; s = Cell.getsval y })
        else if v.str then Cell.setsval result (Cell.getsval y)
        else Cell.setfval result (Cell.getfval y)) e;
      raise (Return_value result)

and loop_body (caps : < caps; .. >) body =
  try exec caps body with Continue_loop | Next_file -> ()

and redirect (caps : < caps; .. >) out =
  match out with
  | None -> Io.stdout
  | Some (how, name) ->
      let name = Cell.getsval (eval caps name) in
      let mode = match how with To_file -> Io.Write | Append -> Io.Append | To_command -> Io.Command_out in
      match Io.open_ caps mode name with Some s -> s | None -> fatal "can't open file %s" name

let run (caps : < caps; .. >) (p : program) =
  let stray () = fatal "illegal break, continue, next or nextfile from BEGIN" in
  let exited =
    try List.iter (exec caps) p.begins; false
    with
    | Exit_program -> true
    | Next_record | Next_file | Break_loop | Continue_loop -> stray () in
  if (not exited) && (p.rules <> [] || p.ends <> []) then begin
    let rule (r : rule) =
      match r with
      | Always s -> exec caps s
      | When (pattern, s) -> if test caps pattern then exec caps s
      | Range (first, last, s, inside) ->
          if (not !inside) && test caps first then inside := true;
          if !inside then begin
            if test caps last then inside := false;
            exec caps s
          end in
    let rec records () =
      match Io.next_record caps with
      | None -> Cell.end_of_input ()
      | Some r ->
          Cell.set_record r;
          (try List.iter rule p.rules with Next_record | Next_file -> ());
          records () in
    try records () with Exit_program -> ()
  end;
  (try List.iter (exec caps) p.ends
   with
   | Exit_program -> ()
   | Next_record | Break_loop | Continue_loop -> fatal "illegal break, continue, next or nextfile from END");
  Io.close_all caps
