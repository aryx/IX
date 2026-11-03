(* mini-analyze -bugs' report for an ML program: each analysis of
 * docs/plans/plan_bug_analyses.md written so far, over its rules'
 * answers, a line a bug that may be, named by its analysis:
 *
 *   bug? Before.ml:6: physeq: in Before.loop, != of a Some made there: always true
 *
 * physeq (lib_code/datalog/physeq.dl): == or != with a side made in
 * the comparison itself. *)

(* the report, on the facts and the rules' answers *)
val bugs_report : < Cap.stdout; .. > -> Datalog.t -> unit
