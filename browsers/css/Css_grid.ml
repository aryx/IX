(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/css/Css_grid.ml, as its add433e first had it (docs/plans/plan_browser.md) *)

(* See Css_grid.mli *)
open Css_syntax

type breadth = Length of Css_values.length | Fr of float | Min_content | Max_content | Auto
type track = { min : breadth; max : breadth }

let auto = { min = Auto; max = Auto }

let breadth (ctx : Css_values.context) (c : component) : breadth option =
  match c with
  | Token (Dimension (n, unit)) when String.lowercase_ascii unit = "fr" -> Some (Fr n)
  | Token (Ident s) -> (
      match String.lowercase_ascii s with "min-content" -> Some Min_content | "max-content" -> Some Max_content | "auto" -> Some Auto | _ -> None)
  | _ -> Option.map (fun l -> Length l) (Css_values.length ctx c)

let rec tracks (ctx : Css_values.context) (value : component list) : track list =
  List.concat_map
    (fun (c : component) ->
      match c with
      | Func (f, args) when String.lowercase_ascii f = "minmax" -> (
          match List.map (fun a -> Css_values.parts a) (split_on Comma args) with
          | [ [ a ]; [ b ] ] -> (
              match (breadth ctx a, breadth ctx b) with
              (* a share cannot be the least: auto *)
              | Some (Fr _), Some max -> [ { min = Auto; max } ]
              | Some min, Some max -> [ { min; max } ]
              | _ -> [])
          | _ -> [])
      | Func (f, args) when String.lowercase_ascii f = "repeat" -> (
          match split_on Comma args with
          | count :: rest -> (
              match Css_values.parts count with
              | [ Token (Number n) ] when n >= 1. && n <= 1000. ->
                  let once = tracks ctx (List.concat rest) in
                  List.concat (List.init (int_of_float n) (fun _ -> once))
              | _ -> [])
          | [] -> [])
      | Func (f, _) when String.lowercase_ascii f = "fit-content" -> [ auto ]
      (* a line's name, "[main-start]": not a track *)
      | Block ('[', _) -> []
      | c -> (
          match breadth ctx c with
          (* "1fr" is minmax(auto, 1fr) *)
          | Some (Fr n) -> [ { min = Auto; max = Fr n } ]
          | Some b -> [ { min = b; max = b } ]
          | None -> []))
    (Css_values.parts value)

let areas (value : component list) : string list list =
  List.filter_map
    (fun (c : component) ->
      match c with
      | Token (String s) -> Some (List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun ch -> if ch = '\t' || ch = '\n' then ' ' else ch) s)))
      | _ -> None)
    value

type placement = Auto_placed | Area of string | Cell of { row : int; column : int }

let placement (value : component list) : placement =
  let line (cs : component list) = match Css_values.parts cs with [ Token (Number n) ] when n >= 1. -> Some (int_of_float n) | _ -> None in
  match split_on (Delim '/') value with
  | [ one ] -> (
      match Css_values.parts one with
      | [ Token (Ident name) ] when String.lowercase_ascii name <> "auto" -> Area name
      | _ -> ( match line one with Some row -> Cell { row; column = 1 } | None -> Auto_placed))
  | row :: column :: _ -> ( match (line row, line column) with Some row, Some column -> Cell { row; column } | _ -> Auto_placed)
  | [] -> Auto_placed
