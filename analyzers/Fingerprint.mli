(* A fingerprint of an analysis's answers (mini-analyze -fingerprint):
 * FNV-1a over 64 bits of each tuple's text, their sum, so that two runs
 * are told apart or alike by one number. Two implementations of this
 * interface, one a road: natively ML (Fingerprint.ml, Int64's
 * arithmetic), on .NET a C module (dotnet/fingerprint.c, compiled by
 * mini-cc -dotnet, called through dotnet/Fingerprint.ml's externals:
 * plan_dotnet_languages.md, stage 8's C module), the same numbers. *)

(* FNV's offset basis; a byte mixed in; two fingerprints' sum *)
val basis : unit -> Int64.t
val mix : Int64.t -> int -> Int64.t
val add : Int64.t -> Int64.t -> Int64.t
