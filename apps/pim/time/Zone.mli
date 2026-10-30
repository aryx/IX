(* Zone: the local time, a zone's offsets from UTC through the year
   (plan_pim.md, stage 3: "the zone's rules from the system's zoneinfo
   on Linux, /env/timezone on mini-9pi"). ix's own: mini-ml's Unix has
   gmtime and no localtime, and the C library's zone is not ix's.

       /etc/localtime (TZif, RFC 8536)       the zone's history: from
       +--------+---------------+--------+   each UTC second on, an
       | header | transitions   | footer |   offset; the footer
       | TZif2  | 1980... 2037  | CET-1CEST,M3.5.0,M10.5.0/3
       +--------+---------------+--------+   POSIX's rule, the years
                                             after the last transition

   M3.5.0 is March's last Sunday (the month, the 5th week, Sunday),
   at 2:00 local unless /time says. A "slim" file has few transitions,
   its rule all the rest; this reads both. Plan 9's file is a line
   "CET 3600 CEST 7200" and the UTC seconds where it changes, summer's
   first. TZ= is looked at first (UTC, a zone's name, a POSIX rule),
   then /etc/localtime, then /env/timezone, else UTC.

   Not here: leap seconds (UTC's seconds count none), the zone's name
   (CET, CEST), the rules Jn and n of POSIX (a day of the year), which
   no zone of the tz database writes. *)

type t

val utc : t

(* a file's text, TZif's or Plan 9's *)
val of_tzif : string -> t option
val of_plan9 : string -> t option

(* the zone TZ, /etc/localtime or /env/timezone say *)
val local : < Cap.open_in ; Cap.env ; .. > -> t

(* [offset z t]: seconds east of UTC at the UTC time [t] *)
val offset : t -> float -> int

(* [clock z t]: the local day and minute of the day at [t] *)
val clock : t -> float -> Civil.date * int
