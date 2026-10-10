(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/run/Script_modules.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_modules.mli *)

open Js_value
open Script_types

let source (t : t) (url : string) : string option = List.assoc_opt url t.module_sources

(* a module's address from what an import says, in the module at
 * [base]: what the page's import map says of it (the name itself, or
 * the longest "prefix/" it starts with), else a relative or whole
 * address, as a link's; a bare name ("react") that no map names is
 * none *)
let resolve (t : t) ~(base : string) (spec : string) : string =
  let prefixes =
    List.filter (fun (k, _) -> String.ends_with ~suffix:"/" k && String.starts_with ~prefix:k spec) t.import_map
    |> List.sort (fun (a, _) (b, _) -> compare (String.length b) (String.length a))
  in
  match (List.assoc_opt spec t.import_map, prefixes) with
  | Some url, _ -> url
  | None, (k, url) :: _ -> url ^ String.sub spec (String.length k) (String.length spec - String.length k)
  | None, [] ->
      let relative = List.exists (fun p -> String.starts_with ~prefix:p spec) [ "./"; "../"; "/" ] || String.contains spec ':' in
      if relative then Browser_url.resolve base spec
      else throw "TypeError" (Printf.sprintf "Failed to resolve module specifier \"%s\": relative references must start with \"/\", \"./\" or \"../\"" spec)

(* <script type=importmap>{"imports": {"react": "/lib/react.js", "lib/": "/lib/"}}: the
 * page's table from names to addresses, each resolved against the page *)
let read_import_map (t : t) (json : string) : unit =
  match Js_json.parse json with
  | exception _ -> ()
  | Object map -> (
      match get_own map "imports" with
      | Some (Object imports) ->
          t.import_map <-
            List.filter_map (fun k -> match get_own imports k with Some (String url) -> Some (k, Browser_url.resolve t.base url) | _ -> None) (keys imports)
      | _ -> ())
  | _ -> ()

(* the modules a text names, as addresses; those that cannot be one left out (the error is the run's) *)
let named (t : t) (url : string) (text : string) : string list =
  List.filter_map (fun spec -> match resolve t ~base:url spec with u -> Some u | exception Throw _ -> None) (Js_module.specifiers text)

(*****************************************************************************)
(* Fetching a graph *)
(*****************************************************************************)

let load (t : t) (url : string) (k : (unit, string) result -> unit) : unit =
  (* the addresses met in this load: a circle is not gone round *)
  let seen = ref [] in
  let rec need (url : string) (k : (unit, string) result -> unit) : unit =
    if List.mem url !seen then k (Ok ())
    else (
      seen := url :: !seen;
      (* a data: URL has its text in it (an import map's stand-in for a
       * module that is not there) *)
      let known = match source t url with Some text -> Some text | None -> Browser_url.data_url url in
      Option.iter (fun text -> if source t url = None then t.module_sources <- (url, text) :: t.module_sources) known;
      match known with
      | Some text -> deps url text k
      | None -> (
          (* asked for once, whoever wants it: those who come while it
           * is on its way wait for the same answer *)
          let come (r : (string, string) result) : unit = match r with Ok text -> deps url text k | Error why -> k (Error why) in
          match List.assoc_opt url t.module_asked with
          | Some waiting -> waiting := !waiting @ [ come ]
          | None ->
              let waiting = ref [ come ] in
              t.module_asked <- (url, waiting) :: t.module_asked;
              let tell (r : (string, string) result) : unit =
                t.module_asked <- List.remove_assoc url t.module_asked;
                List.iter (fun come -> come r) !waiting
              in
              ignore
                (Script_fetch.ask ~cors:true ~headers:[] ~ahead:(Some Js_module.ahead) t ~meth:"GET" ~url ~post:None (fun answer ->
                     match answer with
                     | Ok a when a.status / 100 = 2 ->
                         t.module_sources <- (url, a.body) :: t.module_sources;
                         tell (Ok a.body)
                     | Ok a -> tell (Error (Printf.sprintf "Failed to fetch the module %s (%d)" url a.status))
                     | Error why -> tell (Error (Printf.sprintf "Failed to fetch the module %s: %s" url why))))))
  (* what it names in turn; done when each is, with the first failure *)
  and deps (url : string) (text : string) (k : (unit, string) result -> unit) : unit =
    match named t url text with
    | [] -> k (Ok ())
    | names ->
        let left = ref (List.length names) and failure = ref None in
        List.iter
          (fun dep ->
            need dep (fun r ->
                (match r with Error why when !failure = None -> failure := Some why | _ -> ());
                decr left;
                if !left = 0 then k (match !failure with Some why -> Error why | None -> Ok ())))
          names
  in
  need url k

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

let modules (t : t) : Js_module.t =
  match t.modules with
  | Some m -> m
  | None ->
      let m = Js_module.create t.engine ~resolve:(resolve t) ~source:(source t) in
      (* import(): the graph fetched, then the promise settled, as a
       * task of its own *)
      Js_module.set_dynamic m (fun url ready failed ->
          load t url (fun r -> t.module_jobs <- t.module_jobs @ [ (fun () -> match r with Ok () -> ready () | Error why -> failed why) ]));
      t.modules <- Some m;
      m

let start (t : t) ~(url : string) (text : string option) : unit =
  let m = modules t in
  Option.iter (fun text -> t.module_sources <- (url, text) :: t.module_sources) text;
  load t url (fun r ->
      t.module_jobs <-
        t.module_jobs
        @ [ (fun () -> match r with Ok () -> ignore (Js_module.import m url) | Error why -> throw "TypeError" why) ])

let take_jobs (t : t) : (unit -> unit) list =
  let jobs = t.module_jobs in
  t.module_jobs <- [];
  jobs
