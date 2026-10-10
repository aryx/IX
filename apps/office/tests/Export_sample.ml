(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* usage: Export_sample dir
 * A new document of each kind, and a long one, exported to
 * dir/<kind>.pdf; and beside it each page as the screen draws it
 * (Shape_render_software, a pixel a unit), dir/<kind>-<page>.ppm:
 * what export.sh holds another program's reading of the file to. *)

let kinds : (string * Document.doc) list =
  let fresh = Office_templates.fresh in
  let d = fresh Document.Document in
  let text = String.concat "\n\n" (List.init 40 (fun i -> Printf.sprintf "Paragraph %d of a document long enough to go on to a second page, and to a third." i)) in
  [
    ("document", d); ("spreadsheet", fresh Spreadsheet); ("presentation", fresh Presentation); ("picture", fresh Picture); ("drawing", fresh Drawing_doc);
    ("long", { d with body = Texts [ Rich.of_string ~style:Style.plain text ]; footer = Rich.of_string ~style:Style.plain "page {page} of {pages}" });
  ]

let () =
  Cap.main (fun caps ->
      match CapSys.argv caps with
      | [| _; dir |] ->
          List.iter
            (fun ((name, d) : string * Document.doc) ->
              let model = { Office_model.initial with start = false; history = Undo.start ~limit:100 d } in
              FS.write caps (Fpath.v (Filename.concat dir (name ^ ".pdf"))) (Office_export.pdf model);
              (* the same pages, in the order the file has them *)
              let pw, ph = Office_page.page_size d.kind in
              let slides = match d.body with Texts ts -> List.length ts | Main _ -> 1 in
              let page = ref 0 in
              for slide = 0 to slides - 1 do
                let d = { d with slide } in
                let l, t = Office_page.origin d in
                for k = 0 to Office_page.pages d - 1 do
                  incr page;
                  let fb = Framebuffer.create ~width:(int_of_float pw) ~height:(int_of_float ph) in
                  let shapes = Office_view.page_shapes ~chrome:false d model in
                  let top = t -. (float k *. Office_page.pitch d.kind) in
                  Shape_render_software.render ~options:Shape_render_software.default_options ~scale:1. fb
                    [ Playground.rectangle Playground.white pw ph; Playground.group shapes |> Playground.move (-.(l +. (pw /. 2.))) (-.(top -. (ph /. 2.))) ];
                  FS.write caps (Fpath.v (Filename.concat dir (Printf.sprintf "%s-%d.ppm" name !page))) (Session.ppm fb)
                done
              done)
            kinds
      | _ -> failwith "usage: Export_sample dir")
