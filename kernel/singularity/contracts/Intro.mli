(* mini-singularity: the Intro contract, written by hand as Pong: a
 * process is told where a service is by being sent an endpoint of it,
 * which is then its own (a capability: Singularity's way).
 *
 *   contract Intro {
 *     in message Meet(Pong.Imp);
 *     state Start: Meet? -> Done;
 *     state Done: ;
 *   }
 *)

val contract : Contract.t

type imp
type exp

val channel : unit -> imp * exp

module Imp : sig
  val endpoint : imp -> Sip.endpoint
  (* the Pong's importing end goes with the message: no longer the sender's *)
  val meet : imp -> Pong.imp -> unit
end

module Exp : sig
  val of_endpoint : Sip.endpoint -> exp
  val endpoint : exp -> Sip.endpoint
  (* the one message: the Pong's importing end it carries *)
  val receive : exp -> Pong.imp
end
