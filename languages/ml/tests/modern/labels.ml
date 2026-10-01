(* labeled arguments: a call's arguments go to their parameters, in any
 * order, among those without labels; mini-ml puts them back in the
 * function's order (Scope), whose labels it knows from its definition,
 * its type, or the field it is in *)

let line s = print_string s; print_newline ()
let show = string_of_int

(* its definition's labels *)
let sub ~from ~by = from - by
let range ~lo ~hi ~step f = let rec go i = if i < hi then (f i; go (i + step)) in go lo
let join ~sep a b = a ^ sep ^ b
let rec power ~base ~exp = if exp = 0 then 1 else base * power ~exp:(exp - 1) ~base

(* a label in a type: a field's, a parameter's *)
type io = { write : string -> newline:bool -> unit; scale : by:int -> int -> int }

let report (f : level:int -> text:string -> string) = f ~text:"t" ~level:3

(* without a definition's name: as written *)
let apply f = f ~from:10 ~by:1

let () =
  line (show (sub ~from:10 ~by:3) ^ " " ^ show (sub ~by:3 ~from:10));
  let from = 100 and by = 1 in
  line (show (sub ~by ~from));
  (* the arguments are computed, each once *)
  let n = ref 0 in
  let next () = incr n; !n in
  line (show (sub ~by:(next ()) ~from:(10 * next ())));
  (* labels among arguments without *)
  line (join "a" ~sep:"-" "b" ^ " " ^ join ~sep:"+" "a" "b");
  range ~step:3 ~hi:10 ~lo:1 (fun i -> print_string (show i ^ " "));
  print_newline ();
  line (show (power ~exp:10 ~base:2));
  (* some of them: a function of the others *)
  let minus_one = sub ~from:0 in
  let dash = join ~sep:"-" in
  line (show (minus_one ~by:1) ^ " " ^ dash "x" "y" ^ " " ^ String.concat "," (List.map (join ~sep:"." "p") [ "a"; "b" ]));
  (* another name of a function, and what a call leaves of one: their
   * labels follow *)
  let minus = sub in
  let from_one = range ~lo:1 in
  line (show (minus ~by:1 ~from:5));
  from_one ~step:2 ~hi:6 (fun i -> print_string (show i ^ " "));
  print_newline ();
  (* a local function *)
  let area ~w ~h = w * h in
  line (show (area ~h:2 ~w:21));
  (* a field's function, a parameter's *)
  let io = { write = (fun s ~newline -> print_string s; if newline then print_newline ()); scale = (fun ~by n -> n * by) } in
  io.write "field " ~newline:false;
  io.write ~newline:true (show (io.scale 7 ~by:6));
  line (report (fun ~level ~text -> text ^ show level));
  line (show (apply sub))
