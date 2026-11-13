(* git's wire protocol, versions 0 and 1, as git9 speaks it (proto.c):
 * pkt-lines, capabilities, and the transports.
 *
 * A pkt-line is its length in 4 hex digits (the 4 digits included)
 * followed by its bytes. "0000", the flush, ends a list. The first
 * line of the server's references carries its capabilities after a
 * NUL:
 *
 *   003f1f7a7a47... HEAD\000multi_ack side-band-64k symref=HEAD:refs/heads/master
 *   003d0e4c55d6... refs/heads/master
 *   0000
 *
 * Here are the transports:
 * - a local repository: git9 runs its own git/serve -w over a pipe,
 *   and here mini-git runs serve -w over a socketpair;
 * - git://: TCP, port 9418, with the request
 *   "git-upload-pack /path\000host=h\000" as the first pkt-line;
 * - ssh: "ssh host git-upload-pack path", where $GIT_SSH, as C git
 *   reads it, is run instead of ssh;
 * - smart http(s): git9 opens URLs through Plan 9's webfs, and
 *   mini-git through curl, run as a child process:
 *
 *   GET  URL/info/refs?service=git-upload-pack   the references, after
 *        "# service=git-upload-pack" and a flush, if the content type
 *        says smart http (otherwise "dumb http protocol not supported")
 *   POST URL/git-upload-pack                    the whole request,
 *        written to a file during the write phase; the reply is read
 *        as curl gives it
 *
 * Both use git9's user agent, git/2.24.1 (github answers smart http to
 * a git/ agent). git9 dials https whatever the URL says. mini-git
 * keeps http as http, so that it can be tested with a local git
 * http-backend (deliberate difference 7).
 *
 * terminology:
 * Dumb and smart. git's first way over http needed no git on the
 * server. The repository's files were served as they are, and the
 * client fetched the refs, then objects or whole packs, with one
 * request for each (the dumb protocol). The smart protocol is the
 * conversation above, the same as git://'s, carried in two requests,
 * with a program on the server that makes a pack of just what is
 * lacking.
 *
 * modern:
 * In versions 0 and 1 the server speaks first and lists every
 * reference it has. On a repository with many branches, that is
 * megabytes before the client has said what it wants. Version 2 (git,
 * 2018) turns it around: the client sends commands (ls-refs with a
 * prefix, fetch). git9 does not speak it, and neither does mini-git. *)

type direction = Upload | Receive

type http = { post : string; service : string; mutable request : string option; mutable temps : string list }

type transport = Local | Git | Ssh | Http of http

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.pipe >

type conn = {
  caps : caps;
  transport : transport;
  mutable rd : Unix.file_descr;
  mutable wr : Unix.file_descr;
  mutable child : int option;
  mutable multiack : bool;
  mutable sideband : bool;
  mutable sideband64k : bool;
  mutable report : bool;
  mutable symref : (string * string) option;
}

exception Error of string

type pkt = Flush | Pkt of string

(* a pkt-line; "ERR msg" raises Error *)
val read_pkt : conn -> pkt
val write_pkt : conn -> string -> unit
val flush : conn -> unit

(* n bytes, or fewer at the end of the stream *)
val read_raw : conn -> int -> string
val write_raw : conn -> string -> unit

(* the capabilities after the first line's NUL *)
val parse_caps : conn -> string -> unit

(* git9's parseuri gives (proto, host, port, path); "host:path" is ssh *)
val parse_uri : string -> (string * string * string * string) option

(* [print] gets git9's "uri: \"...\"" line, printed for a remote *)
val connect : < caps; .. > -> print:(string -> unit) -> string -> direction -> conn

(* http's two halves (git9's writephase and readphase). After the
 * references, what is written goes into the request; then the request
 * is posted and the reply is read. Both do nothing for the other
 * transports. *)
val write_phase : conn -> unit
val read_phase : conn -> unit

(* the connection over standard input and output, for serve *)
val stdio : < caps; .. > -> conn

(* closes the write side, so that the other side reads to its end *)
val close_write : conn -> unit
val close : conn -> unit

(* the first position of [sub] in [s] from [from] *)
val find_sub : string -> string -> int -> int option

(* git's rules for a reference's name (git9's okref) *)
val okref : string -> bool
