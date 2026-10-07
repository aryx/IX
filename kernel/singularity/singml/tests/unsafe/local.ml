(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
module Inner = struct
  external abi : int -> int = "sip_abi"
end
module Sys_ = Unix
let () = print_int (Inner.abi 0)
