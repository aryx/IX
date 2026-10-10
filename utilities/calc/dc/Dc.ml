(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dc.mli *)

type caps = < Cap.stdin; Cap.stdout; Cap.open_in; Cap.fork; Cap.exec; Cap.wait >

exception Quit
(* a fed text's end *)
exception End_of_text

(* a register's array: an element not yet stored is None *)
type value = Number of Num.t * int | Text of string | Array of value option array

(* {2 A value as the C's bytes, and back} *)

let signed c = let b = Char.code c in if b >= 128 then b - 256 else b

let bytes v =
  match v with
  | Number (m, scale) -> Num.encode m ^ String.make 1 (Char.chr (scale land 255))
  | Text s -> s
  | Array _ -> ""

(* its integer and its scale: the bytes but the last, and the last *)
let number v =
  match v with
  | Number (m, scale) -> (m, scale)
  | Array _ -> (Num.zero, 0)
  | Text s ->
      let n = String.length s in
      if n = 0 then (Num.zero, 0) else (Num.decode (String.sub s 0 (n - 1)), signed s.[n - 1])

let ten = Num.of_int 10

(* {2 The machine} *)

let stack : value list ref = ref []
let max_stack = 100

(* a register: the values saved under its name, the last first *)
let registers : value list array = Array.make 256 []
(* the names from 221 on are arrays (bc's: a letter's array is 220 + its rank) *)
let first_array = 221
let max_index = 2048

let scale = ref 0                       (* k *)
(* what K gives: k as it was set (at first a 0 with a byte: see print_value) *)
let scale_value = ref (Text "\000\000")
let input_base = ref ten
let output_base = ref ten
(* the output base as a long, its logarithm, and how its digits are
 * printed: each a character up to 16, else a decimal number of a
 * fixed width *)
let obase = ref 10
let log_obase = ref 3
let small_digits = ref true
let width = ref 1
let line_length = ref 70

let out = Buffer.create 256
let print s = Buffer.add_string out s

let push v = if List.length !stack >= max_stack then print "out of stack space\n" else stack := v :: !stack

let pop () =
  match !stack with
  | v :: rest -> stack := rest; Some v
  | [] -> None

(* {2 The input: the macros being run, then the files} *)

(* a macro and how far it was read *)
let macros : (string * int ref) list ref = ref []
let max_macros = 100

(* a file, read a character at a time, one given back at most *)
type source = { next : unit -> int; mutable back : int option }
let sources : source list ref = ref []
let stdin_source : source option ref = ref None

let read_source (s : source) =
  match s.back with
  | Some c -> s.back <- None; c
  | None -> s.next ()

let rec readc () =
  match !macros with
  | (text, pos) :: rest ->
      (* (a macro's character is a C char: a byte over 127 is negative, and -1 is passed as the input's end is) *)
      if !pos < String.length text then (incr pos; signed text.[!pos - 1])
      else (macros := rest; readc ())
  | [] ->
      match !sources with
      | [] -> raise Quit
      | s :: rest ->
          let c = read_source s in
          if c >= 0 then c else (sources := rest; if rest = [] then raise End_of_text else readc ())

let unreadc c =
  match !macros, !sources with
  | (_, pos) :: _, _ -> decr pos
  | [], s :: _ -> if c >= 0 then s.back <- Some c
  | [], [] -> ()

let of_fd fd =
  let buf = Bytes.create 8192 and pos = ref 0 and len = ref 0 in
  let rec next () =
    if !pos < !len then (incr pos; Char.code (Bytes.get buf (!pos - 1)))
    else match Unix.read fd buf 0 8192 with
      | 0 -> -1
      | n -> pos := 0; len := n; next ()
      | exception Unix.Unix_error _ -> -1 in
  { next; back = None }

let of_string text =
  let pos = ref 0 in
  { next = (fun () -> if !pos < String.length text then (incr pos; Char.code text.[!pos - 1]) else -1); back = None }

(* a register's name: a character, or <221>, a number *)
let register () =
  let c = readc () land 255 in
  if c <> Char.code '<' then c
  else begin
    let rec digits n = let c = readc () land 255 in if c = Char.code '>' then n else digits ((n * 10) + c - 48) in
    digits 0 land 255
  end

(* {2 Arithmetic, with dc.c's rules for the scales} *)

(* the integer cut of its n last decimal digits, as dc.c's removc does
 * it: whole bytes dropped from the complement of a negative number
 * (toward the smaller one), then a division by 10 (toward 0) *)
let removc m n =
  let b = Num.encode m in
  let drop = n / 2 in
  let m = if drop >= String.length b then Num.zero else Num.decode (String.sub b drop (String.length b - drop)) in
  if n mod 2 = 1 then fst (Num.divmod m ten) else m

(* the integer part of a value *)
let integer v = let m, sc = number v in removc m sc

let times10 m n = Num.mul m (Num.pow10 n)

(* a number read: digits (A to F too) in the input base, and a point *)
let read_number () =
  let rec go m point decimals =
    let c = readc () in
    let digit d =
      let counted = point && decimals < 99 in
      if point && not counted then go m point decimals
      else go (Num.add (Num.mul m !input_base) (Num.of_int d)) point (if counted then decimals + 1 else decimals) in
    if c = Char.code '.' && not point then go m true decimals
    else if c = Char.code '\\' then (ignore (readc ()); go m point decimals)
    else if c >= Char.code 'A' && c <= Char.code 'F' then digit (c - 55)
    else if c >= Char.code '0' && c <= Char.code '9' then digit (c - 48)
    else begin
      unreadc c;
      if not point then Number (m, 0)
      else Number (fst (Num.divmod (times10 m decimals) (Num.pow !input_base decimals)), decimals)
    end in
  go Num.zero false 0

(* the two values on top, at the same scale *)
let aligned () =
  match pop () with
  | None -> print "stack empty\n"; None
  | Some p ->
      match pop () with
      | None -> push p; print "stack empty\n"; None
      | Some q ->
          let mp, sp = number p and mq, sq = number q in
          if sp < sq then Some (times10 mp (sq - sp), mq, sq) else Some (mp, times10 mq (sp - sq), sp)

let add () = match aligned () with Some (p, q, sc) -> push (Number (Num.add p q, sc)); true | None -> false

let subtract () =
  match pop () with
  | None -> print "stack empty\n"; false
  | Some v -> let m, sc = number v in push (Number (Num.neg m, sc)); add ()

(* a division's operands: the dividend given the digits the scale
 * asks, or cut of those it has too many (what was cut is kept: the
 * remainder's end) *)
let division () =
  match pop () with
  | None -> print "stack empty\n"; None
  | Some divisor ->
      match pop () with
      | None -> print "stack empty\n"; push divisor; None
      | Some dividend ->
          let md, skd = number dividend and mr, skr = number divisor in
          if Num.is_zero mr then (push divisor; print "divide by 0\n"; None)
          else if Num.is_zero md then (push dividend; None)
          else begin
            let c = !scale - skd + skr in
            if c >= 0 then Some (times10 md c, mr, skd, skr, None)
            else begin
              let q, r = Num.divmod md (Num.pow10 (-c)) in
              Some (q, mr, skd, skr, Some r)
            end
          end

let divide () =
  match division () with
  | Some (a, b, _, _, _) -> push (Number (fst (Num.divmod a b), !scale))
  | None -> ()

(* {2 Printing} *)

(* the characters left on the line: a number goes on after a \ *)
let count = ref 70
let outc c = Buffer.add_char out c; decr count; if !count = 0 then (print "\\\n"; count := !line_length)
let test2 () = count := !count - 2; if !count <= 0 then (print "\\\n"; count := !line_length)

(* in base 10: the digits two at a time, the point where the scale says *)
let print_decimal (d : int array) sc =
  let r = ref (Array.length d) in
  let next () = decr r; d.(!r) in
  let two c = print (Printf.sprintf "%02d" c) in
  let first = ref true in
  while !r > 0 && (!r - 1) * 2 >= sc do
    let c = next () in
    if !first then print (string_of_int c) else two c;
    first := false;
    test2 ()
  done;
  if sc > 0 then begin
    let sc = ref sc in
    if !r * 2 > !sc then begin
      let c = next () in
      print (Printf.sprintf "%d." (c / 10)); test2 (); outc (Char.chr (48 + (c mod 10))); decr sc
    end else outc '.';
    while !sc > !r * 2 do outc '0'; decr sc done;
    while !sc > 1 do two (next ()); sc := !sc - 2; test2 () done;
    if !sc = 1 then outc (Char.chr (48 + (next () / 10)))
  end;
  print "\n"

let decimal_digits m = let s = String.concat "" (List.rev_map (Printf.sprintf "%02d") (Array.to_list (Num.digits m))) in
  let rec strip k = if k < String.length s - 1 && s.[k] = '0' then strip (k + 1) else k in
  if Num.is_zero m then "" else String.sub s (strip 0) (String.length s - strip 0)

let print_value v =
  let b = bytes v in
  let n = String.length b in
  if String.exists (fun c -> signed c > 99) b then (print b; print "\n")
  else if n <= 1 then print "0\n"
  else begin
    let m = Num.decode (String.sub b 0 (n - 1)) and sc = signed b.[n - 1] in
    count := !line_length;
    let negative = Num.is_neg m in
    let m = if negative then (outc '-'; Num.neg m) else m in
    (* (its bytes as they are: a 0 that has a byte prints as 0) *)
    let raw = if negative then Num.digits m else Array.init (n - 1) (fun k -> Char.code b.[k]) in
    (* base 0 and -1, and 1: as many characters as the number *)
    let unary ch = for _i = 1 to Num.to_int (removc m sc) do outc ch done; print "\n" in
    if !obase = 0 || !obase = -1 then unary 'd'
    else if !obase = 1 then unary '1'
    else if !obase = 10 then print_decimal raw sc
    (* a 0 with a byte (K's at first, z's, Z's, X's) in another base: the
     * C's division finds a dividend of 0 and leaves it on the stack,
     * nothing printed *)
    else if b.[n - 2] = '\000' then push (Text b)
    else begin
      (* the number at the scale k, whatever its own *)
      let c = !scale - sc in
      let m = if c >= 0 then times10 m c else fst (Num.divmod m (Num.pow10 (-c))) in
      let sc = !scale in
      let unit_ = Num.pow10 sc in
      let whole, frac = Num.divmod m unit_ in
      let b = Buffer.create 64 in
      (* a digit of the integer part (they come the lowest first, and
       * are printed from the buffer's end) or of the fraction *)
      let digit (d : Num.t) fraction =
        if !small_digits then begin
          let c = if Num.is_zero d then 0 else (Num.digits d).(0) in
          if c >= 16 then print "hex digit > 16" else Buffer.add_char b (if c < 10 then Char.chr (48 + c) else Char.chr (87 + c))
        end else begin
          let text = decimal_digits (if Num.is_neg d then Num.neg d else d) in
          let pad = !width - 1 - String.length text - (if Num.is_neg d then 1 else 0) in
          if fraction then begin
            if Num.is_neg d then Buffer.add_char b '-';
            Buffer.add_string b (String.make (max 0 pad) '0');
            Buffer.add_string b text
          end else begin
            String.iter (Buffer.add_char b) (String.init (String.length text) (fun k -> text.[String.length text - 1 - k]));
            Buffer.add_string b (String.make (max 0 pad) '0');
            if Num.is_neg d then Buffer.add_char b '-'
          end;
          Buffer.add_char b ' '
        end in
      let rec integer_part m = if not (Num.is_zero m) then (let q, r = Num.divmod m !output_base in digit r false; integer_part q) in
      integer_part whole;
      let s = Buffer.contents b in
      for k = String.length s - 1 downto 0 do outc s.[k] done;
      if sc > 0 then begin
        Buffer.clear b;
        outc '.';
        let digits = ((3 * sc / 10) + (3 * sc)) / !log_obase in
        let rec fraction frac ct =
          let whole, frac = Num.divmod (Num.mul !output_base frac) unit_ in
          digit whole true;
          if ct + 1 < digits then fraction frac (ct + 1) in
        fraction frac 0;
        String.iter outc (Buffer.contents b)
      end;
      print "\n"
    end
  end

(* dc.c's log2_: of a long of 32 bits *)
let log2 n = if n = 0 then 0 else if n < 0 then 31 else (let rec high k = if n lsr (k + 1) = 0 then k else high (k + 1) in high 0)

(* {2 Registers and conditions} *)

(* the value a register holds, copied; of one never set: 0, or for a
 * name bc gives a function, what stops the program that calls it *)
let load () =
  let c = register () in
  match registers.(c) with
  | Array a :: _ -> push (Array (Array.copy a))
  | v :: _ -> push v
  | [] ->
      if c <= 22 then (print (Printf.sprintf "function %c undefined\n" (Char.chr (c + 96))); push (Text "c0 1Q"))
      else push (Text "\000")

(* a comparison of the two values on top: is the register named after
 * it to be run ('!' before: the comparison's opposite) *)
let condition c negated =
  if not (subtract ()) then true
  else begin
    let m, _ = match pop () with Some v -> number v | None -> (Num.zero, 0) in
    let skip () = ignore (register ()); false in
    let take () = load (); true in
    if Num.is_zero m then (if negated || c <> '=' then (if negated && c <> '=' then take () else skip ()) else take ())
    else if c = '=' then (if negated then take () else skip ())
    else begin
      let below = Num.is_neg m in
      if (below && ((c = '<' && not negated) || (c = '>' && negated))) || ((not below) && ((c = '>' && not negated) || (c = '<' && negated))) then skip ()
      else take ()
    end
  end

(* an index: an integer from 0, below 2048 *)
let index v =
  let m = integer v in
  if Num.is_neg m then (print "neg index\n"; None)
  else if Array.length (Num.digits m) > 2 || Num.to_int m >= max_index then (print "index too big\n"; None)
  else Some (Num.to_int m)

(* {2 The commands} *)

let execute v =
  (* (a macro that ended is not kept under the one it called last) *)
  (match !macros with (text, pos) :: rest when !pos >= String.length text -> macros := rest | _ -> ());
  if List.length !macros >= max_macros then print "nesting depth\n" else macros := (bytes v, ref 0) :: !macros

let shell (caps : < caps; .. >) line =
  Console.print caps (Buffer.contents out); flush stdout; Buffer.clear out;
  let pid = Procs.spawn caps "/bin/rc" [ "-c"; line ] ~stdin:(Console.stdin_fd caps) ~stdout:(Console.stdout_fd caps) in
  ignore (Procs.waitpid caps pid);
  print "!\n"

(* a line of the standard input, as a macro; a ! at its start is a command *)
let rec query (caps : < caps; .. >) =
  match !stdin_source with
  | None -> ()
  | Some s ->
      let c = read_source s in
      if c < 0 then raise Quit
      else if c = Char.code '!' then (bang caps (fun () -> read_source s); query caps)
      else begin
        let b = Buffer.create 64 in
        let rec line c =
          if c >= 0 && c <> Char.code '\n' then begin
            Buffer.add_char b (Char.chr c);
            if c = Char.code '\\' then (let c = read_source s in if c >= 0 then Buffer.add_char b (Char.chr c));
            line (read_source s)
          end in
        line c;
        if List.length !macros >= max_macros then print "nesting depth\n" else macros := (Buffer.contents b, ref 0) :: !macros
      end

(* after a !: a comparison's opposite, or a command for the shell *)
and bang (caps : < caps; .. >) next =
  let c = next () in
  if c = Char.code '<' || c = Char.code '>' || c = Char.code '=' then begin
    if condition (Char.chr c) true then (match pop () with Some v -> execute v | None -> print "stack empty\n")
  end else begin
    let b = Buffer.create 64 in
    let rec line c = if c >= 0 && c <> Char.code '\n' then (Buffer.add_char b (Char.chr c); line (next ())) in
    line c;
    shell caps (Buffer.contents b)
  end

let command (caps : < caps; .. >) c =
  let empty () = print "stack empty\n" in
  if c < -1 then print (Printf.sprintf "%lo is unimplemented\n" (Int32.of_int c))
  else match Char.chr (c land 255) with
  | ' ' | '\t' | '\n' -> ()
  | '+' -> ignore (add ())
  | '-' -> ignore (subtract ())
  | '*' ->
      (match pop () with
       | None -> empty ()
       | Some a ->
           match pop () with
           | None -> push a; empty ()
           | Some b ->
               let ma, sa = number a and mb, sb = number b in
               let m = Num.mul ma mb and total = (sa + sb) land 255 in
               (* no more digits than the scale, or than the operands had *)
               if total > !scale && total > sa && total > sb then begin
                 let sc = max sa (max sb !scale) in
                 push (Number (removc m (total - sc), sc))
               end else push (Number (m, total)))
  | '/' -> divide ()
  | '%' ->
      (match division () with
       | None -> ()
       | Some (a, b, skd, skr, cut) ->
           let r = snd (Num.divmod a b) in
           match cut with
           | None -> push (Number (r, skr + !scale))
           | Some cut -> push (Number (Num.add (times10 r (skd - (skr + !scale))) cut, skd)))
  | '_' ->
      (match read_number () with Number (m, sc) -> push (Number (Num.neg m, sc)) | v -> push v)
  | '^' ->
      (match pop () with
       | None -> empty ()
       | Some e ->
           let me, se = number e in
           if se <> 0 then print "exp not an integer\n"
           else match pop () with
             (* (given back without its scale: the C has taken it off) *)
             | None -> push (Text (Num.encode me)); empty ()
             | Some base ->
                 let negative = Num.is_neg me in
                 let me = if negative then Num.neg me else me in
                 if Array.length (Num.digits me) >= 3 then print "exp too big\n"
                 else begin
                   let mb, sb = number base in
                   let n = Num.to_int me in
                   let p = Num.pow mb n in
                   let d = n * sb and keep = max !scale sb in
                   let result = if keep < d then Number (removc p (d - keep), keep) else Number (p, d) in
                   if not negative then push result
                   else (push (Number (Num.of_int 1, 0)); push result; divide ())
                 end)
  | '<' | '>' | '=' -> if condition (Char.chr c) false then (match pop () with Some v -> execute v | None -> empty ())
  | '[' ->
      let b = Buffer.create 64 in
      let rec go depth =
        let c = readc () in
        if c = Char.code ']' && depth = 0 then ()
        else begin
          Buffer.add_char b (Char.chr (c land 255));
          go (if c = Char.code '[' then depth + 1 else if c = Char.code ']' then depth - 1 else depth)
        end in
      go 0;
      push (Text (Buffer.contents b))
  | 'q' -> (match !macros with _ :: _ :: rest -> macros := rest | _ -> raise Quit)
  | 'p' -> (match !stack with v :: _ -> print_value v | [] -> print "empty stack\n")
  | 'P' ->
      (match pop () with
       | None -> empty ()
       | Some v -> let s = bytes v in print (match String.index_opt s '\000' with Some k -> String.sub s 0 k | None -> s))
  | 'Y' -> ()
  | 'v' ->
      (match pop () with
       | None -> empty ()
       | Some v ->
           let m, sc = number v in
           if Num.is_zero m then push v
           else if Num.is_neg m then print "sqrt of neg number\n"
           else if !scale < sc then push (Number (Num.sqrt (times10 m sc), sc))
           else push (Number (Num.sqrt (times10 m ((!scale * 2) - sc)), !scale)))
  (* (the C's bytes: 0 is a byte, and 100 has its two the wrong way) *)
  | 'z' -> let n = List.length !stack in push (Text (if n >= 100 then "\001\000\000" else String.make 1 (Char.chr n) ^ "\000"))
  | 'Z' ->
      (match pop () with
       | None -> empty ()
       | Some v ->
           (* how many decimal digits, from the bytes: dc.c's count *)
           let b = bytes v in
           let len = String.length b in
           let n = ref ((len - 1) * 2) in
           if len > 1 then begin
             let c = signed b.[len - 2] in
             if c < 0 then begin
               n := !n - 2;
               if len = 2 then incr n
               else (let c = signed b.[len - 3] in if c = 0 then incr n else if c > 90 then decr n)
             end else if c < 10 then decr n
           end;
           let n = max 0 !n in
           push (Text ((if n >= 100 then String.make 1 (Char.chr (n mod 100)) ^ String.make 1 (Char.chr (n / 100 land 255)) else String.make 1 (Char.chr n)) ^ "\000")))
  | 'i' -> (match pop () with None -> empty () | Some v -> input_base := integer v)
  | 'I' -> push (Number (!input_base, 0))
  | 'o' ->
      (match pop () with
       | None -> empty ()
       | Some v ->
           let m = integer v in
           let b = Num.encode m in
           let n = String.length b in
           output_base := m;
           line_length := 70;
           if n = 1 && signed b.[0] <= 16 then begin
             obase := signed b.[0];
             log_obase := log2 !obase;
             small_digits := true;
             width := 1
           end else begin
             (* (the base 0 is given as 1: its bytes are none) *)
             let l = if n = 0 then -1 else Num.to_int (if Num.is_neg m then Num.neg m else m) in
             let negative = n = 0 || Num.is_neg m in
             log_obase := log2 l;
             obase := (if negative then - l else l);
             small_digits := false;
             (* its digits' width: that of the base less 1, in decimal *)
             let largest = Num.encode (Num.add (if Num.is_neg m then Num.neg m else m) (Num.of_int (-1))) in
             let w = (if negative then 1 else 0) + (String.length largest * 2)
                     + (if largest <> "" && signed largest.[String.length largest - 1] > 9 then 1 else 0) in
             width := w;
             if w > 0 && w < 70 then line_length := 70 / w * w
           end)
  | 'O' -> push (Number (!output_base, 0))
  | 'k' ->
      (match pop () with
       | None -> empty ()
       | Some v ->
           let m = integer v in
           let b = Num.encode m in
           if String.length b > 1 then print "scale too big\n"
           else (scale := (if b = "" then 0 else signed b.[0]); scale_value := Number (m, 0)))
  | 'K' -> push !scale_value
  | 'X' ->
      (match pop () with
       | None -> empty ()
       | Some v -> let b = bytes v in push (Text (String.make 1 (if b = "" then '\255' else b.[String.length b - 1]) ^ "\000")))
  | 'Q' ->
      (match pop () with
       | None -> empty ()
       | Some v ->
           let b = bytes v in
           if String.length b > 2 then print "Q?\n"
           else if b = "" || signed b.[0] < 0 then print "neg Q\n"
           else begin
             (* (said for each level there is not) *)
             let rec leave n = if n > 0 then ((match !macros with _ :: rest -> macros := rest | [] -> print "readstk?\n"); leave (n - 1)) in
             leave (signed b.[0])
           end)
  | 'f' -> (match !stack with [] -> print "empty stack\n" | values -> List.iter print_value values)
  | 'd' -> (match !stack with v :: _ -> push v | [] -> print "empty stack\n")
  | 'c' -> stack := []
  | 'S' ->
      if !stack = [] then print "save: args\n"
      else begin
        let c = register () in
        match pop () with
        | None -> empty ()
        | Some v -> registers.(c) <- (if c >= first_array then (match v with Array _ -> v | _ -> Array [||]) else v) :: registers.(c)
      end
  | 's' ->
      if !stack = [] then print "save:args\n"
      else begin
        let c = register () in
        match pop () with
        | None -> empty ()
        | Some v -> registers.(c) <- v :: (match registers.(c) with _ :: rest -> rest | [] -> [])
      end
  | 'l' -> load ()
  | 'L' ->
      let c = register () in
      (match registers.(c) with
       | v :: rest -> registers.(c) <- rest; push v
       | [] -> print "L?\n")
  | ':' ->
      (match pop () with
       | None -> empty ()
       | Some i ->
           match index i with
           | None -> ()
           | Some i ->
               let c = register () in
               let a = match registers.(c) with Array a :: _ -> a | _ -> [||] in
               let a = if i < Array.length a then a else Array.init (i + 1) (fun k -> if k < Array.length a then a.(k) else None) in
               registers.(c) <- Array a :: (match registers.(c) with _ :: rest -> rest | [] -> []);
               match pop () with
               | None -> empty ()
               | Some v -> a.(i) <- Some v)
  | ';' ->
      (match pop () with
       | None -> empty ()
       | Some i ->
           match index i with
           | None -> ()
           | Some i ->
               let c = register () in
               match registers.(c) with
               | Array a :: _ when i < Array.length a && a.(i) <> None -> Option.iter push a.(i)
               | _ -> push (Text "\000"))
  | 'x' -> (match pop () with Some v -> execute v | None -> empty ())
  | '?' -> query caps
  | '!' -> bang caps readc
  | _ -> print (Printf.sprintf "%lo is unimplemented\n" (Int32.of_int c))

let flush_out (caps : < caps; .. >) =
  if Buffer.length out > 0 then begin
    let o = Console.stdout caps in
    output_string o (Buffer.contents out);
    flush o;
    Buffer.clear out
  end

let commands (caps : < caps; .. >) =
  let rec loop () =
    flush_out caps;
    let c = readc () in
    if (c >= Char.code '0' && c <= Char.code '9') || (c >= Char.code 'A' && c <= Char.code 'F') || c = Char.code '.' then (unreadc c; push (read_number ()))
    else if c <> -1 then command caps c;
    loop () in
  try loop () with e -> flush_out caps; raise e

let feed (caps : < caps; .. >) text =
  if !stdin_source = None then stdin_source := Some (of_fd (Console.stdin_fd caps));
  sources := [ of_string text ];
  try commands caps with End_of_text -> sources := []

let run (caps : < caps; .. >) file =
  let input = of_fd (Console.stdin_fd caps) in
  stdin_source := Some input;
  sources := (match file with Some f -> [ of_fd (FS.open_in_fd caps f); input ] | None -> [ input ]);
  try commands caps with End_of_text -> raise Quit
