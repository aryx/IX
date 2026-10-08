(* mini-singularity: the Pong contract, written by hand, and kept so:
 * what mini-singml makes of a contract's declaration (singml/; Intro
 * here is made by it), to be read (plan_system_singularity.md, stage
 * 4). Singularity's smallest (PongContract: Ready, then Ping
 * there and Pong back), with a block lent and returned, and a text
 * handed over. In Sing#'s way of writing it:
 *
 *   contract Pong {
 *     in  message Ping(int);          out message Ready();
 *     in  message Text(block, int);   out message Pong(int);
 *     in  message Lend(block);        out message Thanks();
 *                                     out message Return(block);
 *     state Start:  Ready! -> Serve;
 *     state Serve:  Ping? -> Pong!   -> Serve
 *                 | Text? -> Thanks! -> Serve
 *                 | Lend? -> Return! -> Serve;
 *   }
 *
 * An end has its own type, and an operation a message it may send: a
 * message of the other end's, or with the wrong argument, does not
 * compile. The state is the kernel's to check: Imp.ping twice in a
 * row compiles, and ends the program that does it. *)

val contract : Contract.t

(* the importing end (the client's) and the exporting (the server's) *)
type imp
type exp

(* what the exporting end receives, and the importing *)
type request =
  | Ping of int
  | Text of Sip.block * int             (* a block now the receiver's; its text's bytes *)
  | Lend of Sip.block
type reply =
  | Ready
  | Pong of int
  | Thanks
  | Return of Sip.block

val channel : unit -> imp * exp

module Imp : sig
  (* an endpoint as this contract's importing end: Failure if it is not *)
  val of_endpoint : Sip.endpoint -> imp
  val endpoint : imp -> Sip.endpoint
  val ping : imp -> int -> unit
  val text : imp -> Sip.block -> int -> unit
  val lend : imp -> Sip.block -> unit
  val receive : imp -> reply
  val close : imp -> unit
end

module Exp : sig
  val of_endpoint : Sip.endpoint -> exp
  val endpoint : exp -> Sip.endpoint
  val ready : exp -> unit
  val pong : exp -> int -> unit
  val thanks : exp -> unit
  val return : exp -> Sip.block -> unit
  val receive : exp -> request
  val close : exp -> unit
end
