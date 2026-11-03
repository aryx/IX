(* mini-analyze -dead: a record of functions, a program's, through a type
 * that is abstract outside its unit (Prog.mli's model): its step is live *)
type 'm app = { start : 'm; step : 'm -> 'm }
