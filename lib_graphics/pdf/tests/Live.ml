(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* What a PDF file keeps alive, stage by stage: the megabytes of live
 * values (OCaml's Gc, after a full collection) once the file is read,
 * its pages listed, and each page asked for drawn. OCaml's build
 * only: its values are not mini-ml's (a float of an array is not a
 * block there), but which stage holds the memory is the same. Behind
 * docs/plans/plan_pdf.md's "memory".
 * usage: Live.exe file.pdf page... *)

let live (what : string) : unit =
  Gc.full_major ();
  Printf.printf "%7.1f MB  %s\n%!" (float_of_int (Gc.stat ()).live_words *. 8. /. 1e6) what

let () =
  Cap.main (fun caps ->
      match Array.to_list (CapSys.argv caps) with
      | _ :: file :: pages ->
          let bytes = FS.read caps (Fpath.v file) in
          live "the file's bytes";
          let pdf = Pdf.of_string bytes in
          live "read (Pdf.of_string)";
          let all = Array.of_list (Pdf.pages pdf) in
          live (Printf.sprintf "its %d pages listed" (Array.length all));
          let cache = Pdf_render.cache () in
          let kept = ref [] in
          List.iter
            (fun (n : string) ->
              let img = Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey pdf cache all.(int_of_string n - 1) ~scale:1. in
              live (Printf.sprintf "page %s drawn, its picture dropped (%d by %d)" n img.width img.height))
            pages;
          ignore (Sys.opaque_identity (pdf, cache, all, !kept))
      | _ -> prerr_endline "usage: Live.exe file.pdf page...")
