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
 * contract says, and the state is then the next.
 *
 * The Pong contract's channel (Pong.mli has the contract), between
 * ping, at the importing end, and pong, at the exporting one:
 *
 *     the state   ping (Imp)          pong (Exp)
 *     Start                      <--  Ready
 *     Serve       Ping 1  -->
 *     (a state                   <--  Pong 2
 *      with no    Lend b  -->         b is pong's now
 *      name)                     <--  Return b
 *     Serve       close               receive: Closed
 *
 *     a rogue:    Ping 1  -->
 *                 Ping 2  -->         Refused: the state after Ping
 *                                     allows only Pong, from Exp;
 *                                     Abi ends the sender
 *
 * A contract is a small automaton, shared by the two ends (the
 * record [shared]), and a send is one step of it. Each end has its
 * own queue of what was sent to it, so a send never waits; where
 * the automaton makes the two ends take turns, as Pong's does, a
 * queue never holds more than one message (Singularity computes
 * that bound from the contract and reserves the room; here a queue
 * is OCaml's Queue, with no limit).
 *
 * An endpoint is itself something a message may carry: ping is not
 * given pong's channel but is sent its end, on another channel
 * (the Intro contract). That is how a service is found and handed
 * on with no names: who holds an end may talk, and nobody else can.
 *
 * design:
 * Processes that share no memory can still pass a megabyte for the
 * price of a pointer, if the pointer's owner changes with the
 * message (Exchange): the copy that message passing costs in a
 * microkernel, and the lock that shared memory costs, are both
 * gone. The price is a discipline, exactly one owner at each
 * moment, that a compiler can check (Sing#'s, and Rust's since) and
 * that here is checked at each use.
 *
 * cs-history:
 * Processes that only exchange messages are Hoare's communicating
 * sequential processes (1978); Plan 9's and Go's channels, and
 * Limbo's, come from there through Rob Pike's languages. A contract
 * is what was added: the protocol of a channel as a type, known
 * in theory as session types (Kohei Honda, 1993). Singularity built
 * an operating system on them.
 *
 * others:
 * A Unix pipe carries bytes with no shape, one way, and copies
 * them twice (mini-xv6's File). Mach's ports and L4's IPC carry
 * typed messages between address spaces; L4 made the crossing fast,
 * the copy remains. Plan 9's 9P is one contract for everything, a
 * file's operations, written in a manual and checked by nobody.
 *
 * References: Fahndrich, Aiken, Hawblitzel, Hodson, Hunt, Larus and
 * Levi, "Language Support for Fast and Reliable Message-based
 * Communication in Singularity OS" (EuroSys 2006): channels,
 * contracts, the exchange heap, and how Sing# verifies them. Hunt
 * and Larus (2007), on contract-based channels. C. A. R. Hoare,
 * "Communicating Sequential Processes" (Communications of the ACM,
 * 1978). *)

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
