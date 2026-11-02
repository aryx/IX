(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fingerprint.mli: the .NET road's, fingerprint.c's, compiled by
 * mini-cc -dotnet into fingerprint.dll beside the program; its class
 * fingerprint's methods called as they are (ilasm's [assembly]Class) *)

external basis : unit -> Int64.t =
  "dotnet:static [fingerprint]fingerprint::fp_basis() -> uint64"
external mix : Int64.t -> int -> Int64.t =
  "dotnet:static [fingerprint]fingerprint::fp_mix(uint64, int32) -> uint64"
external add : Int64.t -> Int64.t -> Int64.t =
  "dotnet:static [fingerprint]fingerprint::fp_add(uint64, uint64) -> uint64"
