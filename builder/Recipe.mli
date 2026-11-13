(* Running a recipe: the job, its environment, how it is printed, and
 * the process that runs it.
 *
 * A job is one recipe to run: the rule it comes from, and the names it
 * is run with. For hello.5 from %.5: %.c, the recipe sees:
 *
 *     target=hello.5      the targets being made (a rule a b: c makes
 *                         both at once, if both are out of date)
 *     prereq=hello.c      all the prerequisites
 *     newprereq=          the prerequisites newer than a target
 *     stem=hello          the stem
 *     stem0..stem8        the groups (:R:); stem9 is empty
 *     alltarget=          every target of the rule
 *     nproc=0             the slot running it
 *     pid=                mk's own pid
 *
 * The recipe also sees every variable of the mkfile and of mk's
 * environment, except those assigned with X=U=... A list is exported
 * with its words separated by a space for sh, and by \001 for rc,
 * which splits it back into a list (on 9base, $#X is 2 for X=a b
 * under rc). An empty list is not exported to rc at all: on Plan 9 it
 * is an empty /env file, which rc reads as (), but a Unix rc reads X=
 * as ('') -- one empty word, and ocamlc $SYSLIBS then fails on an
 * empty argument. omk does the same and 9base's mk does not; xix's
 * build needs it.
 *
 * {b The whole recipe goes to one shell}, on its standard input, with
 * -e (unless :E:), so the first failing command stops it and a cd
 * lasts until the end -- unlike make's one shell per line:
 *
 *     install:V:
 *         cd sub
 *         cp prog /bin       mk copies sub/prog; make would copy ./prog
 *
 * {b Printing.} Before it runs, a recipe is printed (unless :Q:, and
 * always under -n) with the variables that mk set expanded -- those of
 * the mkfile, of the command line, and the job's own -- and the rest is
 * left for the shell: $HOME stays $HOME, and so does anything quoted
 * ('$X', "$target", `cmd`). The bugs section of mk(1) says not to trust
 * this printing, but it is what 9base prints, and what the differential
 * tests compare.
 *
 * References: mk(1), "Execution" and "Environment"; principia's run.c,
 * env.c (buildenv), shprint.c and Posix.c (execsh, exportenv); Andrew
 * Hume and Bob Flandrena, "Maintaining Files on Plan 9 with Mk", for
 * the one shell: "Make evaluates recipes one line at a time ... Mk
 * passes the entire recipe to the shell without interpretation". *)

type job = {
  rule : Mkfile.rule;         (* the master rule, whose recipe runs *)
  stems : Pattern.binding;
  targets : string list;      (* $target *)
  alltargets : string list;   (* $alltarget *)
  prereqs : string list;      (* $prereq *)
  newprereqs : string list;   (* $newprereq *)
  nodes : Graph.node list;    (* the nodes made by this job *)
}

(* the environment of [job] run in slot [slot]: the exported variables
 * and the job's own (buildenv). With no job, as for backquotes, the
 * job's own variables are empty. *)
val env : Mkfile.t -> job:job option -> slot:int -> pid:int -> unit -> (string * string list) list

(* the environment as "name=value" strings, with each list joined the
 * way [shell] wants *)
val environment : shell:string list -> (string * string list) list -> string array

(* [shprint mk env recipe] is the recipe as mk prints it (see above) *)
val shprint : Mkfile.t -> (string * string list) list -> quoting:Word.quoting -> string -> string

(* shprint.c's front(): a printed recipe cut down to its first three
 * fields and its last one, for error messages *)
val front : string -> string

(* {2 Processes} *)

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.pipe >

(* [start caps ~shell ~env ~args script] forks the shell with [args]
 * (such as ["-e"]) and [script] on its standard input, and returns its
 * pid. *)
val start : < caps; .. > -> shell:string list -> env:string array -> args:string list -> string -> int

(* how a recipe ended: why it failed, as mk prints it ("exit(1)",
 * "signal 9") *)
(* It is a variant and not a string with "" for success, because a
 * test of why <> "" is easily written backwards, and nothing says ""
 * cannot be a reason. *)
type ended = Succeeded | Exit_status of string

(* [wait caps] returns a child that ended, and how it ended, or None if
 * there is none *)
val wait : < caps; .. > -> (int * ended) option

(* [output caps ~shell ~env ~stdin cmd] runs [cmd] (on the standard
 * input, or with -c), waits for it, and returns what it printed and
 * whether it succeeded. It is used for backquotes, <| and :P:. *)
val output : < caps; .. > -> shell:string list -> env:string array -> stdin:bool -> string -> string * bool
