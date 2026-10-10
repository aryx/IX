(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-curl: a URL's bytes on standard output (curl, Daniel Stenberg,
 * 1998), after the author's mini-chrome's tools/curl: the request made
 * by Http_client, over Tcp, or inside ix's own TLS 1.3 for https://.
 * A redirection is followed with a GET, ten at most. With -v, what is
 * sent and the answer's head on standard error, as curl ("> ", "< ").
 *
 * It is the browser's network stack with no browser around it: what
 * the address bar does before anything is shown, each step a module
 * that can be looked at on its own.
 *
 *     mini-curl -v https://example.com/
 *        Url           the string cut: https, example.com, 443, /
 *        Dns, Tcp      the name's address, a connection
 *        Tls_client    the handshake (Tls13), the certificate's chain
 *                      checked against the system's roots (X509)
 *        Http          "GET / HTTP/1.1" written, the status line,
 *                      the headers and the body read
 *     * example.com, port 443, TLS             on standard error
 *     > GET / HTTP/1.1
 *     > Host: example.com
 *     > ...
 *     < HTTP/1.1 200 OK
 *     < Content-Type: text/html
 *     < ...
 *     <!doctype html>...                       on standard output
 *
 * A redirection, by mini-httpd, which answers so for a directory
 * named without its slash (the tests' served.sh has the first):
 *
 *     mini-curl -i U/sub      HTTP/1.1 301 Moved Permanently
 *                             Location: /sub/
 *     mini-curl -L -v U/sub   > GET /sub HTTP/1.1  ...  < HTTP/1.1 301 ...
 *                             > GET /sub/ HTTP/1.1 ...  < HTTP/1.1 200 OK
 *                             and /sub/'s page
 *
 * The flags are [usage]'s, and their letters curl's. Less than
 * curl's hundreds: no HEAD, no header of one's own, no upload, no
 * cookie kept between two requests (mini-chrome's has a jar),
 * HTTP/1.1 only, and the body as the server sent it (Http asks for
 * no compression).
 *
 * design:
 * A program for one layer of a system is how the layer gets tested
 * and understood. The browser draws a page or it does not; with
 * mini-curl the question becomes which of five modules failed, and
 * the answer is on the screen: no address, a connection refused, a
 * certificate not trusted, a 404, a body that is not what was
 * expected. And every test of the browser's network is a shell
 * script comparing two programs' output, this one's and the system's
 * curl's.
 *
 * Reference: curl(1), whose flags' letters these are; Daniel
 * Stenberg's history of it is told in Http_client.mli. *)

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-curl [-i] [-L] [-v] [-f] [-d data] [-o file] [--cacert file] url
  -i  the answer's head before its body
  -L  a redirection followed
  -v  the request and the answer's head said on standard error
  -f  status 22 and no body when the server answers 400 or more
  -d  data posted (application/x-www-form-urlencoded)
  -o  the body written to file
  --cacert  the roots trusted for https://, in the system's place (PEM)"

type options = { head : bool; follow : bool; verbose : bool; fail : bool; data : string option; output : string option; cacert : string option; url : string option }

let rec options (o : options) (args : string list) : (options, string) result =
  match args with
  | [] -> Ok o
  | ("-i" | "--include") :: rest -> options { o with head = true } rest
  | ("-L" | "--location") :: rest -> options { o with follow = true } rest
  | ("-v" | "--verbose") :: rest -> options { o with verbose = true } rest
  | ("-f" | "--fail") :: rest -> options { o with fail = true } rest
  | ("-d" | "--data") :: data :: rest -> options { o with data = Some data } rest
  | ("-o" | "--output") :: file :: rest -> options { o with output = Some file } rest
  | "--cacert" :: file :: rest -> options { o with cacert = Some file } rest
  | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> Error (Printf.sprintf "%s: not a flag of mine\n%s" flag usage)
  | url :: rest -> if o.url = None then options { o with url = Some url } rest else Error usage

(* "HTTP/1.1 200 OK" and the headers, a line each *)
let head_lines (r : Http.response) : string list =
  Printf.sprintf "%s %d %s" r.version r.status r.reason :: List.map (fun (k, v) -> k ^ ": " ^ v) r.headers

(* a request's head: its bytes up to the empty line, a line each *)
let request_lines (bytes : string) : string list =
  let rec go lines = match lines with [] | "" :: _ -> [] | l :: rest -> l :: go rest in
  go (List.map (fun l -> if String.ends_with ~suffix:"\r" l then String.sub l 0 (String.length l - 1) else l) (String.split_on_char '\n' bytes))

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let ( let* ) = Result.bind in
  let complain (s : string) : unit = Console.eprint caps (s ^ "\n") in
  (* one request at a time, each said with -v *)
  let rec fetch (o : options) ~(post : (string * string) option) (url : Url.t) (left : int) : (Http.response list, string) result =
    (if o.verbose then
       match Http_client.prepare ~post url with
       | Ok (host, port, bytes) ->
           complain (Printf.sprintf "* %s, port %d%s" host port (if url.scheme = Some "https" then ", TLS" else ""));
           List.iter (fun l -> complain ("> " ^ l)) (request_lines bytes)
       | Error _ -> ());
    let* (r : Http.response) = Http_client.once caps ~post url in
    if o.verbose then List.iter (fun l -> complain ("< " ^ l)) (head_lines r);
    match (o.follow && Http.is_redirect r.status, Http.header "Location" r.headers) with
    | true, Some location ->
        if left = 0 then Error "too many redirections"
        else
          let* next = Url.parse location in
          let* rest = fetch o ~post:None (Url.resolve url next) (left - 1) in
          Ok (r :: rest)
    | _ -> Ok [ r ]
  in
  let result =
    let* o = options { head = false; follow = false; verbose = false; fail = false; data = None; output = None; cacert = None; url = None } (List.tl (Array.to_list argv)) in
    let* url = match o.url with Some u -> Ok u | None -> Error usage in
    (* example.com is http://example.com *)
    let url = if String.starts_with ~prefix:"http://" url || String.starts_with ~prefix:"https://" url then url else "http://" ^ url in
    let* parsed = Url.parse url in
    (match o.cacert with Some file -> Tls_client.trust_file caps file | None -> ());
    let post = Option.map (fun d -> ("application/x-www-form-urlencoded", d)) o.data in
    let* answers = fetch o ~post parsed 10 in
    let last = List.nth answers (List.length answers - 1) in
    if o.fail && last.status >= 400 then Error (Printf.sprintf "the server answered %d" last.status)
    else begin
      (* -i: every answer's head, a redirection's too, as curl -i -L *)
      if o.head then List.iter (fun r -> Console.print caps (String.concat "\r\n" (head_lines r) ^ "\r\n\r\n")) answers;
      (match o.output with None -> Console.print caps last.body | Some file -> FS.write caps (Fpath.v file) last.body);
      Ok ()
    end
  in
  match result with
  | Ok () -> Exit.OK
  | Error why -> complain ("mini-curl: " ^ why); Exit.Err "curl"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
