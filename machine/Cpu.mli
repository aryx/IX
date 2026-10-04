(* The loop: fetch, decode (once: a direct-mapped cache of decoded
 * instructions by address, plan_arm.md decision 5), execute. *)

type stats = { mutable instructions : int }

(* runs until the program exits (Linux.Exit), with [trace], if some,
 * called before each instruction, and [signal] between two when Linux.signal_waiting
 * is set (it sets st.next when it enters a handler) *)
val run32 :
  trace:(int -> Arm32_isa.t -> unit) option -> Arm32_isa.state -> pc:int -> svc:(Arm32_isa.state -> int -> unit) ->
  signal:(Arm32_isa.state -> int -> unit) -> stats -> unit

(* the same for arm64 *)
val run64 :
  trace:(int -> Arm64_isa.t -> unit) option -> Arm64_isa.state -> pc:int -> svc:(Arm64_isa.state -> int -> unit) ->
  signal:(Arm64_isa.state -> int -> unit) -> stats -> unit
