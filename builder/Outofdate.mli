(* Out of date, or not: the date stamps, and the decision.
 *
 * A target must be remade if it is not newer than one of its
 * prerequisites. The date stamp of a node (mk(1), principia's mk.c
 * update()) is:
 *
 *     a file that exists       its modification time
 *     a file that doesn't      0 before it is made; after its recipe,
 *                                mk stats it again, and if it is still
 *                                missing, its stamp is the newest of
 *                                its prerequisites' stamps
 *     a virtual target (:V:)   0 before; after, the newest of its
 *                                prerequisites' stamps (at least 1)
 *
 * and the test is [target <= prereq]: equal times count as out of date
 * ("It's a race, and the safer option is to do extra building", mk.c).
 * For foo.o: foo.c (checked on 9base's mk and omk, 2026-09-23):
 *
 *     foo.c        foo.o          9base mk     omk          mini-mk
 *     10:00:00     10:00:00       rebuilds     up to date   rebuilds
 *     10:00:00.2   10:00:00.7     rebuilds     up to date   up to date
 *     10:00:00.7   10:00:00.2     rebuilds     rebuilds     rebuilds
 *
 * 9base has whole seconds, so it can't tell the second row from the
 * first; omk has sub-second times but compares with <. mini-mk uses
 * sub-second times and mk's <=.
 *
 * {b Re-stat after the recipe.} A recipe that leaves its target alone
 * (cmp -s new old || mv new old) keeps its old time, so what depends on
 * it is not rebuilt. This is early cutoff, which Bazel and Shake get
 * from content hashes; here it comes from mtimes, because
 * [after_recipe] looks again rather than assuming.
 *
 * {b :P:cmd:} replaces the comparison: "cmd target prereq" is run by
 * the shell, and a non-zero exit status means out of date. Its answer
 * is remembered, and asked again only after the target's recipe.
 *
 * {b -H, content hashes} (this is not in mk; it is the plan's phase
 * 7). A target's {e trace} is a digest of its recipe and of its
 * prerequisites' contents (a virtual or missing prerequisite stands
 * for its own trace). It is recorded in .mkhash when the target is
 * made or found up to date. The target is out of date when it is
 * missing, when it is virtual, or when its trace changed. Times play
 * no part, except for a target with no trace yet, which the times
 * decide. (That rule came from the
 * first measurement: xix's directories each have their own .mkhash,
 * and lib_core/commons, which depends on ../../caps/src/caps/Cap.cmi,
 * had no trace for it and so rebuilt it with its own flags --
 * "Recursive Make Considered Harmful" in miniature. Deciding by times
 * until there is a trace also lets an existing tree switch to -H
 * without a rebuild.)
 *
 *     edit config.in, and config.h is regenerated identically:
 *         mtimes (no cmp -s trick)   rebuild config.h, then foo.o
 *         -H                         rebuilds config.h only: foo.o's
 *                                    trace has the same digest of
 *                                    config.h
 *     git checkout changes every mtime, and no content:
 *         mtimes                     rebuild everything
 *         -H                         rebuilds nothing
 *
 * These are the "verifying traces" of the paper below. They are what
 * Shake and Bazel do, here in about 30 lines, at the price of reading
 * every input.
 *
 * This module is the rebuilder of "Build Systems a la Carte" (Mokhov,
 * Mitchell and Peyton Jones, 2018), a modification-time rebuilder.
 * Graph gives it the dependencies, and Build is the scheduler around
 * it.
 *
 * References: mk(1), "Execution"; principia's mk.c (outofdate, update)
 * and file.c (timeof); Stuart Feldman, "Make -- A Program for
 * Maintaining Computer Programs" (Software: Practice and Experience,
 * 1979), for the rule itself: a target is created "if it has not been
 * modified since its generators were" (mk adds the <= of equal times);
 * Peter Miller, "Recursive Make Considered Harmful" (AUUGN, 1998), on
 * what one make per directory gets wrong; Mokhov, Mitchell and Peyton
 * Jones, "Build Systems a la Carte" (ICFP 2018), for the rebuilders
 * and the traces. *)

type ctx

(* -H, content hashes instead of times. [digest file] is a file's
 * digest (None if it is missing). [traces] holds each target's trace
 * from when it was last made; CLI loads it from .mkhash and saves it
 * there. *)
type hashes = {
  digest : string -> string option;
  traces : (string, string) Hashtbl.t;
}

(* [create ~time ~prog ()]: [time name] is the current date stamp of a
 * node, and [prog cmd target prereq] runs a :P: command and says
 * whether it succeeded. With [hashes], out of date is decided as -H
 * does. *)
val create :
  hashes:hashes option -> time:(string -> float) -> prog:(string -> string -> string -> bool) -> unit -> ctx

(* Is [node] out of date with respect to the prerequisite of [arc]?
 * [~eval:true] asks a :P: command again instead of remembering. *)
val arc : eval:bool -> ctx -> Graph.node -> Graph.arc -> Graph.node -> bool

(* -H: record the trace of a node found up to date *)
val up_to_date : ctx -> Graph.node -> unit

(* [after_recipe ctx ~exists ~stat node] is the node's date stamp once
 * its recipe has run (see the table above) *)
val after_recipe :
  ctx -> exists:(string -> bool) -> stat:(string -> float) -> Graph.node -> float
