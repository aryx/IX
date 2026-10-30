(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Map_http.mli *)

let user_agent = "mini-maps/0.1 (+https://github.com/aryx/ix)"

let get (caps : < Cap.network; Cap.open_in; .. >) ~(more : Http.header list) (url : string) : (Http.response, string) result =
  let said = ("User-Agent", user_agent) :: more in
  let options = { Http_client.defaults with said; keep = true } in
  Result.map snd (Http_client.fetch_with options caps ~post:None url)
