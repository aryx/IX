(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/layout/Grid_layout.ml, as its add433e first had it (docs/plans/plan_browser.md) *)

(* See Grid_layout.mli *)

(*****************************************************************************)
(* Placement *)
(*****************************************************************************)

type cell = { row : int; column : int; rows : int; columns : int }

(* the rectangle a name draws in the areas, if it is there *)
let area_of (areas : string list list) (name : string) : cell option =
  let found = ref None in
  List.iteri
    (fun r row ->
      List.iteri
        (fun c n ->
          if n = name then
            found := Some (match !found with None -> (r, c, r, c) | Some (r0, c0, r1, c1) -> (min r0 r, min c0 c, max r1 r, max c1 c)))
        row)
    areas;
  Option.map (fun (r0, c0, r1, c1) -> { row = r0; column = c0; rows = r1 - r0 + 1; columns = c1 - c0 + 1 }) !found

let place ~(rows : int) ~(columns : int) ~(areas : string list list) (placements : Css_grid.placement list) : cell list * int * int =
  let columns = List.fold_left (fun m row -> max m (List.length row)) (max 1 columns) areas in
  (* where an item says it goes; a name that no area has is no place *)
  let said (p : Css_grid.placement) : cell option =
    match p with
    | Area name -> area_of areas name
    | Cell { row; column } -> Some { row = row - 1; column = column - 1; rows = 1; columns = 1 }
    | Auto_placed -> None
  in
  let explicit = List.map said placements in
  let columns = List.fold_left (fun m c -> match c with Some c -> max m (c.column + c.columns) | None -> m) columns explicit in
  let taken : (int * int, unit) Hashtbl.t = Hashtbl.create 16 in
  let take (c : cell) = for r = c.row to c.row + c.rows - 1 do for k = c.column to c.column + c.columns - 1 do Hashtbl.replace taken (r, k) () done done in
  List.iter (Option.iter take) explicit;
  (* the others: the next free cell, row by row *)
  let cursor = ref 0 in
  let cells =
    List.map
      (fun (c : cell option) ->
        match c with
        | Some c -> c
        | None ->
            while Hashtbl.mem taken (!cursor / columns, !cursor mod columns) do incr cursor done;
            let c = { row = !cursor / columns; column = !cursor mod columns; rows = 1; columns = 1 } in
            take c;
            c)
      explicit
  in
  let rows = List.fold_left (fun m (c : cell) -> max m (c.row + c.rows)) (max rows (List.length areas)) cells in
  (cells, rows, columns)

(*****************************************************************************)
(* The tracks' sizes *)
(*****************************************************************************)

type content = { least : float; most : float }

let flexible (t : Css_grid.track) : bool = match t.max with Fr _ -> true | _ -> false

(* a track's least, and its most (infinity for an fr) *)
let least ~(base : float) (t : Css_grid.track) (c : content) : float =
  match t.min with Length l -> Css_values.resolve l base | Max_content -> c.most | Min_content | Auto | Fr _ -> c.least

let most ~(base : float) (t : Css_grid.track) (c : content) : float =
  match t.max with Length l -> Css_values.resolve l base | Min_content -> c.least | Max_content | Auto -> c.most | Fr _ -> infinity

let contents ~(base : float) ~(gap : float) (tracks : Css_grid.track array) (items : (int * int * content) list) : content array =
  let cs = Array.make (Array.length tracks) { least = 0.; most = 0. } in
  let add i (c : content) = cs.(i) <- { least = Float.max cs.(i).least c.least; most = Float.max cs.(i).most c.most } in
  (* the items of one track first, then those that span *)
  List.iter (fun (first, span, c) -> if span = 1 && first < Array.length cs then add first c) items;
  List.iter
    (fun (first, span, (c : content)) ->
      let last = first + span - 1 in
      if span > 1 && last < Array.length cs && not (Array.exists flexible (Array.sub tracks first span)) then begin
        (* what the others hold already, taken off: the rest to the last *)
        let others (pick : Css_grid.track -> content -> float) : float =
          let sum = ref (gap *. float_of_int (span - 1)) in
          for i = first to last - 1 do
            sum := !sum +. pick tracks.(i) cs.(i)
          done;
          !sum
        in
        (* a track's widest: its most, if it has one; else its content's *)
        let widest t k = let m = most ~base t k in if m = infinity then k.most else Float.max m (least ~base t k) in
        add last { least = Float.max 0. (c.least -. others (least ~base)); most = Float.max 0. (c.most -. others widest) }
      end)
    items;
  cs

let sizes ~(room : float option) ~(base : float) ~(gap : float) ~(stretch : bool) (tracks : Css_grid.track array) (cs : content array) : float array =
  let n = Array.length tracks in
  let low = Array.init n (fun i -> least ~base tracks.(i) cs.(i)) in
  let high = Array.init n (fun i -> Float.max low.(i) (most ~base tracks.(i) cs.(i))) in
  match room with
  | None ->
      (* nothing to share: each its most, an fr its content *)
      Array.init n (fun i -> if flexible tracks.(i) then Float.max low.(i) cs.(i).most else high.(i))
  | Some room ->
      let size = Array.copy low in
      let gaps = gap *. float_of_int (max 0 (n - 1)) in
      let left () = room -. gaps -. Array.fold_left ( +. ) 0. size in
      (* the room left to the tracks below their most, equally, each up
       * to it: again until none is left, or none can grow *)
      let rec grow () =
        let growing = List.filter (fun i -> (not (flexible tracks.(i))) && size.(i) < high.(i)) (List.init n Fun.id) in
        let free = left () in
        if free > 0.01 && growing <> [] then begin
          let share = free /. float_of_int (List.length growing) in
          List.iter (fun i -> size.(i) <- Float.min high.(i) (size.(i) +. share)) growing;
          grow ()
        end
      in
      grow ();
      (* then to the fr tracks, by their shares; one whose least is more
       * than its share keeps its least, and the others share again *)
      let rec share (flex : int list) =
        if flex <> [] then begin
          let fixed = Array.fold_left ( +. ) 0. (Array.mapi (fun i s -> if List.mem i flex then 0. else s) size) in
          let fr i = match tracks.(i).max with Fr f -> f | _ -> 0. in
          let unit = Float.max 0. (room -. gaps -. fixed) /. Float.max 1. (List.fold_left (fun s i -> s +. fr i) 0. flex) in
          match List.filter (fun i -> low.(i) > fr i *. unit) flex with
          | [] -> List.iter (fun i -> size.(i) <- fr i *. unit) flex
          | frozen ->
              List.iter (fun i -> size.(i) <- low.(i)) frozen;
              share (List.filter (fun i -> not (List.mem i frozen)) flex)
        end
      in
      let flex = List.filter (fun i -> flexible tracks.(i)) (List.init n Fun.id) in
      share flex;
      (* no fr: the auto tracks stretched over what is left *)
      (if stretch && flex = [] then
         let autos = List.filter (fun i -> tracks.(i).max = Css_grid.Auto) (List.init n Fun.id) in
         let free = left () in
         if free > 0. && autos <> [] then List.iter (fun i -> size.(i) <- size.(i) +. (free /. float_of_int (List.length autos))) autos);
      size

(*****************************************************************************)
(* Where each starts *)
(*****************************************************************************)

let starts ~(align : Computed.align) ~(room : float) ~(gap : float) (sizes : float array) : float array =
  let n = Array.length sizes in
  let free = Float.max 0. (room -. Array.fold_left ( +. ) 0. sizes -. (gap *. float_of_int (max 0 (n - 1)))) in
  let fn = float_of_int n in
  (* before the first, and added to each gap *)
  let before, between =
    match align with
    | End -> (free, 0.)
    | Center -> (free /. 2., 0.)
    | Space_between when n > 1 -> (0., free /. (fn -. 1.))
    | Space_around when n > 0 -> (free /. fn /. 2., free /. fn)
    | Space_evenly -> (free /. (fn +. 1.), free /. (fn +. 1.))
    | _ -> (0., 0.)
  in
  let at = ref before in
  Array.map
    (fun s ->
      let start = !at in
      at := !at +. s +. gap +. between;
      start)
    sizes
