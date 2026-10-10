(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Unit_scheme_secd.mli *)

module E = Scheme_eval
module M = Scheme_secd

(* each form of [text] run to its end; the last's value, or the error *)
let secd (m : M.t) (text : string) : string =
  let rec go (last : string) (forms : Sexpr.t list) : string =
    match forms with
    | [] -> last
    | x :: rest -> (
        M.start m (Scheme_syntax.top x);
        match M.run ~fuel:10_000_000 m with
        | E.Done v -> go (Scheme.print Scheme.Write v) rest
        | E.Failed e -> "error: " ^ e.message
        | _ -> "not done") in
  go "" (Sexpr_read.read_all Sexpr_read.Scheme text)

let cesk (text : string) : string =
  match E.eval_all ~fuel:10_000_000 (E.create ()) text with
  | Ok v, _ -> Scheme.print Scheme.Write v
  | Error e, _ -> "error: " ^ e.message

let check = Alcotest.(check string)

let programs : string list =
  [ "(+ 1 2 3)";
    "((lambda (x) (+ x 1)) 41)";
    "(define (f n) (if (= n 0) 1 (* n (f (- n 1))))) (f 10)";
    "(map (lambda (x) (* x x)) '(1 2 3))";
    "(let loop ([i 0] [acc '()]) (if (= i 5) (reverse acc) (loop (+ i 1) (cons i acc))))";
    "(define (make-counter) (let ([n 0]) (lambda () (set! n (+ n 1)) n))) (define c (make-counter)) (c) (c)";
    "(+ 1 (call/cc (lambda (k) (k 41))))";
    "(let ([k #f] [seen '()]) (let ([n (+ 1 (call/cc (lambda (c) (set! k c) 0)))]) (set! seen (cons n seen)) (if (< n 3) (k n) (reverse seen))))";
    "(define-struct posn (x y)) (posn-x (make-posn 3 4))";
    "(apply + 1 2 '(3 4))";
    "(define (f . rest) rest) (f 1 2 3)";
    "(car 5)";
    "(undefined-thing 1)";
    "((lambda (x) x))";
    "(sort '(3 1 2) <)" ]

let tests =
  Testo.categorize "Scheme, by Landin's SECD machine"
    [ Testo.create "the same values and errors as the CESK machine's" (fun () ->
          List.iter
            (fun (p : string) ->
              check p (cesk p) (secd (M.create ~tail:true) p);
              check (p ^ ", every call saving on the dump") (cesk p) (secd (M.create ~tail:false) p))
            programs);
      Testo.create "a loop: the dump stays where it is, or grows as in 1964" (fun () ->
          let loop = "(define (loop i) (if (= i 0) 'done (loop (- i 1)))) (loop 1000)" in
          let m = M.create ~tail:true in
          check "its value" "done" (secd m loop);
          Alcotest.(check int) "no frame kept" 0 (M.deepest m);
          let m = M.create ~tail:false in
          check "its value" "done" (secd m loop);
          Alcotest.(check int) "a frame a turn" 1001 (M.deepest m));
      Testo.create "the four registers, before a step" (fun () ->
          let m = M.create ~tail:false in
          M.start m (Scheme_syntax.top (fst (Sexpr_read.read Sexpr_read.Scheme "((lambda (x) (+ x 1)) 41)" 0)));
          let lines : string list ref = ref [] in
          let rec go () : unit =
            lines := M.show m :: !lines;
            match M.run ~fuel:1 m with E.Running -> go () | _ -> () in
          go ();
          check "the application's parts, then ap" "S: - | E: - | C: (lambda (x) ...) 41 ap | D: 0" (List.nth (List.rev !lines) 1);
          check "the body, the caller on the dump" "S: - | E: x=41 | C: (+ x 1) | D: 1" (List.nth (List.rev !lines) 4);
          check "the value, before the return" "S: 42 | E: x=41 | C: - | D: 1" (List.hd !lines)) ]
