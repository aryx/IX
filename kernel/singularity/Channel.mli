(* mini-singularity: the channels (decision 4 of
 * plan_system_singularity.md): the only way two processes talk. A
 * channel has two endpoints, the importing and the exporting, each
 * held by one process; what is sent at one is received at the other,
 * in order. A message is a tag, an integer, and maybe a block of the
 * exchange heap or an endpoint of another channel, which goes with it.
 * Sending never waits; receiving is Process's and Abi's to wait for.
 *
 * A channel has a contract (Contract) and a state: a message is sent
 * only if the state allows it from that end, carrying what the
 * contract says, and the state is then the next. *)

type shared = {
  contract : Contract.t;
  mutable state : int;
}

type endpoint = {
  side : Contract.side;
  channel : shared;
  mutable peer : endpoint option;       (* None: closed, here or there *)
  queue : message Queue.t;              (* sent to this end, not received yet *)
  mutable owner : int;                  (* the process that holds it; Exchange.in_message *)
  mutable waiter : int;                 (* the process waiting to receive here, or -1 *)
}

and carried =
  | Nothing
  | Block of Exchange.block
  | Endpoint of endpoint

and message = {
  tag : int;
  value : int;
  carried : carried;
}

(* a waiting process may run again (Process sets it) *)
val wake : (int -> unit) ref

(* [create contract owner]: a channel in its contract's first state:
 * its importing and its exporting endpoint *)
val create : Contract.t -> int -> endpoint * endpoint

type sent =
  | Sent
  | Closed_                             (* nothing was sent, nothing given away *)
  | Refused of string                   (* by the contract: why *)
val send : endpoint -> message -> sent

type received =
  | Message of message
  | Empty
  | Closed                              (* and nothing left to receive *)
val receive : endpoint -> received
(* a receive would not wait *)
val ready : endpoint -> bool

(* this end closed: the other's receives say so once its queue is
 * empty; what was sent here and not received is freed, or closed *)
val close : endpoint -> unit
