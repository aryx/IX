(* An analysis's answers, every tuple of every relation a rule makes,
 * made one number (Fingerprint's): mini-analyze -fingerprint, the same
 * by both roads when they agree *)
val fingerprint : Datalog.t -> Int64.t

(* as 16 hexadecimal digits *)
val hex : Int64.t -> string
