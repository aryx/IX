(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Icons.mli *)

open Playground

type look = Folder | Text | Web | Picture | Sound | Film | Book | Program | Archive | Other

let of_kind (kind : string) : look =
  let is (prefix : string) = String.starts_with ~prefix kind in
  if is "text/html" then Web
  else if kind = "text/x-abc" || is "audio/" then Sound
  else if is "text/x-script" then Program
  else if is "text/" then Text
  else if is "image/" then Picture
  else if is "video/" then Film
  else if kind = "application/pdf" || kind = "application/x-office" then Book
  else if kind = "application/x-executable" then Program
  else if kind = "application/gzip" || kind = "application/x-tar" then Archive
  else Other

let at = move

(* a sheet with a dark edge, what most kinds are drawn on *)
let sheet (paper : color) : shape list =
  [ rectangle (rgb 90 95 100) 12. 16.; rectangle paper 10. 14. ]

let lines (ink : color) : shape list =
  List.map (fun (y : float) -> at 0. y (rectangle ink 6. 1.)) [ 4.; 1.; -2.; -5. ]

let draw (look : look) : shape =
  let parts =
    match look with
    | Folder ->
        let tab = rgb 200 150 40 and body = rgb 240 190 70 in
        [ at (-3.) 5. (rectangle tab 8. 4.); at 0. (-1.) (rectangle tab 16. 11.); at 0. (-1.) (rectangle body 14. 9.) ]
    | Text -> sheet white @ lines (rgb 95 99 104)
    | Web ->
        sheet white
        @ [ circle (rgb 26 115 232) 4.; at 0. 0. (rectangle white 8. 1.); at 0. 0. (rectangle white 1. 8.) ]
    | Picture ->
        sheet (rgb 180 220 245)
        @ [ at 2. 3. (circle (rgb 245 200 40) 2.);
            polygon (rgb 60 150 80) [ (-5., -7.); (5., -7.); (5., -3.); (1., 0.); (-2., -3.); (-5., -1.) ] ]
    | Sound ->
        let ink = rgb 130 60 170 in
        [ at (-3.) (-5.) (circle ink 3.); at 3. (-3.) (circle ink 3.);
          at (-1.) 1. (rectangle ink 1. 12.); at 5. 3. (rectangle ink 1. 12.);
          polygon ink [ (-1., 7.); (6., 9.); (6., 6.); (-1., 4.) ] ]
    | Film ->
        let strip = rgb 50 52 56 and hole = white in
        [ rectangle strip 14. 16.; rectangle (rgb 120 190 240) 8. 10. ]
        @ List.concat_map
            (fun (y : float) -> [ at (-5.5) y (rectangle hole 2. 2.); at 5.5 y (rectangle hole 2. 2.) ])
            [ 6.; 2.; -2.; -6. ]
    | Book -> sheet (rgb 250 225 220) @ (at (-3.) 5. (rectangle (rgb 200 50 40) 4. 3.) :: lines (rgb 200 50 40))
    | Program ->
        [ rectangle (rgb 50 52 56) 16. 14.; at 0. 5. (rectangle (rgb 120 125 130) 16. 3.);
          polygon (rgb 90 220 110) [ (-6., 2.); (-1., -1.); (-6., -4.) ]; at 3. (-4.) (rectangle (rgb 90 220 110) 5. 1.) ]
    | Archive ->
        let ink = rgb 150 110 60 in
        [ rectangle ink 14. 14.; at 0. 0. (rectangle (rgb 215 180 125) 12. 12.); at 0. 0. (rectangle ink 2. 14.);
          at 0. 0. (rectangle ink 14. 2.) ]
    | Other -> sheet (rgb 225 227 230)
  in
  group parts
