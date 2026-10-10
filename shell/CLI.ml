(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Eval.caps; Cap.argv; Cap.exit; Cap.stdout >

(* plan9port's rcmain (/usr/lib/plan9/etc/rcmain, as 9base installs it) *)
let rcmain = {|# rcmain: Plan 9 on Unix version
if(~ $#home 0) home=$HOME
if(~ $#home 0) home=/
if(~ $#ifs 0) ifs=IFS
switch($#prompt){
case 0
	prompt=('% ' '	')
case 1
	prompt=($prompt '	')
}
if(~ $rcname ?.out ?.rc */?.rc */?.out) prompt=('broken! ' '	')
if(flag p) path=(/bin /usr/bin)
if not{
	finit
	# should be taken care of by rc now, but leave just in case
}
fn sigexit
if(! ~ $#cflag 0){
	if(flag l && test -r $home/lib/profile) . $home/lib/profile
	status=''
	eval $cflag
	exit $status
}
if(flag i){
	if(flag l && test -r $home/lib/profile) . $home/lib/profile
	status=''
	if(! ~ $#* 0) . $*
	. -i '/dev/stdin'
	exit $status
}
if(flag l && test -r $home/lib/profile) . $home/lib/profile
if(~ $#* 0){
	. /dev/stdin
	exit $status
}
status=''
. $*
exit $status
|}

(* its ifs line is a blank, a tab and a newline, which a {| |} string
 * would not show *)
let rcmain =
  match String.split_on_char '\n' rcmain with
  | lines ->
      String.concat "\n"
        (List.map (fun l -> if l = "if(~ $#ifs 0) ifs=IFS" then "if(~ $#ifs 0) ifs=' \t\n'" else l) lines)

(* Plan 9's own (/rc/lib/rcmain), where rc runs on Plan 9: the
 * standard input is '#d/0', there is no $HOME nor /usr/bin *)
let rcmain_plan9 = {|# rcmain: Plan 9 version
if(~ $#home 0) home=/
if(~ $#ifs 0) ifs=' 	
'
switch($#prompt){
case 0
	prompt=('% ' '	')
case 1
	prompt=($prompt '	')
}
if(~ $rcname ?.out) prompt=('broken! ' '	')
if(flag p) path=/bin
if not{
	finit
	if(~ $#path 0) path=(. /bin)
}
fn sigexit
if(! ~ $#cflag 0){
	if(flag l && /bin/test -r $home/lib/profile) . $home/lib/profile
	status=''
	eval $cflag
}
if not if(flag i){
	if(flag l && /bin/test -r $home/lib/profile) . $home/lib/profile
	status=''
	if(! ~ $#* 0) . $*
	. -i '#d/0'
}
if not if(~ $#* 0) . '#d/0'
if not{
	status=''
	. $*
}
exit $status
|}

let rcmain = if Sys.os_type = "Plan9" then rcmain_plan9 else rcmain

let usage = "usage: rc [-eiIlrvxp] [-c arg] [-m rcmain] [file [arg ...]]"

(* -h: the usage, the flags, and the language by example, as it runs *)
let help = {|usage: mini-rc [-eiIlrvxp] [-c cmd] [-m rcmain] [file [arg ...]]
Plan 9's rc, faithfully: runs the file, the -c command, or the terminal's
commands (with a prompt). -e: a failed command ends rc; -x: each command
printed; -i, -I: interactive, or not; -l: a login shell ($home/lib/profile).
The language, by example, one line after the other at its prompt:
  x=(a b c); echo $x $#x $x(2)        a b c 3 b (a variable is a list)
  echo $x^.c                          a.c b.c c.c
  for(i in a b) echo $i               a, then b
  if(~ $x(1) a) echo yes; if not echo no
  fn greet { echo hello $1 }; greet you
  x=`{echo one two}; echo $#x         2: a command's output, its words
  { echo a; echo b } > f; cat f       a, then b
  ls /nonexistent >[2] /dev/null || echo failed: $status
|}

let run (caps : < caps; .. >) (argv : string array) : int =
  Builtin.init ();
  let env = Env.create () in
  Env.import env (CapUnix.environment caps ());
  let argv0 = if Array.length argv > 0 then argv.(0) else "rc" in
  let main_file = ref None in
  let rec flags = function
    | "-c" :: cmd :: rest -> Env.set env "cflag" [ cmd ]; flags rest
    | "-m" :: file :: rest -> main_file := Some file; flags rest
    | a :: rest when String.length a > 1 && a.[0] = '-' && a <> "--" ->
        String.iteri (fun i c -> if i > 0 then Env.set_flag env c true) a;
        flags rest
    | "--" :: rest -> Some rest
    | rest -> Some rest
  in
  match flags (List.tl (Array.to_list argv)) with
  | None -> prerr_endline usage; 1
  | Some args ->
      Env.set env "*" args;
      Env.set env "rcname" [ argv0 ];
      Env.set env "pid" [ string_of_int (Unix.getpid ()) ];
      if not (Env.flag env 'I') && Env.get env "cflag" = [] && args = [] && Unix.isatty Unix.stdin then
        Env.set_flag env 'i' true;
      Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> Eval.interrupted := true));
      let t = Eval.create caps ~argv0 env in
      let text =
        match !main_file with
        | None -> rcmain
        | Some f -> FS.read caps (Fpath.v f)
      in
      let finish status =
        (* sigexit, if defined, runs once on the way out *)
        (match Env.fn env "sigexit" with
         | Some body ->
             Env.set_fn env "sigexit" None;
             Env.set_status env status;
             (try Eval.run t body with _ -> ())
         | None -> ());
        flush stdout;
        Process.code status
      in
      match Eval.source t ~name:(Some "rcmain") ~interactive:false (Lexer.of_string text) with
      | () -> finish (Env.status env)
      | exception Eval.Exit s -> finish s
      | exception (Eval.Error m | Word.Error m) ->
          if m <> "" then Eval.eprint (Printf.sprintf "rc (%s): %s\n" argv0 m);
          (* claude: an error ends rc without its sigexit, as 9base's *)
          Env.set_fn env "sigexit" None;
          finish "error"

let main (caps : < caps; .. >) (argv : string array) : int =
  match Array.to_list argv with
  | [ _; ("-h" | "--help") ] -> Console.print caps help; 0
  | _ -> run caps argv
