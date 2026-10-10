(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's libs/network/protocols/Cookie.ml; ~script said (no optional argument), the days by Civil, the date's seconds in floats (docs/plans/plan_browser.md) *)

(* See Cookie.mli *)

type cookie = {
  name : string;
  value : string;
  domain : string;
  host_only : bool;
  path : string;
  expires : float option;
  secure : bool;
  http_only : bool;
  created : float;
}

type jar = cookie list

(*****************************************************************************)
(* Dates *)
(*****************************************************************************)

let months = [ "jan"; "feb"; "mar"; "apr"; "may"; "jun"; "jul"; "aug"; "sep"; "oct"; "nov"; "dec" ]

(* RFC 6265 section 5.1.1: the tokens between delimiters, each tried
 * as a time, a day of the month, a month, a year, the first of each
 * kind kept *)
let date (s : string) : float option =
  let delimiter c = not ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = ':') in
  let tokens = List.filter (( <> ) "") (String.split_on_char ' ' (String.map (fun c -> if delimiter c then ' ' else c) s)) in
  let digits t = t <> "" && String.for_all (fun c -> c >= '0' && c <= '9') t in
  (* a token's leading digits, as the RFC reads "09Jun" or "2021GMT" *)
  let leading t =
    let n = ref 0 in
    while !n < String.length t && t.[!n] >= '0' && t.[!n] <= '9' do incr n done;
    String.sub t 0 !n
  in
  let time = ref None and day = ref None and month = ref None and year = ref None in
  List.iter
    (fun t ->
      match String.split_on_char ':' t with
      | [ h; m; sec ] when !time = None && digits h && digits m && digits (leading sec) && leading sec <> "" ->
          time := Some (int_of_string h, int_of_string m, int_of_string (leading sec))
      | _ -> (
          let n = leading t in
          (* (List.find_index is OCaml 5.1's) *)
          let prefix = if String.length t >= 3 then String.lowercase_ascii (String.sub t 0 3) else "" in
          let named = List.find_map (fun (i, m) -> if m = prefix then Some i else None) (List.mapi (fun i m -> (i, m)) months) in
          match (String.length n, named) with
          | (1 | 2), _ when !day = None -> day := Some (int_of_string n)
          | _, Some i when !month = None && n = "" -> month := Some (i + 1)
          | (2 | 3 | 4), _ when !year = None -> year := Some (int_of_string n)
          | _ -> ()))
    tokens;
  match (!time, !day, !month, !year) with
  | Some (h, mi, sec), Some d, Some m, Some y ->
      (* two digits: 70 to 99 are the 1900s, 0 to 69 the 2000s *)
      let y = if y >= 70 && y <= 99 then y + 1900 else if y >= 0 && y <= 69 then y + 2000 else y in
      if d < 1 || d > 31 || y < 1601 || h > 23 || mi > 59 || sec > 59 then None
      else
        (* in floats: the seconds since 1970 do not fit an int of 31 bits *)
        Some ((float_of_int (Civil.days_from_civil { year = y; month = m; day = d }) *. 86400.) +. float_of_int ((h * 3600) + (mi * 60) + sec))
  | _ -> None

(*****************************************************************************)
(* Where a cookie goes *)
(*****************************************************************************)

let host_of (url : Url.t) : string = match url.authority with Some a -> String.lowercase_ascii a.host | None -> ""

(* an address in numbers has no domain above it *)
let is_address (host : string) : bool =
  host <> "" && (host.[0] = '[' || String.for_all (fun c -> (c >= '0' && c <= '9') || c = '.') host)

(* section 5.1.3: the host is the domain, or under it *)
let domain_matches ~(host : string) (domain : string) : bool =
  host = domain || ((not (is_address host)) && String.ends_with ~suffix:("." ^ domain) host)

(* section 5.1.4: the directory of the page asked for *)
let default_path (url : Url.t) : string =
  if url.path = "" || url.path.[0] <> '/' then "/"
  else match String.rindex url.path '/' with 0 -> "/" | i -> String.sub url.path 0 i

(* the request's path is the cookie's, or under it *)
let path_matches ~(request : string) (path : string) : bool =
  let request = if request = "" then "/" else request in
  request = path
  || String.starts_with ~prefix:path request
     && (String.ends_with ~suffix:"/" path || request.[String.length path] = '/')

(*****************************************************************************)
(* Set-Cookie *)
(*****************************************************************************)

let parse ~(now : float) (url : Url.t) (value : string) : cookie option =
  let host = host_of url in
  let pair s = match String.index_opt s '=' with Some i -> (String.trim (String.sub s 0 i), String.trim (String.sub s (i + 1) (String.length s - i - 1))) | None -> (String.trim s, "") in
  match String.split_on_char ';' value with
  | [] -> None
  | first :: attributes -> (
      let name, v = match String.index_opt first '=' with Some _ -> pair first | None -> ("", String.trim first) in
      let attributes = List.map (fun a -> let k, v = pair a in (String.lowercase_ascii k, v)) attributes in
      (* the last of a name wins *)
      let attribute k = List.assoc_opt k (List.rev attributes) in
      let secure = attribute "secure" <> None and http_only = attribute "httponly" <> None in
      let expires =
        match Option.bind (attribute "max-age") int_of_string_opt with
        | Some seconds -> Some (if seconds <= 0 then 0. else now +. float_of_int seconds)
        | None -> Option.bind (attribute "expires") date
      in
      let path = match attribute "path" with Some p when p <> "" && p.[0] = '/' -> p | _ -> default_path url in
      (* a Domain: said without its dot; the host must be it or under
       * it, and it must not be a name every site is under *)
      let domain =
        match Option.map (fun d -> String.lowercase_ascii (if String.starts_with ~prefix:"." d then String.sub d 1 (String.length d - 1) else d)) (attribute "domain") with
        | None | Some "" -> Some (host, true)
        | Some d when d = host -> Some (host, not (String.contains d '.'))
        | Some d when String.contains d '.' && domain_matches ~host d -> Some (d, false)
        | Some _ -> None
      in
      match domain with
      | Some (domain, host_only) when name <> "" && host <> "" && String.length value <= 4096 && not (secure && url.scheme <> Some "https") ->
          Some { name; value = v; domain; host_only; path; expires; secure; http_only; created = now }
      | _ -> None)

let alive ~(now : float) (jar : jar) : jar = List.filter (fun c -> match c.expires with Some e -> e > now | None -> true) jar

(* so many kept, the oldest forgotten: a browser's are 180 a site and
 * 3,000 in all *)
let most = 3000

let store ~(now : float) ~(script : bool) (url : Url.t) (value : string) (jar : jar) : jar =
  match parse ~now url value with
  | None -> jar
  | Some c when script && c.http_only -> jar
  | Some c ->
      let same (o : cookie) = o.name = c.name && o.domain = c.domain && o.path = c.path in
      if script && List.exists (fun o -> same o && o.http_only) jar then jar
      else
        let dead = match c.expires with Some e -> e <= now | None -> false in
        let jar =
          match List.find_opt same jar with
          (* the one it replaces keeps its age and its place: the order
           * they are sent in *)
          | Some old -> if dead then List.filter (fun o -> not (same o)) jar else List.map (fun o -> if same o then { c with created = old.created } else o) jar
          | None -> if dead then jar else c :: jar
        in
        List.filteri (fun i _ -> i < most) (alive ~now jar)

(*****************************************************************************)
(* Cookie *)
(*****************************************************************************)

let for_url ~(now : float) ~(script : bool) (url : Url.t) (jar : jar) : cookie list =
  let host = host_of url and https = url.scheme = Some "https" in
  (* the oldest first (the jar has the newest first), for those of one age *)
  List.rev (alive ~now jar)
  |> List.filter (fun c ->
         (if c.host_only then host = c.domain else domain_matches ~host c.domain)
         && path_matches ~request:url.path c.path
         && ((not c.secure) || https)
         && not (script && c.http_only))
  |> List.stable_sort (fun a b ->
         match compare (String.length b.path) (String.length a.path) with 0 -> compare a.created b.created | n -> n)

let header ~(now : float) ~(script : bool) (url : Url.t) (jar : jar) : string option =
  match for_url ~now ~script url jar with
  | [] -> None
  | cookies -> Some (String.concat "; " (List.map (fun c -> c.name ^ "=" ^ c.value) cookies))
