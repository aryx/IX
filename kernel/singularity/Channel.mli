(* mini-singularity: the channels (decision 4 of
 * plan_system_singularity.md): the only way two processes talk. A
 * channel has two endpoints, each held by one process; what is sent at
 * one is received at the other, in order. A message is a tag, an
 * integer, and maybe a block of the exchange heap, which goes with it.
 * Sending never waits; receiving is Process's and Abi's to wait for.
 * (The contract, which says what tags a channel's state allows, is
 * stage 4's.) *)

type message = {
  tag : int;
  value : int;
  block : Exchange.block option;
}

type endpoint = {
  mutable peer : endpoint option;       (* None: closed, here or there *)
  queue : message Queue.t;              (* sent to this end, not received yet *)
  mutable owner : int;                  (* the process that holds it *)
  mutable waiter : int;                 (* the process waiting to receive here, or -1 *)
}

(* a waiting process may run again (Process sets it) *)
val wake : (int -> unit) ref

(* [create owner]: a channel's two endpoints *)
val create : int -> endpoint * endpoint

(* to the other end: false if the channel is closed (the block stays the sender's) *)
val send : endpoint -> message -> bool

type received =
  | Message of message
  | Empty
  | Closed                              (* and nothing left to receive *)
val receive : endpoint -> received
(* a receive would not wait *)
val ready : endpoint -> bool

(* this end closed: the other's receives say so once its queue is
 * empty; what was sent here and not received is freed *)
val close : endpoint -> unit
