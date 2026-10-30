(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Browser_helpers.mli *)

type rule = { site : string option; kind : string option; run : string list }

let defaults : rule list =
  List.map (fun site -> { site = Some site; kind = None; run = [ "mpv"; "%u" ] }) [ "youtube.com/watch"; "youtube.com/shorts/"; "youtu.be/" ]
  @ List.map (fun prog -> { site = None; kind = Some "application/pdf"; run = [ prog; "%s" ] }) [ "mini-page"; "page" ]
  (* a mailto: link to mini-pim's composer, filled from it *)
  @ List.map (fun prog -> { site = Some "mailto:"; kind = None; run = [ prog; "write=%u" ] }) [ "mini-pim"; "pim" ]

let words (s : string) : string list = List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.trim s))

(* "helper what command...": what has a '/' and no '.' before it is a
 * content type (application/pdf), else a site (youtube.com/watch) *)
let of_preferences (text : string) : rule list =
  List.filter_map
    (fun line ->
      match words line with
      | "helper" :: what :: (_ :: _ as run) ->
          let is_type = match String.index_opt what '/' with Some i -> not (String.contains (String.sub what 0 i) '.') | None -> false in
          Some (if is_type then { site = None; kind = Some (String.lowercase_ascii what); run } else { site = Some what; kind = None; run })
      | _ -> None)
    (String.split_on_char '\n' text)

let to_preferences (rules : rule list) : string =
  String.concat ""
    (List.map (fun r -> Printf.sprintf "helper %s %s\n" (match (r.site, r.kind) with Some s, _ -> s | None, Some k -> k | None, None -> "") (String.concat " " r.run)) rules)

let of_mailcap (text : string) : rule list =
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if line = "" || line.[0] = '#' then None
      else
        match String.split_on_char ';' line with
        | kind :: command :: _ when words command <> [] -> Some { site = None; kind = Some (String.lowercase_ascii (String.trim kind)); run = words command }
        | _ -> None)
    (String.split_on_char '\n' text)

(* "https://www.youtube.com/watch?v=x": "www.youtube.com", "/watch?v=x" *)
let host_and_path (url : string) : (string * string) option =
  match String.index_opt url ':' with
  | Some i when String.length url > i + 2 && String.sub url i 3 = "://" ->
      let rest = String.sub url (i + 3) (String.length url - i - 3) in
      let cut = match String.index_opt rest '/' with Some j -> j | None -> String.length rest in
      Some (String.sub rest 0 cut, String.sub rest cut (String.length rest - cut))
  | _ -> None

let matches_site (site : string) (url : string) : bool =
  let host, path = match String.index_opt site '/' with Some i -> (String.sub site 0 i, String.sub site i (String.length site - i)) | None -> (site, "") in
  match host_and_path url with
  | Some (h, p) -> (h = host || String.ends_with ~suffix:("." ^ host) h) && String.starts_with ~prefix:path p
  | None -> false

(* ix: a site ending in ':' is a scheme's (mailto:) *)
let matches (site : string) (url : string) : bool =
  let n = String.length site in
  if n > 0 && site.[n - 1] = ':' then
    String.length url >= n && String.lowercase_ascii (String.sub url 0 n) = String.lowercase_ascii site
  else matches_site site url

let for_url (rules : rule list) (url : string) : rule option =
  List.find_opt (fun r -> match r.site with Some s -> matches s url | None -> false) rules

let for_type (rules : rule list) (kind : string) : rule option =
  let kind = String.lowercase_ascii kind in
  let major = match String.index_opt kind '/' with Some i -> String.sub kind 0 i | None -> kind in
  List.find_opt (fun r -> match r.kind with Some k -> k = kind || k = major ^ "/*" | None -> false) rules

let name (r : rule) : string = match r.run with p :: _ -> Filename.basename p | [] -> ""

(* %u and %s anywhere in a word (write=%u), as a mailcap's command *)
let command (r : rule) ~(url : string) ~(file : string option) : string list =
  let s = match file with Some f -> f | None -> url in
  let rec subst (w : string) (i : int) : string =
    match String.index_from_opt w i '%' with
    | Some k when k + 1 < String.length w && (w.[k + 1] = 'u' || w.[k + 1] = 's') ->
        let by = if w.[k + 1] = 'u' then url else s in
        let w' = String.sub w 0 k ^ by ^ String.sub w (k + 2) (String.length w - k - 2) in
        subst w' (k + String.length by)
    | Some k when k + 1 < String.length w -> subst w (k + 1)
    | _ -> w
  in
  List.map (fun w -> subst w 0) r.run

let available (caps : < Cap.env; .. >) (rules : rule list) : rule list =
  let path = try CapSys.getenv caps "PATH" with Not_found -> "/bin:/usr/bin" in
  let dirs = String.split_on_char ':' path in
  let found (prog : string) = if String.contains prog '/' then Sys.file_exists prog else List.exists (fun d -> d <> "" && Sys.file_exists (Filename.concat d prog)) dirs in
  List.filter (fun r -> match r.run with p :: _ -> found p | [] -> false) rules

(* the programs started and not yet seen to end *)
let running : int list ref = ref []

let run (caps : < Cap.exec; Cap.wait; .. >) (command : string list) : unit =
  running := List.filter (fun pid -> match CapUnix.waitpid caps [ Unix.WNOHANG ] pid with 0, _ -> true | _ -> false | exception Unix.Unix_error _ -> false) !running;
  match command with
  | prog :: args ->
      Logs.info (fun m -> m "running %s" (String.concat " " command));
      (* (not Procs.spawn: OCaml 5's Unix.fork fails once the tab's worker,
       * a domain, was spawned: Worker_spawn) *)
      (try running := Procs.create_process caps prog args ~stdin:Unix.stdin ~stdout:Unix.stdout :: !running
       with Unix.Unix_error (e, _, _) -> Logs.warn (fun m -> m "%s: %s" prog (Unix.error_message e)))
  | [] -> ()
