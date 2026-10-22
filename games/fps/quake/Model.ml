(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Model.mli *)

type vec = { x : float; y : float; z : float }
type plane = { normal : vec; dist : float; kind : int }
type contents = Empty | Solid | Water | Slime | Lava | Sky | Other of int

type texture = {
  tname : string;
  width : int;
  height : int;
  mips : string array;
  mutable anim_total : int;
  mutable anim_min : int;
  mutable anim_max : int;
  mutable anim_next : texture option;
  mutable alternate : texture option;
}

type texinfo = {
  s : vec;
  s_offset : float;
  t : vec;
  t_offset : float;
  texture : texture;
  special : bool;
}

type kind = Normal | Sky | Turbulent

type surface = {
  index : int;
  plane : plane;
  back : bool;
  first_edge : int;
  num_edges : int;
  texinfo : texinfo;
  kind : kind;
  texturemins : int * int;
  extents : int * int;
  styles : int array;
  samples : int;
  mutable visframe : int;
}

type node = {
  nplane : plane;
  children : child array;
  nmins : vec;
  nmaxs : vec;
  first_surface : int;
  num_surfaces : int;
  mutable nvisframe : int;
  mutable nparent : node option;
}

and leaf = {
  lindex : int;
  contents : contents;
  visofs : int;
  lmins : vec;
  lmaxs : vec;
  marks : surface array;
  mutable lvisframe : int;
  mutable key : int;
  mutable lparent : node option;
}

and child = Node of node | Leaf of leaf

type hull = {
  cplanes : plane array;
  front : int array;
  back : int array;
  clip_mins : vec;
  clip_maxs : vec;
}

type submodel = {
  mins : vec;
  maxs : vec;
  origin : vec;
  headnode : int array;
  visleafs : int;
  first_face : int;
  num_faces : int;
}

type t = {
  vertexes : vec array;
  edge0 : int array;
  edge1 : int array;
  surfedges : int array;
  planes : plane array;
  textures : texture option array;
  surfaces : surface array;
  nodes : node array;
  leaves : leaf array;
  hulls : hull array;
  submodels : submodel array;
  visibility : string;
  lighting : string;
  entities : (string * string) list list;
}

(*****************************************************************************)
(* Vectors *)
(*****************************************************************************)

let zero = { x = 0.; y = 0.; z = 0. }

let dot (a : vec) (b : vec) : float =
  (a.x *. b.x) +. (a.y *. b.y) +. (a.z *. b.z)

let add (a : vec) (b : vec) : vec =
  { x = a.x +. b.x; y = a.y +. b.y; z = a.z +. b.z }

let sub (a : vec) (b : vec) : vec =
  { x = a.x -. b.x; y = a.y -. b.y; z = a.z -. b.z }

let scale (k : float) (a : vec) : vec =
  { x = k *. a.x; y = k *. a.y; z = k *. a.z }

let length (a : vec) : float = sqrt (dot a a)

let normalize (a : vec) : vec =
  let n = length a in
  if n = 0. then a else scale (1. /. n) a

let cross (a : vec) (b : vec) : vec =
  {
    x = (a.y *. b.z) -. (a.z *. b.y);
    y = (a.z *. b.x) -. (a.x *. b.z);
    z = (a.x *. b.y) -. (a.y *. b.x);
  }

let vec_of_string (s : string) : vec =
  match
    List.filter (fun (w : string) -> w <> "") (String.split_on_char ' ' s)
  with
  | [ x; y; z ] ->
      { x = float_of_string x; y = float_of_string y; z = float_of_string z }
  | _ -> failwith ("not a vector: " ^ s)

(*****************************************************************************)
(* The entities *)
(*****************************************************************************)

(* { "key" "value" ... } { ... }: COM_Parse's tokens *)
let parse_entities (s : string) : (string * string) list list =
  let n = String.length s in
  let i = ref 0 in
  let rec token () : string option =
    while
      !i < n
      && (s.[!i] = ' '
         || s.[!i] = '\n'
         || s.[!i] = '\r'
         || s.[!i] = '\t'
         || s.[!i] = '\000')
    do
      incr i
    done;
    if !i >= n then None
    else if !i + 1 < n && s.[!i] = '/' && s.[!i + 1] = '/' then begin
      while !i < n && s.[!i] <> '\n' do
        incr i
      done;
      token ()
    end
    else if s.[!i] = '"' then begin
      let start = !i + 1 in
      i := start;
      while !i < n && s.[!i] <> '"' do
        incr i
      done;
      let t = String.sub s start (!i - start) in
      incr i;
      Some t
    end
    else begin
      let start = !i in
      while
        !i < n
        && s.[!i] <> ' '
        && s.[!i] <> '\n'
        && s.[!i] <> '\t'
        && s.[!i] <> '\r'
      do
        incr i
      done;
      Some (String.sub s start (!i - start))
    end
  in
  let rec entities (acc : (string * string) list list) :
      (string * string) list list =
    match token () with
    | Some "{" ->
        let rec pairs (kv : (string * string) list) : (string * string) list =
          match token () with
          | Some "}" | None -> List.rev kv
          | Some k -> (
              match token () with
              | Some v -> pairs ((k, v) :: kv)
              | None -> List.rev kv)
        in
        entities (pairs [] :: acc)
    | Some _ -> entities acc
    | None -> List.rev acc
  in
  entities []

let value (e : (string * string) list) (k : string) : string option =
  List.assoc_opt k e

(*****************************************************************************)
(* Loading *)
(*****************************************************************************)

let contents_of (k : int) : contents =
  match k with
  | -1 -> Empty
  | -2 -> Solid
  | -3 -> Water
  | -4 -> Slime
  | -5 -> Lava
  | -6 -> Sky
  | k -> Other k

let records (lump : string) (size : int) (f : int -> 'a) : 'a array =
  if String.length lump mod size <> 0 then failwith "a lump of a funny size";
  Array.init (String.length lump / size) (fun (k : int) -> f (k * size))

let vec_at (s : string) (o : int) : vec =
  {
    x = Bspfile.float32 s o;
    y = Bspfile.float32 s (o + 4);
    z = Bspfile.float32 s (o + 8);
  }

let short_vec (s : string) (o : int) : vec =
  {
    x = float (Bspfile.short s o);
    y = float (Bspfile.short s (o + 2));
    z = float (Bspfile.short s (o + 4));
  }

(* an animated texture's frame: +0 to +9, or +a to +j *)
type frame = Main of int | Alt of int

let load_textures (lump : string) : texture option array =
  if lump = "" then [||]
  else begin
    let n = Bspfile.int32 lump 0 in
    let tex =
      Array.init n (fun (i : int) ->
          let o = Bspfile.int32 lump (4 + (4 * i)) in
          if o = -1 then None
          else begin
            let w = Bspfile.int32 lump (o + 16)
            and h = Bspfile.int32 lump (o + 20) in
            if w land 15 <> 0 || h land 15 <> 0 then
              failwith "a texture not 16 aligned";
            let mips =
              Array.init 4 (fun (k : int) ->
                  String.sub lump
                    (o + Bspfile.int32 lump (o + 24 + (4 * k)))
                    (w * (h lsr (2 * k))))
            in
            Some
              {
                tname = Bspfile.name lump o 16;
                width = w;
                height = h;
                mips;
                anim_total = 0;
                anim_min = 0;
                anim_max = 0;
                anim_next = None;
                alternate = None;
              }
          end)
    in
    (* the animations sequenced: +0 to +9 the frames, +a to +j the
     * other set, two tenths each (ANIM_CYCLE) *)
    let frame (t : texture) : frame =
      let c = Char.uppercase_ascii t.tname.[1] in
      if c >= '0' && c <= '9' then Main (Char.code c - Char.code '0')
      else if c >= 'A' && c <= 'J' then Alt (Char.code c - Char.code 'A')
      else failwith ("a bad animating texture " ^ t.tname)
    in
    Array.iter
      (fun (t : texture option) ->
        match t with
        | Some t when t.tname.[0] = '+' && t.anim_next = None ->
            let rest = String.sub t.tname 2 (String.length t.tname - 2) in
            let same =
              Array.to_list tex
              |> List.filter_map (fun (u : texture option) ->
                  match u with
                  | Some u
                    when u.tname.[0] = '+'
                         && String.sub u.tname 2 (String.length u.tname - 2)
                            = rest ->
                      Some u
                  | _ -> None)
            in
            let main = Array.make 10 None and alt = Array.make 10 None in
            List.iter
              (fun (u : texture) ->
                match frame u with
                | Main k -> main.(k) <- Some u
                | Alt k -> alt.(k) <- Some u)
              same;
            let count (a : texture option array) : int =
              let n = ref 0 in
              Array.iteri
                (fun (k : int) (u : texture option) ->
                  if u <> None then n := k + 1)
                a;
              !n
            in
            let link (a : texture option array) (other : texture option array) :
                unit =
              let m = count a in
              for k = 0 to m - 1 do
                match a.(k) with
                | None -> failwith ("a missing frame of " ^ t.tname)
                | Some u ->
                    u.anim_total <- m * 2;
                    u.anim_min <- k * 2;
                    u.anim_max <- (k + 1) * 2;
                    u.anim_next <- a.((k + 1) mod m);
                    if count other > 0 then u.alternate <- other.(0)
              done
            in
            link main alt;
            link alt main
        | _ -> ())
      tex;
    tex
  end

let no_texture : texture =
  {
    tname = "notexture";
    width = 16;
    height = 16;
    mips = Array.init 4 (fun (k : int) -> String.make (256 lsr (2 * k)) '\015');
    anim_total = 0;
    anim_min = 0;
    anim_max = 0;
    anim_next = None;
    alternate = None;
  }

(* a face's texture extents, rounded out to 16s (CalcSurfaceExtents) *)
let extents (vertexes : vec array) (edge0 : int array) (edge1 : int array)
    (surfedges : int array) (ti : texinfo) (first : int) (n : int) :
    (int * int) * (int * int) =
  let mins = [| infinity; infinity |]
  and maxs = [| neg_infinity; neg_infinity |] in
  for i = 0 to n - 1 do
    let e = surfedges.(first + i) in
    let v = if e >= 0 then vertexes.(edge0.(e)) else vertexes.(edge1.(-e)) in
    let s = dot v ti.s +. ti.s_offset and t = dot v ti.t +. ti.t_offset in
    mins.(0) <- Float.min mins.(0) s;
    maxs.(0) <- Float.max maxs.(0) s;
    mins.(1) <- Float.min mins.(1) t;
    maxs.(1) <- Float.max maxs.(1) t
  done;
  let lo (k : int) : int = int_of_float (Float.floor (mins.(k) /. 16.))
  and hi (k : int) : int = int_of_float (Float.ceil (maxs.(k) /. 16.)) in
  ((lo 0 * 16, lo 1 * 16), ((hi 0 - lo 0) * 16, (hi 1 - lo 1) * 16))

let load (bsp : Bspfile.t) : t =
  let lump (k : int) : string = bsp.lumps.(k) in
  let vertexes =
    records (lump Bspfile.vertexes) 12 (vec_at (lump Bspfile.vertexes))
  in
  let el = lump Bspfile.edges in
  let edge0 = records el 4 (fun (o : int) -> Bspfile.ushort el o)
  and edge1 = records el 4 (fun (o : int) -> Bspfile.ushort el (o + 2)) in
  let sl = lump Bspfile.surfedges in
  let surfedges = records sl 4 (Bspfile.int32 sl) in
  let pl = lump Bspfile.planes in
  let planes =
    records pl 20 (fun (o : int) ->
        {
          normal = vec_at pl o;
          dist = Bspfile.float32 pl (o + 12);
          kind = Bspfile.int32 pl (o + 16);
        })
  in
  let textures = load_textures (lump Bspfile.textures) in
  let tl = lump Bspfile.texinfo in
  let texinfos =
    records tl 40 (fun (o : int) ->
        let m = Bspfile.int32 tl (o + 32) in
        let texture =
          if m >= 0 && m < Array.length textures then
            match textures.(m) with Some t -> t | None -> no_texture
          else no_texture
        in
        {
          s = vec_at tl o;
          s_offset = Bspfile.float32 tl (o + 12);
          t = vec_at tl (o + 16);
          t_offset = Bspfile.float32 tl (o + 28);
          texture;
          special = Bspfile.int32 tl (o + 36) land 1 <> 0;
        })
  in
  let fl = lump Bspfile.faces in
  let surfaces =
    records fl 20 (fun (o : int) ->
        let first_edge = Bspfile.int32 fl (o + 4)
        and num_edges = Bspfile.short fl (o + 8) in
        let ti = texinfos.(Bspfile.short fl (o + 10)) in
        let name = ti.texture.tname in
        let kind =
          if String.length name >= 3 && String.sub name 0 3 = "sky" then Sky
          else if name <> "" && name.[0] = '*' then Turbulent
          else Normal
        in
        let texturemins, extents =
          if kind = Turbulent then ((-8192, -8192), (16384, 16384))
          else extents vertexes edge0 edge1 surfedges ti first_edge num_edges
        in
        {
          index = o / 20;
          plane = planes.(Bspfile.short fl o);
          back = Bspfile.short fl (o + 2) <> 0;
          first_edge;
          num_edges;
          texinfo = ti;
          kind;
          texturemins;
          extents;
          styles = Array.init 4 (fun (k : int) -> Bspfile.u8 fl (o + 12 + k));
          samples = Bspfile.int32 fl (o + 16);
          visframe = 0;
        })
  in
  let ml = lump Bspfile.marksurfaces in
  let marks = records ml 2 (Bspfile.ushort ml) in
  let ll = lump Bspfile.leafs in
  let leaves =
    records ll 28 (fun (o : int) ->
        let first = Bspfile.ushort ll (o + 20)
        and n = Bspfile.ushort ll (o + 22) in
        {
          lindex = o / 28;
          contents = contents_of (Bspfile.int32 ll o);
          visofs = Bspfile.int32 ll (o + 4);
          lmins = short_vec ll (o + 8);
          lmaxs = short_vec ll (o + 14);
          marks = Array.init n (fun (k : int) -> surfaces.(marks.(first + k)));
          lvisframe = 0;
          key = 0;
          lparent = None;
        })
  in
  let nl = lump Bspfile.nodes in
  let count = String.length nl / 24 in
  (* (the nodes made from the last: a node's children come after it in
   * qbsp's order, but nothing says so; made on demand instead) *)
  let nodes : node option array = Array.make count None in
  let rec node (k : int) : node =
    match nodes.(k) with
    | Some n -> n
    | None ->
        let o = k * 24 in
        let ch (c : int) : child =
          if c >= 0 then Node (node c) else Leaf leaves.(-1 - c)
        in
        let n =
          {
            nplane = planes.(Bspfile.int32 nl o);
            children =
              [| ch (Bspfile.short nl (o + 4)); ch (Bspfile.short nl (o + 6)) |];
            nmins = short_vec nl (o + 8);
            nmaxs = short_vec nl (o + 14);
            first_surface = Bspfile.ushort nl (o + 20);
            num_surfaces = Bspfile.ushort nl (o + 22);
            nvisframe = 0;
            nparent = None;
          }
        in
        nodes.(k) <- Some n;
        n
  in
  let nodes = Array.init count node in
  (* the parents (Mod_SetParent) *)
  Array.iter
    (fun (n : node) ->
      Array.iter
        (fun (c : child) ->
          match c with
          | Node c -> c.nparent <- Some n
          | Leaf l -> l.lparent <- Some n)
        n.children)
    nodes;
  (* hull 0 from the nodes (Mod_MakeHull0) *)
  let hull0 =
    let raw (o : int) (c : int) : int =
      let k = Bspfile.short nl (o + c) in
      if k >= 0 then k else Bspfile.int32 ll ((-1 - k) * 28)
    in
    {
      cplanes = Array.map (fun (n : node) -> n.nplane) nodes;
      front = Array.init count (fun (k : int) -> raw (k * 24) 4);
      back = Array.init count (fun (k : int) -> raw (k * 24) 6);
      clip_mins = zero;
      clip_maxs = zero;
    }
  in
  let cl = lump Bspfile.clipnodes in
  let ncl = String.length cl / 8 in
  let clip (mins : vec) (maxs : vec) : hull =
    {
      cplanes =
        Array.init ncl (fun (k : int) -> planes.(Bspfile.int32 cl (k * 8)));
      front = Array.init ncl (fun (k : int) -> Bspfile.short cl ((k * 8) + 4));
      back = Array.init ncl (fun (k : int) -> Bspfile.short cl ((k * 8) + 6));
      clip_mins = mins;
      clip_maxs = maxs;
    }
  in
  let hulls =
    [|
      hull0;
      clip { x = -16.; y = -16.; z = -24. } { x = 16.; y = 16.; z = 32. };
      clip { x = -32.; y = -32.; z = -24. } { x = 32.; y = 32.; z = 64. };
    |]
  in
  let sml = lump Bspfile.models in
  let submodels =
    records sml 64 (fun (o : int) ->
        {
          mins = vec_at sml o;
          maxs = vec_at sml (o + 12);
          origin = vec_at sml (o + 24);
          headnode =
            Array.init 4 (fun (k : int) -> Bspfile.int32 sml (o + 36 + (4 * k)));
          visleafs = Bspfile.int32 sml (o + 52);
          first_face = Bspfile.int32 sml (o + 56);
          num_faces = Bspfile.int32 sml (o + 60);
        })
  in
  {
    vertexes;
    edge0;
    edge1;
    surfedges;
    planes;
    textures;
    surfaces;
    nodes;
    leaves;
    hulls;
    submodels;
    visibility = lump Bspfile.visibility;
    lighting = lump Bspfile.lighting;
    entities = parse_entities (lump Bspfile.entities);
  }

(*****************************************************************************)
(* Queries *)
(*****************************************************************************)

let child (m : t) (k : int) : child =
  if k >= 0 then Node m.nodes.(k) else Leaf m.leaves.(-1 - k)

let submodel_root (m : t) (k : int) : child =
  child m m.submodels.(k).headnode.(0)

let leaf_at (m : t) (p : vec) : leaf =
  let rec walk (c : child) : leaf =
    match c with
    | Leaf l -> l
    | Node n ->
        if dot n.nplane.normal p -. n.nplane.dist > 0. then walk n.children.(0)
        else walk n.children.(1)
  in
  walk (submodel_root m 0)

(* (the world's leaves but the solid one: those the rows are of) *)
let visleafs (m : t) : int = m.submodels.(0).visleafs

let pvs (m : t) (l : leaf) : Bytes.t =
  let row = (visleafs m + 7) lsr 3 in
  let out = Bytes.make row '\000' in
  if l.lindex = 0 then out
  else if l.visofs < 0 || m.visibility = "" then Bytes.make row '\255'
  else begin
    (* a zero byte, then how many zero bytes: the rows are mostly
     * zeros, a leaf seeing few of the others *)
    let vis = m.visibility and i = ref l.visofs and o = ref 0 in
    while !o < row do
      let c = Char.code vis.[!i] in
      if c <> 0 then begin
        Bytes.set out !o vis.[!i];
        incr o;
        incr i
      end
      else begin
        o := !o + Char.code vis.[!i + 1];
        i := !i + 2
      end
    done;
    out
  end

let vertex (m : t) (s : surface) (i : int) : vec =
  let e = m.surfedges.(s.first_edge + i) in
  if e >= 0 then m.vertexes.(m.edge0.(e)) else m.vertexes.(m.edge1.(-e))
