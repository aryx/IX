(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* The tests of lib_graphics/pdf and lib_graphics/fonts: a file
 * written (Unit_pdf_write, ix's), and mini-chrome's of a file read:
 * PDF files of others' programs (data/make.sh says how), each page
 * drawn near poppler's picture of it. The files are found from the
 * tree's top, where make test runs this, or in PDF_TESTS_DATA. *)

let () =
  Cap.main (fun caps ->
      let dir = match CapSys.getenv caps "PDF_TESTS_DATA" with d -> d | exception Not_found -> "lib_graphics/pdf/tests/data" in
      Testutil_pdf.reader := (fun (name : string) -> FS.read caps (Fpath.v (Filename.concat dir name)));
      Testo.interpret_argv ~project_name:"pdf" (fun _env -> List.concat [ Unit_pdf_write.tests; Unit_pdf.tests; Unit_fonts.tests; Unit_pdf_render.tests ]))
