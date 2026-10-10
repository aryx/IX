(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-lynx: the web in a terminal (CERN's Line Mode Browser, 1991;
 * Lynx, University of Kansas, 1992), after the author's mini-chrome's
 * tools/lynx: a page as lines of text, its links numbered, a number
 * typed to follow one. A browser with the hard parts left out, no
 * fonts, no boxes, no pictures, and so the shortest path through one:
 *
 *     an address --Http_client--> bytes --Charset--> text
 *                --Html_tree--> the tree --Line_mode--> lines, links
 *                a number typed --Url.resolve--> an address
 *
 * An address without "http://" is a file when there is one of that
 * name, else a host. Styles and scripts are not read; a form cannot be
 * filled.
 *
 * A page shown (show): its title and address, its lines, and the
 * addresses of its links by their numbers, each made whole against
 * the page's own:
 *
 *     Menu  (http://localhost/menu.html)
 *
 *                                     Menu
 *
 *     Soup of the day. See the recipes[1] or go back home[2].
 *
 *     [1] http://localhost/recipes.html
 *     [2] http://localhost/
 *
 * What is typed after a page (step): a link's number to go there, an
 * address to go to it, b to come back, q to leave, nothing to see
 * the page again. The pages come through are a list, the one shown
 * first: b drops its head, and there is no forward.
 *
 * Where it stands: mini-netscape's way from an address to pixels
 * (its header draws it) with the middle taken out. No Cascade, no
 * Box_layout, no Hit: Line_mode walks the tree once and fills lines
 * of a fixed width, a link being found again by its number where a
 * window needs the place of a click. The network under it is the
 * same (Http_client, ix's own TLS), and so is the tree (Html_tree),
 * which is why it came first (plan_browser.md, stage 4: HTML, before
 * the pictures, CSS and the window). Of its terminal it asks only
 * lines read and written (Console): no cursor moved, no key read
 * alone.
 *
 * cs-history:
 * The first browser most people could run was not the one with a
 * window. Tim Berners-Lee's WorldWideWeb (1990) needed a NeXT; CERN's
 * Line Mode Browser (1991, begun by Nicola Pellow, a student there)
 * worked on any terminal and was what was ported everywhere, with
 * the numbered links kept here. Lynx (University of Kansas, 1992)
 * replaced the numbers by a cursor moved from link to link with the
 * arrows, and is still used: on a console, and by a script (lynx
 * -dump, which our -dump is after).
 *
 * References: the Line Mode Browser (libwww, 1991); lynx(1). *)

type caps = < Cap.network; Cap.open_in; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-lynx [-dump] [-w width] address
  -dump  the page said, and no question asked after it
  -w     the width of a line (80)
After a page: a link's number to go there, an address to go to it,
b to come back, q to leave, nothing to see the page again."

(* a page read: its address (after the redirections), its title, its
 * lines and its links' addresses *)
type page = { url : string; title : string; lines : string list; links : string list }
(* the pages come through, the one shown first *)
type session = page list
type step = Go of session | Stay of string | Quit

(* the text of the first <title> *)
let title_of (tree : Dom.element) : string =
  let rec find (e : Dom.element) : string option =
    if e.name = "title" then Some (String.trim (Dom.text_content e))
    else List.find_map (fun (c : Dom.node) -> match c with Dom.Element c -> find c | Dom.Text _ -> None) e.children
  in
  match find tree with Some t -> t | None -> ""

let is_web (address : string) : bool = String.starts_with ~prefix:"http://" address || String.starts_with ~prefix:"https://" address

(* a link's address, against its page's *)
let resolve (base : string) (href : string) : string =
  match (Url.parse base, Url.parse href) with
  | Ok base, Ok href -> Url.to_string (Url.resolve base href)
  | _ -> href

let open_ (caps : < Cap.network; Cap.open_in; Cap.readdir; .. >) (width : int) (address : string) : (page, string) result =
  let ( let* ) = Result.bind in
  let file = if String.starts_with ~prefix:"file://" address then String.sub address 7 (String.length address - 7) else address in
  let* url, content_type, bytes =
    if (not (is_web address)) && Sys.file_exists file && not (Sys.is_directory file) then
      (* (its whole path: a link of the page is resolved against it) *)
      let whole = if Filename.is_relative file then Filename.concat (FS.getcwd caps ()) file else file in
      Ok ("file://" ^ whole, None, FS.read caps (Fpath.v file))
    else
      let address = if is_web address then address else "http://" ^ address in
      let* url, (r : Http.response) = Http_client.fetch caps ~post:None address in
      if r.status >= 400 then Error (Printf.sprintf "%s: %d %s" url r.status r.reason) else Ok (url, Http.header "Content-Type" r.headers, r.body)
  in
  let text = Charset.decode content_type bytes in
  let html = match content_type with Some ct -> String.starts_with ~prefix:"text/html" (String.lowercase_ascii ct) | None -> not (String.ends_with ~suffix:".txt" url) in
  (* a text that is not HTML: its lines as they are *)
  if not html then Ok { url; title = ""; lines = String.split_on_char '\n' text; links = [] }
  else
    let tree = Html_tree.of_string text in
    let shown = Line_mode.render width tree in
    Ok { url; title = title_of tree; lines = shown.lines; links = List.map (resolve url) shown.links }

(* its title, its lines, and the addresses of its links by their numbers *)
let show (p : page) : string =
  let head = if p.title = "" then p.url else Printf.sprintf "%s  (%s)" p.title p.url in
  let links = List.mapi (fun i l -> Printf.sprintf "[%d] %s" (i + 1) l) p.links in
  String.concat "\n" ((head :: "" :: p.lines) @ (if links = [] then [] else "" :: links)) ^ "\n"

let step (caps : < Cap.network; Cap.open_in; Cap.readdir; .. >) (width : int) (session : session) (typed : string) : step =
  let go address = match open_ caps width address with Ok p -> Go (p :: session) | Error why -> Stay why in
  match (String.trim typed, session) with
  | ("q" | "quit"), _ -> Quit
  | "", _ -> Go session
  | "b", _ :: (_ :: _ as before) -> Go before
  | "b", _ -> Stay "no page before this one"
  | typed, here :: _ when int_of_string_opt typed <> None -> (
      match if int_of_string typed >= 1 then List.nth_opt here.links (int_of_string typed - 1) else None with
      | Some link -> go link
      | None -> Stay (Printf.sprintf "no link %s: this page has %d" typed (List.length here.links)))
  | address, _ -> go address

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let rec options dump width address args =
    match args with
    | [] -> ( match address with Some a -> Some (dump, width, a) | None -> None)
    | "-dump" :: rest -> options true width address rest
    | "-w" :: w :: rest -> ( match int_of_string_opt w with Some w when w > 10 -> options dump w address rest | _ -> None)
    | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
    | a :: rest -> options dump width (Some a) rest
  in
  match options false 80 None (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"
  | Some (dump, width, address) -> (
      match open_ caps width address with
      | Error why -> Console.eprint caps ("mini-lynx: " ^ why ^ "\n"); Exit.Err "page"
      | Ok page ->
          let say (s : string) : unit = Console.print caps s; flush (Console.stdout caps) in
          say (show page);
          (* -dump: no question; a question to nobody (the input's end) ends too *)
          let rec loop (session : session) : unit =
            say "\nlink number, address, b (back), q (quit): ";
            match In_channel.input_line (Console.stdin caps) with
            | None -> ()
            | Some typed -> (
                match step caps width session typed with
                | Quit -> ()
                | Stay why -> say (why ^ "\n"); loop session
                | Go session -> say (show (List.hd session)); loop session)
          in
          if not dump then loop [ page ];
          Exit.OK)

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
