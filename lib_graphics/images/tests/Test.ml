(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* The tests of the pictures' readers and of what draws a picture
 * (docs/plans/plan_office.md, stage 7): the playground's of Png (over
 * PngSuite), of Jpeg (over JPEGs of its own and the pixels libjpeg
 * decodes them to) and of Blit. The files are found from the tree's
 * top, where make test runs this, or in IMAGES_TESTS_DATA. *)

let () =
  Cap.main (fun caps ->
      let dir = match CapSys.getenv caps "IMAGES_TESTS_DATA" with d -> d | exception Not_found -> "lib_graphics/images/tests" in
      Testutil_images.reader := (fun (name : string) -> FS.read caps (Fpath.v (Filename.concat dir name)));
      Testo.interpret_argv ~project_name:"images" (fun _env -> List.concat [ Unit_png.tests; Unit_jpeg.tests; Unit_gif.tests; Unit_blit.tests ]))
