(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex.mli *)

open Latex_state
open Latex_input
open Latex_output
open Latex_names

(* the lines' length, in ens: a page's of 6 inches, a terminal's 60
 * columns *)
let line_length (paper : bool) : float = if paper then 86.4 else 60.

(* an entry of the table of contents begins here: its anchor *)
let entry (t : t) =
  if t.body then begin
    t.entries <- t.entries + 1;
    anchor t ("toc:" ^ string_of_int t.entries) false
  end

(* ---------------------------------------------------------------- *)
(* The reading *)
(* ---------------------------------------------------------------- *)

let rec run (t : t) =
  let going = ref true in
  while !going do
    match peek t with
    | None -> going := false
    | Some c -> step t c
  done

and step (t : t) (c : char) =
  if at_line_start t && special_line t c then ()
  else
    match c with
    | '\\' -> advance t; command t (name t)
    | '{' -> advance t; t.groups <- t.look :: t.groups
    | '}' -> advance t; (match t.groups with l :: rest -> t.look <- l; t.groups <- rest | [] -> ())
    | '%' -> ignore (rest_of_line t); (let rec spaces () = match peek t with Some (' ' | '\t') -> advance t; spaces () | _ -> () in spaces ())
    | '~' -> advance t; text t "\xc2\xa0"
    | '$' ->
        advance t;
        if peek t = Some '$' then begin
          advance t;
          let raw = until t "$$" in
          Latex_math.display t raw
        end else Latex_math.math t (until t "$")
    | '[' when looking t "[[" ->
        skip t 2;
        let raw = until t "]]" in
        let rec more (s : string) : string = if peek t = Some ']' then begin advance t; more (s ^ "]") end else s in
        put t (Doc.Text (mono_of t.look.style, more raw))
    | '[' when looking t "[<" && (match t.input with f :: _ -> (match String.index_from_opt f.s f.i '\n', String.index_from_opt f.s f.i '>' with nl, Some gt -> (match nl with Some nl -> gt < nl | None -> true) && gt + 1 < String.length f.s && f.s.[gt + 1] = ']' | _ -> false) | [] -> false) ->
        skip t 2;
        put t (Doc.Text (mono_of t.look.style, until t ">]"))
    | '\n' ->
        advance t;
        let rec blank (k : int) : int option = match ahead t k with Some (' ' | '\t') -> blank (k + 1) | Some '\n' -> Some k | _ -> None in
        (match blank 0 with
         | Some _ when (match t.input with f :: _ -> f.i < String.length f.s | [] -> false) ->
             let rec all () = match blank 0 with Some k -> skip t (k + 1); all () | None -> () in
             all ();
             par t
         | _ -> space t)
    | ' ' | '\t' | '\r' -> advance t; space t
    | '-' when t.look.style.font <> Doc.Mono && looking t "---" -> skip t 3; text t "\xe2\x80\x94"
    | '-' when t.look.style.font <> Doc.Mono && looking t "--" -> skip t 2; text t "\xe2\x80\x93"
    | '`' when looking t "``" -> skip t 2; text t "\xe2\x80\x9c"
    | '\'' when looking t "''" -> skip t 2; text t "\xe2\x80\x9d"
    | _ ->
        (* (the letters to the next mark, at once) *)
        (match t.input with
         | f :: _ ->
             let n = String.length f.s in
             let plain (c : char) : bool = match c with '\\' | '{' | '}' | '%' | '~' | '$' | '[' | '\n' | ' ' | '\t' | '\r' | '-' | '`' | '\'' -> false | _ -> true in
             let rec go (j : int) : int = if j < n && plain f.s.[j] then go (j + 1) else j in
             let e = max (f.i + 1) (go f.i) in
             text t (String.sub f.s f.i (e - f.i));
             f.i <- e
         | [] -> ())

(* A line that is not LaTeX's: a chunk of code (noweb), a file put
 * here (syncweb's #include), the author's notes to himself, which a
 * book does not show. *)
and special_line (t : t) (c : char) : bool =
  if c = '<' && looking t "<<" then begin
    let line = match t.input with f :: _ -> (match String.index_from_opt f.s f.i '\n' with Some e -> String.sub f.s f.i (e - f.i) | None -> String.sub f.s f.i (String.length f.s - f.i)) | [] -> "" in
    let line = String.trim line in
    let n = String.length line in
    if n > 5 && String.sub line (n - 3) 3 = ">>=" then begin
      ignore (rest_of_line t);
      Noweb.chunk t (String.trim (String.sub line 2 (n - 5)));
      true
    end else false
  end
  else if c = '#' && looking t "#include" then begin
    let line = rest_of_line t in
    (match String.index_opt line '"' with
     | Some a -> (match String.index_from_opt line (a + 1) '"' with Some b -> file t (String.sub line (a + 1) (b - a - 1)) | None -> ())
     | None -> ());
    true
  end
  else if c = '\\' && (looking t "\\l " || looking t "\\t " || looking t "\\n " || looking t "\\l\n" || looking t "\\t\n" || looking t "\\n\n") then begin ignore (rest_of_line t); true end
  else if c = '@' && (looking t "@\n" || looking t "@ ") then begin ignore (rest_of_line t); true end
  else false

(* a file read where it is named *)
and file (t : t) (path : string) =
  match (match t.load path with Some s -> Some s | None -> t.load (path ^ ".tex")) with
  | Some s -> if List.length t.input > 100 then say t ("too many files inside each other: " ^ path) else t.input <- { s; i = 0; stop = false; file = Filename.basename path; line = 1; counts = true } :: t.input
  | None -> say t ("no file " ^ path)

(* ---------------------------------------------------------------- *)
(* The commands *)
(* ---------------------------------------------------------------- *)

and expand (t : t) (m : macro) =
  let first = match m.default with Some d when m.args > 0 -> [ (match opt t with Some o -> o | None -> d) ] | _ -> [] in
  let rest = List.init (m.args - List.length first) (fun _ -> arg t) in
  if List.length t.input > 200 then say t "macros inside each other without end" else push t (substitute m.body (first @ rest))

and define (t : t) (replace : bool) =
  ignore (star t);
  let n = named (arg t) in
  let args = match opt t with Some k -> (match int_of_string_opt (String.trim k) with Some k -> k | None -> 0) | None -> 0 in
  let default = opt t in
  let body = arg t in
  if replace || not (Hashtbl.mem t.macros n) then Hashtbl.replace t.macros n { args; default; body }

and heading (t : t) (level : int) =
  let starred = star t in
  ignore (opt t);
  let raw = arg t in
  par t;
  let level = if t.report then level else max 1 level in
  let number =
    if starred || level > 3 then ""
    else begin
      (match level with
       | 0 -> t.chapter <- t.chapter + 1; t.section <- 0; t.subsection <- 0; t.subsubsection <- 0; t.figure <- 0; t.table <- 0
       | 1 -> t.section <- t.section + 1; t.subsection <- 0; t.subsubsection <- 0
       | 2 -> t.subsection <- t.subsection + 1; t.subsubsection <- 0
       | _ -> t.subsubsection <- t.subsubsection + 1);
      let chapter = if t.appendix then String.make 1 (Char.chr (64 + min 26 (max 1 t.chapter))) else string_of_int t.chapter in
      let parts = (if t.report then [ chapter ] else []) @ (if level >= 1 then [ string_of_int t.section ] else []) @ (if level >= 2 then [ string_of_int t.subsection ] else []) @ (if level >= 3 then [ string_of_int t.subsubsection ] else []) in
      String.concat "." parts
    end in
  if number <> "" then t.here <- number;
  if not t.final && t.body && not starred then t.known.toc <- (level, number, raw) :: t.known.toc;
  let size = match level with -1 -> 6 | 0 -> 6 | 1 -> 4 | 2 -> 2 | _ -> 0 in
  let style : Doc.style = { font = Doc.Bold; size; shift = 0 } in
  let title = with_look t { style; caps = false; center = false } raw in
  let label = if number = "" then [] else [ Doc.Text (style, (if level = 0 then (if t.appendix then "Appendix " else "Chapter ") ^ number ^ "\xc2\xa0\xc2\xa0" else number ^ "\xc2\xa0\xc2\xa0")) ] in
  if t.body then begin
    emit t (Doc.Space (if level <= 0 then 2. else if level = 1 then 1. else 0.6));
    if not starred then entry t;
    emit t (Doc.Heading (1, label @ title));
    emit t (Doc.Space (if level <= 0 then 0.8 else 0.3))
  end

and begin_env (t : t) (env_name : string) =
  let gather (e : env) = t.envs <- e :: t.envs; (match e.outer with Some _ -> t.out <- fresh () | None -> ()) in
  let make (gathers : bool) : env = { name = env_name; outer = (if gathers then Some t.out else None); saved = t.look; started = false; tag = []; count = 0; caption = None; after = None } in
  match env_name with
  | "document" -> t.body <- true
  | "itemize" | "enumerate" | "description" | "thebibliography" ->
      if env_name = "thebibliography" then begin ignore (arg t); push t "\\section*{References}" ; run_pushed t end;
      par t; gather (make true)
  | "figure" | "figure*" | "table" | "table*" -> ignore (opt t); par t; gather (make true)
  | "center" | "flushright" | "flushleft" -> par t; gather (make false); if env_name = "center" then t.look <- { t.look with center = true }
  | "quote" | "quotation" | "verse" | "abstract" -> par t; gather (make true)
  | "minipage" -> ignore (opt t); ignore (arg t); par t; gather (make false); t.look <- { t.look with center = false }
  | "tabular" | "tabular*" | "tabularx" | "longtable" -> Latex_table.tabular t env_name
  | "tikzpicture" | "picture" -> ignore (to_end t env_name true); say t ("a picture drawn by commands (" ^ env_name ^ ")"); par t; block t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = [ Doc.Text (t.look.style, "[a picture]") ] })
  | "equation" | "equation*" | "displaymath" | "align" | "align*" | "eqnarray" | "eqnarray*" -> Latex_math.display t (to_end t env_name false)
  | _ ->
      (match Hashtbl.find_opt t.verbatims env_name, Hashtbl.find_opt t.environments env_name with
       | Some small, _ ->
           ignore (opt t);
           let raw = to_end t env_name false in
           verbatim t (if small then -1 else 0) raw
       | None, Some (m, after) ->
           let e = make false in
           e.after <- Some after;
           gather e;
           expand t m
       | None, None -> say_once t ("\\begin{" ^ env_name ^ "}"); gather (make false))

(* (a heading asked for by a text put in front: read before going on) *)
and run_pushed (t : t) =
  match t.input with
  | f :: _ when not f.counts && not f.stop -> let raw = String.sub f.s f.i (String.length f.s - f.i) in t.input <- List.tl t.input; capture t raw
  | _ -> ()

and verbatim (t : t) (size : int) (raw : string) =
  par t;
  let lines = String.split_on_char '\n' raw in
  let lines = match lines with "" :: rest -> rest | l -> l in
  let lines = match List.rev lines with l :: rest when String.trim l = "" -> List.rev rest | _ -> lines in
  let style : Doc.style = { font = Doc.Mono; size; shift = 0 } in
  block t (lines_as_they_are t size (List.map (fun l -> if l = "" then [] else [ Doc.Text (style, l) ]) lines))

(* a list's item is ended: it goes to the list's place *)
and end_item (t : t) (e : env) =
  par t;
  (match e.outer with
   | Some outer ->
       if e.started then begin
         let wide = cols t (match e.name with "itemize" -> 3. | "enumerate" -> 4. | _ -> 5.) in
         (match outer.blocks with [] | Doc.Space _ :: _ | Doc.Heading _ :: _ -> () | _ -> outer.blocks <- Doc.Space (gap t) :: outer.blocks);
         outer.blocks <- Doc.Tagged { tag = e.tag; width = wide; body = List.rev t.out.blocks } :: outer.blocks
       end;
       t.out <- fresh ()
   | None -> ())

and item (t : t) =
  let label = opt t in
  match List.find_opt (fun (e : env) -> e.outer <> None && (e.name = "itemize" || e.name = "enumerate" || e.name = "description" || e.name = "thebibliography")) t.envs with
  | None -> say_once t "\\item outside a list"
  | Some e ->
      (* (what was opened in the last item and not closed is closed) *)
      let rec close () = match t.envs with top :: _ when top != e -> end_env t top.name; close () | _ -> () in
      close ();
      end_item t e;
      e.started <- true;
      e.count <- e.count + 1;
      t.look <- e.saved;
      e.tag <-
        (match label, e.name with
         | Some l, _ -> with_look t { t.look with style = { t.look.style with font = Doc.Bold } } l
         | None, "enumerate" -> [ Doc.Text (t.look.style, string_of_int e.count ^ ".") ]
         | None, _ -> [ Doc.Text (t.look.style, "\xe2\x80\xa2") ])

and end_env (t : t) (env_name : string) =
  if env_name = "document" then begin par t; t.input <- [] end
  else
    match t.envs with
    | e :: rest when e.name = env_name ->
        (match e.after with
         | Some after -> e.after <- None; push t ("\\end{" ^ env_name ^ "}"); push t after
         | None ->
             (match e.outer with
              | None -> par t
              | Some outer ->
                  (match env_name with
                   | "itemize" | "enumerate" | "description" | "thebibliography" -> end_item t e; t.out <- outer
                   | _ ->
                       par t;
                       let body = List.rev t.out.blocks in
                       t.out <- outer;
                       (match env_name with
                        | "figure" | "figure*" | "table" | "table*" ->
                            let caption = match e.caption with Some c -> [ Doc.Space (gap t); Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = c } ] | None -> [] in
                            block t (Doc.Keep (body @ caption))
                        | "abstract" ->
                            block t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = [ Doc.Text ({ font = Doc.Bold; size = 0; shift = 0 }, "Abstract") ] });
                            block t (Doc.Indent (cols t 4., body))
                        | _ -> block t (Doc.Indent (cols t 4., body)))));
             t.look <- e.saved;
             t.envs <- rest)
    | _ ->
        if List.exists (fun (e : env) -> e.name = env_name) t.envs then begin
          (* (what was opened inside it and not closed is closed) *)
          let rec close () = match t.envs with top :: _ when top.name <> env_name -> end_env t top.name; close () | _ -> () in
          close ();
          end_env t env_name
        end else say_once t ("\\end{" ^ env_name ^ "} with no \\begin")

(* The references: the entries cited, in the order they were, each
 * with its number. *)
and bibliography (t : t) (files : string) =
  par t;
  let entries = List.concat_map (fun (f : string) ->
    let f = String.trim f in
    match (match t.load (f ^ ".bib") with Some s -> Some s | None -> t.load f) with
    | Some s -> Bib.read s
    | None -> say t ("no file " ^ f ^ ".bib"); []) (String.split_on_char ',' files) in
  push t (if t.report then "\\chapter*{References}" else "\\section*{References}");
  run_pushed t;
  let roman = t.look.style in
  let italic : Doc.style = { roman with font = Doc.Italic } in
  List.iteri (fun (k : int) (key : string) ->
    match List.find_opt (fun (e : Bib.entry) -> e.key = key) entries with
    | None -> say t ("\\cite{" ^ key ^ "}: not in the bibliography")
    | Some e ->
        let field (name : string) : string option = match List.assoc_opt name e.fields with Some v when String.trim v <> "" -> Some v | _ -> None in
        let part (style : Doc.style) (name : string) (after : string) : Doc.inline list =
          match field name with Some v -> with_look t { style; caps = false; center = false } v @ [ Doc.Text (roman, after) ] | None -> [] in
        let where = List.concat_map (fun (name : string) -> part roman name ", ") [ "booktitle"; "journal"; "publisher"; "institution"; "organization"; "howpublished"; "edition" ] in
        let body = part roman "author" ". " @ part italic "title" ". " @ where @ part roman "year" ". " @ part roman "note" "" in
        block t (Doc.Tagged { tag = [ Doc.Text (roman, "[" ^ string_of_int (k + 1) ^ "]") ]; width = cols t 5.; body = [ Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body } ] })) (List.rev t.known.cites)

(* A picture from a file: the file as it is named, or with the name's
 * end that LaTeX leaves out; as wide as its options say (width=, a
 * length; scale=), or a pixel a point. *)
and includegraphics (t : t) (options : string) (f : string) =
  let line = if t.paper then 86.4 else 60. in
  let inch = if t.paper then 14.4 else 10. in
  let option (name : string) : string option =
    List.find_map (fun (o : string) ->
      match String.index_opt o '=' with
      | Some i when String.trim (String.sub o 0 i) = name -> Some (String.trim (String.sub o (i + 1) (String.length o - i - 1)))
      | _ -> None) (String.split_on_char ',' options) in
  let found = List.find_map (fun (e : string) -> match t.load (f ^ e) with Some bytes -> Some bytes | None -> None) [ ""; ".png"; ".jpg"; ".jpeg"; ".gif" ] in
  let fails (why : string) = say t ("a picture from a file (" ^ f ^ "): " ^ why); put t (Doc.Text (t.look.style, "[picture: " ^ Filename.basename f ^ "]")) in
  match found with
  | None -> fails (if t.load (f ^ ".pdf") <> None || Filename.check_suffix f ".pdf" then "a PDF file, not read as a picture" else "no such file")
  | Some bytes ->
      let scale = match option "scale" with Some s -> (match float_of_string_opt s with Some v -> v | None -> 1.) | None -> 1. in
      let wide = match option "width" with Some w -> Latex_table.length t line w /. inch | None -> 0. in
      (match Doc_image.picture (Filename.basename f) bytes wide (72. /. scale) (line /. inch) with
       | Ok picture -> par t; block t picture
       | Error why -> fails why)

and cite_label (t : t) (key : string) : string =
  match Hashtbl.find_opt t.known.bibitems key with
  | Some l -> l
  | None ->
      if not (List.mem key t.known.cites) then t.known.cites <- key :: t.known.cites;
      let order = List.rev t.known.cites in
      let rec index (l : string list) (k : int) : int = match l with [] -> 0 | x :: rest -> if x = key then k else index rest (k + 1) in
      string_of_int (index order 1)

and command (t : t) (w : string) =
  if w <> "" && is_letter w.[0] then after_name t;
  match Hashtbl.find_opt t.macros w with
  | Some m -> expand t m
  | None ->
      let n = String.length w in
      if n > 4 && String.sub w (n - 4) 4 = "true" && Hashtbl.mem t.flags (String.sub w 0 (n - 4)) then Hashtbl.replace t.flags (String.sub w 0 (n - 4)) true
      else if n > 5 && String.sub w (n - 5) 5 = "false" && Hashtbl.mem t.flags (String.sub w 0 (n - 5)) then Hashtbl.replace t.flags (String.sub w 0 (n - 5)) false
      else if n > 2 && String.sub w 0 2 = "if" && Hashtbl.mem t.flags (String.sub w 2 (n - 2)) then (if not (Hashtbl.find t.flags (String.sub w 2 (n - 2))) then skip_branch t true)
      else builtin t w

and builtin (t : t) (w : string) =
  let style = t.look.style in
  let font (f : Doc.font) = t.look <- { t.look with style = { style with font = f }; caps = false } in
  match w with
  (* the text's own characters *)
  | "&" | "%" | "$" | "#" | "_" | "{" | "}" -> text t w
  | " " | "," | ";" | ":" | "\n" -> text t " "
  | "\\" -> ignore (star t); ignore (opt t); if t.out.line <> [] then put t Doc.Break
  | "newline" | "linebreak" -> ignore (opt t); if t.out.line <> [] then put t Doc.Break
  | "'" | "`" | "^" | "\"" | "~" | "c" | "v" ->
      let a = arg t in
      (match List.assoc_opt (w ^ a) accents with Some s -> text t s | None -> text t a)
  | "xspace" -> (match peek t with Some ('.' | ',' | ':' | ';' | '!' | '?' | '\'' | ')' | ']' | '}' | '/' | '-' | '~' | ' ' | '\n' | '\t') | None -> () | Some _ -> text t " ")
  (* the looks *)
  | "em" -> font (if style.font = Doc.Italic then Doc.Roman else Doc.Italic)
  | "it" | "itshape" | "sl" -> font Doc.Italic
  | "bf" | "bfseries" -> font Doc.Bold
  | "tt" | "ttfamily" -> font Doc.Mono
  | "rm" | "rmfamily" | "sf" | "sffamily" | "upshape" | "mdseries" -> font Doc.Roman
  | "sc" | "scshape" -> t.look <- { t.look with caps = true }
  | "underline" | "mbox" | "fbox" | "centerline" | "hbox" | "uline" -> push t ("{" ^ arg t ^ "}")
  | "makebox" | "framebox" -> ignore (opt t); ignore (opt t); push t ("{" ^ arg t ^ "}")
  | "parbox" -> ignore (opt t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "resizebox" -> ignore (star t); ignore (arg t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "scalebox" | "textcolor" | "colorbox" | "raisebox" -> ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "multirow" -> ignore (arg t); ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "multicolumn" ->
      let k = arg t in
      let spec = arg t in
      t.span <- (match int_of_string_opt (String.trim k) with Some k -> max 1 k | None -> 1);
      t.cell_align <- Some (if String.contains spec 'c' then Doc.Center else if String.contains spec 'r' then Doc.Right else Doc.Left);
      push t ("{" ^ arg t ^ "}")
  | "ensuremath" -> Latex_math.math t (arg t)
  | "textcircled" -> push t ("({" ^ arg t ^ "})")
  (* the author's notes to himself, wherever on a line: not a book's *)
  | "l" | "t" | "n" -> ignore (rest_of_line t); space t
  | "centering" -> t.look <- { t.look with center = true }
  | "begingroup" | "bgroup" -> t.groups <- t.look :: t.groups
  | "endgroup" | "egroup" -> (match t.groups with l :: rest -> t.look <- l; t.groups <- rest | [] -> ())
  (* the text's parts *)
  | "part" -> heading t (-1)
  | "chapter" -> heading t 0
  | "section" -> heading t 1
  | "subsection" -> heading t 2
  | "subsubsection" -> heading t 3
  | "paragraph" | "subparagraph" -> ignore (star t); let raw = arg t in par t; push t ("{\\bf " ^ raw ^ "}\\ \\ ")
  | "appendix" -> t.appendix <- true; t.chapter <- 0; t.section <- 0
  | "addcontentsline" ->
      ignore (arg t);
      let kind = String.trim (arg t) in
      let raw = arg t in
      let level = match kind with "part" -> -1 | "chapter" -> 0 | "section" -> 1 | "subsection" -> 2 | _ -> 3 in
      if not t.final && t.body then t.known.toc <- ((if t.report then level else max 1 level), "", raw) :: t.known.toc;
      entry t
  | "par" -> par t
  | "bigskip" | "medskip" | "vskip" -> par t; emit t (Doc.Space (gap t))
  | "hrule" -> par t; block t (Doc.Picture { wide = 6.; high = 0.05; marks = [ Doc.Stroke [ (0., 0.02); (6., 0.02) ] ] })
  | "begin" -> begin_env t (arg t)
  | "end" -> end_env t (arg t)
  | "item" -> item t
  | "bibitem" ->
      let label = opt t in
      let key = arg t in
      (match List.find_opt (fun (e : env) -> e.name = "thebibliography") t.envs with
       | Some e ->
           let l = match label with Some l -> l | None -> string_of_int (e.count + 1) in
           if not t.final then Hashtbl.replace t.known.bibitems key l;
           push t ("\\item[{[" ^ l ^ "]}]")
       | None -> ())
  | "caption" ->
      ignore (star t);
      ignore (opt t);
      let raw = arg t in
      (match List.find_opt (fun (e : env) -> e.outer <> None && e.name <> "itemize" && e.name <> "enumerate" && e.name <> "description") t.envs with
       | Some e ->
           let is_table = String.length e.name >= 5 && String.sub e.name 0 5 = "table" in
           if is_table then t.table <- t.table + 1 else t.figure <- t.figure + 1;
           let number = (if t.report then string_of_int t.chapter ^ "." else "") ^ string_of_int (if is_table then t.table else t.figure) in
           t.here <- number;
           let look : look = { style = Doc.plain; caps = false; center = false } in
           e.caption <- Some (Doc.Text (Doc.plain, (if is_table then "Table " else "Figure ") ^ number ^ ": ") :: with_look t look raw)
       | None -> say_once t "\\caption outside a figure")
  | "footnote" | "thanks" ->
      ignore (opt t);
      let raw = arg t in
      t.notes <- t.notes + 1;
      let number = string_of_int t.notes in
      let saved = t.out in
      let inner = with_look t { style = Doc.plain; caps = false; center = false } raw in
      t.out <- saved;
      if t.body then t.out.feet <- Doc.Footnote [ Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body = Doc.Text (Doc.plain, number ^ ". ") :: inner } ] :: t.out.feet;
      put t (Doc.Text ({ style with size = style.size - 2; shift = style.shift + 1 }, number))
  (* what names another place *)
  | "label" -> let k = arg t in if not t.final then Hashtbl.replace t.known.labels k t.here; anchor t ("label:" ^ k) false
  | "ref" | "autoref" | "cref" | "Cref" | "eqref" ->
      let k = arg t in
      (match Hashtbl.find_opt t.known.labels k with
       | Some v -> text t v
       | None -> say t ("\\ref{" ^ k ^ "} (no such label)"); text t "??")
  (* (on a terminal, which has no sheets, a ?) *)
  | "pageref" -> let k = arg t in put t (Doc.Page (style, "label:" ^ k, "?"))
  | "cite" | "citep" | "citet" | "nocite" ->
      let note = opt t in
      let keys = List.map String.trim (String.split_on_char ',' (arg t)) in
      let labels = List.map (cite_label t) keys in
      if w <> "nocite" then text t ("[" ^ String.concat ", " labels ^ (match note with Some n -> ", " ^ Doc.words (inlines_of t n) | None -> "") ^ "]")
  | "bibliography" -> bibliography t (arg t)
  | "url" | "path" | "nolinkurl" ->
      let raw = arg t in
      let b = Buffer.create (String.length raw) in
      String.iteri (fun i c -> if not (c = '\\' && i + 1 < String.length raw && (match raw.[i + 1] with '%' | '#' | '_' | '&' | '~' -> true | _ -> false)) then Buffer.add_char b c) raw;
      put t (Doc.Text (mono_of style, Buffer.contents b))
  | "href" -> ignore (arg t); push t ("{" ^ arg t ^ "}")
  | "verb" ->
      ignore (star t);
      (match peek t with
       | Some d -> advance t; put t (Doc.Text (mono_of style, until t (String.make 1 d)))
       | None -> ())
  | "tableofcontents" ->
      par t;
      push t (if t.report then "\\chapter*{Contents}" else "\\section*{Contents}");
      run_pushed t;
      List.iteri (fun (k : int) ((level, number, raw) : int * string * string) ->
        if level <= 2 then begin
          let st : Doc.style = { font = (if level <= 0 then Doc.Bold else Doc.Roman); size = 0; shift = 0 } in
          let body = (if number = "" then [] else [ Doc.Text (st, number ^ "\xc2\xa0\xc2\xa0") ]) @ with_look t { style = st; caps = false; center = false } raw in
          let by = cols t (float_of_int (3 * max 0 level)) in
          (* on paper, the sheet's number at the line's end: a table of a
           * row, the title filled in what is left (a terminal's has no
           * sheets, and its lines are as they were) *)
          let p =
            if not t.paper then Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body }
            else begin
              let cell (align : Doc.align) (filled : bool) (body : Doc.inline list) : Doc.cell = { align; span = 1; filled; body } in
              let entry = [ cell Doc.Left true body; cell Doc.Right false [ Doc.Page (st, "toc:" ^ string_of_int (k + 1), "") ] ] in
              Doc.Table { centered = false; boxed = false; widths = [ line_length true -. by -. 8.; 5. ]; rows = [ Doc.Cells entry ] }
            end in
          if level <= 0 then emit t (Doc.Space (gap t));
          emit t (if level <= 0 then p else Doc.Indent (by, [ p ]))
        end) (List.rev t.known.toc);
      emit t (Doc.Space 1.)
  | "nowebindex" -> Noweb.index t
  | "includegraphics" ->
      let options = opt t in
      let f = String.trim (arg t) in
      includegraphics t (match options with Some o -> o | None -> "") f
  | "VerbatimInput" | "verbatiminput" | "lstinputlisting" ->
      ignore (opt t);
      let f = arg t in
      (match t.load f with Some s -> verbatim t (-1) s | None -> say t ("no file " ^ f))
  | "input" | "include" -> file t (String.trim (arg t))
  (* the title *)
  | "title" -> t.title <- arg t
  | "author" -> t.author <- arg t
  | "date" -> t.date <- arg t
  | "maketitle" ->
      par t;
      push t ("\\begin{center}{\\Large\\bf " ^ t.title ^ "\\par}\\bigskip{" ^ t.author ^ "\\par}" ^ (if String.trim t.date = "" then "" else "\\bigskip{" ^ t.date ^ "\\par}") ^ "\\end{center}\\bigskip ")
  (* what is defined *)
  | "newcommand" | "renewcommand" | "DeclareRobustCommand" -> define t true
  | "providecommand" -> define t false
  | "def" | "gdef" | "edef" ->
      blanks t;
      if peek t = Some '\\' then begin
        advance t;
        let n = name t in
        let pattern = match t.input with f :: _ -> (let e = match String.index_from_opt f.s f.i '{' with Some e -> e | None -> String.length f.s in let p = String.sub f.s f.i (e - f.i) in skip t (e - f.i); p) | [] -> "" in
        let args = String.fold_left (fun k c -> if c = '#' then k + 1 else k) 0 pattern in
        if String.exists (fun c -> not (c = '#' || is_digit c || is_blank c)) pattern then say t ("\\def\\" ^ n ^ " with a pattern");
        Hashtbl.replace t.macros n { args; default = None; body = arg t }
      end
  | "let" ->
      blanks t;
      let a = named (arg t) in
      blanks t;
      if peek t = Some '=' then advance t;
      let b = named (arg t) in
      (match Hashtbl.find_opt t.macros b with Some m -> Hashtbl.replace t.macros a m | None -> ())
  | "newif" ->
      blanks t;
      let n = named (arg t) in
      if String.length n > 2 then Hashtbl.replace t.flags (String.sub n 2 (String.length n - 2)) false
  | "newenvironment" | "renewenvironment" ->
      let n = arg t in
      let args = match opt t with Some k -> (match int_of_string_opt (String.trim k) with Some k -> k | None -> 0) | None -> 0 in
      let default = opt t in
      let body = arg t in
      let after = arg t in
      Hashtbl.replace t.environments n ({ args; default; body }, after)
  | "DefineVerbatimEnvironment" -> let n = arg t in ignore (arg t); ignore (arg t); Hashtbl.replace t.verbatims n true
  | "iftrue" -> ()
  | "iffalse" -> skip_branch t true
  | "else" -> skip_branch t false
  | "fi" -> ()
  | "(" -> Latex_math.math t (until t "\\)")
  | "[" -> Latex_math.display t (until t "\\]")
  | _ ->
      (match List.assoc_opt w sizes, List.assoc_opt w with_text, List.assoc_opt w symbols, List.assoc_opt w nothing with
       | Some size, _, _, _ -> t.look <- { t.look with style = { style with size } }
       | None, Some declaration, _, _ -> push t ("{\\" ^ declaration ^ " " ^ arg t ^ "}")
       | None, None, Some s, _ -> text t s
       | None, None, None, Some takes ->
           String.iter (fun c -> match c with 'm' -> ignore (arg t) | 'o' -> ignore (opt t) | _ -> ignore (star t)) takes;
           if w = "vspace" || w = "smallskip" then par t
       | None, None, None, None ->
           if String.length w > 2 && String.sub w 0 2 = "if" then begin say_once t ("\\" ^ w ^ " (a condition not declared: taken as false)"); skip_branch t true end
           else say_once t ("\\" ^ w))

(* ---------------------------------------------------------------- *)
(* A document *)
(* ---------------------------------------------------------------- *)

let once (paper : bool) (load : string -> string option) (known : known) (final : bool) (source : string) : Doc.block list * (int * string) list =
  let contains (s : string) (w : string) : bool =
    let n = String.length s and m = String.length w in
    let rec go (i : int) : bool = i + m <= n && (String.sub s i m = w || go (i + 1)) in
    go 0 in
  let t = {
    run = (fun _ -> ()); paper; load; known; final; input = [ { s = source; i = 0; stop = false; file = ""; line = 1; counts = true } ]; out = fresh ();
    look = { style = Doc.plain; caps = false; center = false }; groups = []; envs = []; macros = Hashtbl.create 64; flags = Hashtbl.create 16; environments = Hashtbl.create 8;
    verbatims = Hashtbl.create 8; body = not (contains source "\\begin{document}"); said = []; unknown = Hashtbl.create 16; report = contains source "{report}" || contains source "{book}";
    appendix = false; chapter = 0; section = 0; subsection = 0; subsubsection = 0; figure = 0; table = 0; notes = 0; chunk = 0; entries = 0; here = ""; title = ""; author = ""; date = "";
    span = 1; cell_align = None } in
  List.iter (fun (n : string) -> Hashtbl.replace t.verbatims n false) [ "verbatim"; "verbatim*"; "Verbatim"; "lstlisting"; "alltt" ];
  Hashtbl.replace t.verbatims "vdiagram" true;
  t.run <- run;
  run t;
  par t;
  (* (what was opened and not closed is closed) *)
  List.iter (fun (e : env) -> if List.memq e t.envs then end_env t e.name) t.envs;
  (List.rev t.out.blocks, List.rev t.said)

let read (paper : bool) (load : string -> string option) (source : string) : Doc.t * (int * string) list =
  let known = { labels = Hashtbl.create 64; toc = []; defs = Hashtbl.create 64; uses = Hashtbl.create 64; cites = []; bibitems = Hashtbl.create 16 } in
  ignore (once paper load known false source);
  let body, said = once paper load known true source in
  ({ header = ("", "", ""); width = line_length paper; margin = 0.; sub = 0.; body }, said)
