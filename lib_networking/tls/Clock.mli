(* Clock: the time you read on a wall.

   An animation counts seconds from wherever it likes, but a clock must
   count them from the Unix epoch, 1970-01-01 at 00:00 in Greenwich
   (UTC), and then say what they are *here*. A day is 86400 of them
   (Unix time does not count leap seconds, so every day is), and "here"
   is an offset: the minutes by which the local clocks are ahead of
   UTC.

        seconds since the epoch           1790253735.
      + offset * 60                        + 120 * 60     (Paris, summer)
      = local seconds                     1790260935.
        / 86400 -> day 20720 (Civil: 2026-09-24, a Thursday)
        mod 86400 -> 52935 s = 14:42:15

   The offset is not the zone. Paris is +60 in winter and +120 in
   summer, and which one applies at an instant is for the platform to
   say (the tz database is out of scope, plan_pim.md). Some offsets are
   not whole hours: India is +330, and Nepal +345.

   No clock is read in here (the README's principle 5): the seconds and
   the offset are arguments, and only an app, given its [computer], has
   the time.

   (ix: the README and the apps are the playground's. Here the one
   caller is Asn1.time, with an offset of 0. A certificate's notBefore
   and notAfter are written in UTC, and [of_local] turns them into the
   seconds that X509.verify compares with the time that Tls_client
   read.)

   terminology:
   UTC, GMT, Unix time. GMT was the sun's time at Greenwich. UTC (1972)
   is the time of atomic clocks, kept within a second of the sun's by a
   leap second added now and then. Unix time is neither quite. It
   counts 86400 seconds in every day, so a leap second is a second
   counted twice or smeared over a day, and the number is not the count
   of seconds really elapsed since 1970 (it is 27 fewer by now). That
   is what makes the arithmetic above a division. *)

type time_of_day = { hour : int (* 0-23 *); minute : int (* 0-59 *); second : float (* [0, 60) *) }

val seconds_per_day : int

(* [split ~offset t] is the local day number (Civil's) and the time of
 * day of [t], in seconds since the epoch, at [offset] minutes east of
 * UTC. It works before the epoch too: -1. is day -1 (1969-12-31) at
 * 23:59:59. *)
val split : offset:int -> float -> int * time_of_day

(* the same, with the day as a date *)
val local : offset:int -> float -> Civil.date * time_of_day

(* [of_local ~offset date tod] is the inverse, back to seconds since
 * the epoch *)
val of_local : offset:int -> Civil.date -> time_of_day -> float

(* "14:42:15", with the seconds truncated; [~seconds:false] gives
 * "14:42" *)
val to_string : seconds:bool -> time_of_day -> string

(* "+02:00", "-04:00", "+05:30": the offset as ISO 8601 writes it *)
val offset_to_string : int -> string
