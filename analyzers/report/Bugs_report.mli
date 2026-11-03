(* mini-analyze -bugs' report for an ML program: each analysis of
 * docs/plans/plan_bug_analyses.md written so far, over its rules'
 * answers, a line a bug that may be, named by its analysis, the file as
 * mini-analyze was given it:
 *
 *   bug? Before.ml:6: physeq: in Before.loop, != of a Some made there: always true
 *   bug? Devmnt.ml:85: stack: wait calls itself in a try's handler: no tail call by mini-ml
 *
 * physeq (lib_code/datalog/bugs/physeq.dl): == or != with a side made in
 * the comparison itself. stack (bugs/stack.dl): a recursion the stack may
 * not hold, a loop through a try, or a frame for each element of a
 * list. Only the program's own units, and code that is reached. *)

(* the report, on the facts and the rules' answers *)
val bugs_report : < Cap.stdout; .. > -> Datalog.t -> unit
