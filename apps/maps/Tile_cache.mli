(* Tile_cache: the tiles on disk, for as long as the server says.

   A map shows the same streets for years, and OSM's servers are paid for
   by donations: its policy asks a client to keep what it was given, for
   as long as the answer says it stays good, and to ask politely when it
   no longer does. That is HTTP's caching (RFC 9111), which comes down to
   two questions.

   How long is it good? The answer says, and it is a date computed when
   the answer comes:

       Cache-Control: max-age=604800      good for a week from now
       Age: 3600                          of which a proxy used an hour
       Expires: Thu, 05 Nov 2026 ...      the old way (HTTP/1.0), when
                                          there is no max-age
       Cache-Control: no-cache            keep it, but ask before using
       Cache-Control: no-store            do not keep it

   And when it is no longer good? It is often still right, so the client
   asks "has it changed?", saying which version it has:

       GET /4/8/5.png                     HTTP/1.1 200 OK
                                          ETag: "abc"
                                          Cache-Control: max-age=604800
                                          (25 KB)
       ... a week later ...
       GET /4/8/5.png                     HTTP/1.1 304 Not Modified
       If-None-Match: "abc"               Cache-Control: max-age=604800
                                          (nothing)

   A few hundred bytes instead of 25 KB, and a second week. The ETag is
   whatever the server likes, a hash of the file usually; only the server
   ever compares it.

   And when the server does not answer at all, an old tile is shown rather
   than none: a map a week old is still a map.

   Kept within a size: past [limit] bytes the least recently used go, down
   to nine tenths of it, so that the work is not done again at the next
   tile. The cost is one number a tile, kept in the file index and
   written now and then: a crash loses the last few uses, not a tile.

   Only the worker uses it (Map_worker), so no lock.

   cs-history:
   Caches were on the web before there was much of a web: CERN's httpd
   (Ari Luotonen and Kevin Altis, 1994) was a proxy keeping pages, for a
   laboratory's one slow line. HTTP/1.0 had If-Modified-Since, by the
   clock, a second being too coarse and a server's clock not to be
   trusted. HTTP/1.1 (RFC 2068, 1997; Jeffrey Mogul, for a good part) gave
   the ETag and Cache-Control; the rest of the web's speed, CDNs from
   Akamai (1998) on, is built on those few headers.

   Reference: RFC 9111, "HTTP Caching" (Fielding, Nottingham and Reschke,
   2022); OSM's Tile Usage Policy,
   https://operations.osmfoundation.org/policies/tiles/. *)

type t

(* a tile as kept: its file, until when it is good (seconds since 1970), the
 * server's name for this version *)
type entry = { bytes : string; expires : float; etag : string option }

(* [lifetime ~now headers]: until when an answer with these headers stays
 * good (0. when it must be asked again each time: nothing said, no-cache);
 * None when it must not be kept *)
val lifetime : now:float -> Http.header list -> float option

(* [create caps ~dir ~limit]: the cache in [dir], made if it is not there,
 * of at most [limit] bytes; None if it cannot be made *)
val create : < Cap.open_in; Cap.open_out; .. > -> dir:string -> limit:int -> t option

(* the tile of this name ("4/8/5") *)
val find : t -> string -> entry option

(* kept, or kept again, the least recently used going if it is too much *)
val put : t -> string -> entry -> unit

(* how many tiles and bytes are kept (the tests) *)
val size : t -> int * int
