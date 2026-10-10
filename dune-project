(lang dune 3.7)
(using menhir 2.1)
(name ix)

(package
 (name ix)
 (synopsis "The Principia Softwarica system, tiny, in OCaml")
 (depends ocaml dune caps fpath logs fmt testo alcotest (tsdl (>= 1.3.0)) js_of_ocaml-compiler js_of_ocaml ppx_deriving menhir))
