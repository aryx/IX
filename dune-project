(lang dune 3.7)
(using menhir 2.1)
(name ix)

(package
 (name ix)
 (synopsis "The Principia Softwarica system, tiny, in OCaml")
 (depends ocaml dune caps fpath logs fmt testo alcotest tsdl js_of_ocaml-compiler ppx_deriving menhir))
