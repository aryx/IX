(* mini-singml: a contract's module written, in OCaml, over
 * kernel/singularity's lib/Contract and lib/Sip: what
 * contracts/Pong.ml and Pong.mli there are by hand. The contract's
 * value for the kernel; the two ends' types, abstract; the types
 * declared, as they are; and for each end a module with an operation a
 * message it sends, receive for those it is sent, of_endpoint (which
 * asks the kernel), endpoint and close. *)

(* [ml source c], [mli source c]: the module's two files' text; source
 * is the declaration's file, named in their first line *)
val ml : string -> Description.t -> string
val mli : string -> Description.t -> string
