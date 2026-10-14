(* The kernel's Machine (kernels/lib_machine) as Memimage asks it, for
 * the host: Memimage's file is the kernel's, compiled here too
 * (Hostdraw). The kernel keeps a program's images in a memory of their
 * own (Imag: principia's imagmem); the host draws on the guest's
 * images, which it neither makes nor frees, so what it makes is in
 * OCaml's heap and never given back. *)

module Imag : sig
  val alloc : int -> Bytes.t
  val free : Bytes.t -> unit
  val quiet : unit -> unit
  (* never asked: the host draws on no screen *)
  val flush : Bytes.t -> int array -> unit
end
