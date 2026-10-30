# Plan: mini-maps, a map and the weather, fetched from the internet (`apps/maps/`)

The author (2026-10-30), after plan_apps.md: "I would also love to have
a maps and weather program that fetch data from internet."

**Status: stages 1 to 3 built** (see the end). What is below about the services
was tried on 2026-10-30 with ix's own `mini-curl`, a handful of requests.

## What it is for

A map moved and zoomed, a place found, and what the weather is there
and will be. One program, because the two share what matters: *a
place*. Find Tours, see it on the map, press `w`; or click anywhere on
the map and ask the same. On Linux and on mini-9pi from its first
stage, with a `mkfile` and on the card.

    mini-maps                     the window
    mini-maps tours               the window, there
    mini-maps weather tours       the forecast as lines, for a terminal

## What the services are, and what they ask

All answered ix's own TLS and HTTP, with no key:

| What | Service | Answer | Its terms (read 2026-10-30) |
|---|---|---|---|
| the map | `tile.openstreetmap.org/z/x/y.png` | a 256x256 PNG, 25,476 bytes for 4/8/5, a palette (`Png` reads those) | see below |
| a place found | Nominatim, `nominatim.openstreetmap.org/search` | JSON | at most 1 request a second; no autocomplete at all; results cached; our own User-Agent |
| the weather | Open-Meteo, `api.open-meteo.com/v1/forecast` | JSON, current and by day | free for non-commercial use; under 10,000 calls a day; CC-BY 4.0, so credited |
| a route (later) | OSRM's demo server | JSON | not read yet, to read before stage 5 |

OSM's tile policy shapes the design more than anything else:

- **A User-Agent of our own**, naming the program, with a contact. Ix
  says `elm_playground` for everyone today (`Http.get`), and a stock one
  may be blocked, so stage 1 fixes that; `Http.saying` adds a header and
  does not replace one, so it needs a small change.
- **"© OpenStreetMap contributors" on the map**, always visible.
- **A cache that honours the server**: `Cache-Control`, `Expires` and
  `ETag`, an expired tile asked again with `If-None-Match`; never
  `no-cache`. This is a small HTTP lesson of its own.
- **No prefetching and no "save this area"**: only what is in view, with
  a short look-ahead. So no map on the card and no offline mode from
  this server; offline would mean our own extract, as a later plan.
- **The tile address configurable** (`tiles=...`), which they recommend,
  and which is also how the tests run.

## What it brings

- **Mercator** (1569) and the web's version: why the map stops at 85°,
  why Greenland is huge, latitude and longitude to a pixel and back.
- **The tile pyramid** (Google Maps, 2005): zoom z is 2^z x 2^z tiles,
  which tiles a window needs, and zooming between levels by scaling
  what is already there until the sharper one arrives.
- **Waiting without freezing**: `Http_client` blocks, and a map cannot.
  Tiles are fetched by a worker, as mini-netscape's tabs (`Tab_worker`,
  `Worker_spawn`: a thread on mini-9pi), the window drawing what it has.
- **A cache** of files, kept within a size, the least recently used out.
- **JSON from a program's side**: `lib_core`'s `Json` has no float, and
  a forecast and a latitude are nothing but, so it gains one (`Float`),
  which its other users must still build with.
- **The forecast**: the WMO's weather codes as icons, a day's curve of
  temperature; and in the `.mli` the history, from Richardson's forecast
  by hand (1922) to ENIAC's (1950), today's models being what the
  service gives us.
- **Later, a shortest path**: Dijkstra (1959) and A* (1968), which the
  author's measure would prefer computed here, over a small extract,
  than asked of a server.

## Tests

`make test` takes no network and no external server. `mini-httpd` serves
tiles and JSON from a directory. The tiles are drawn by a small script,
each with its z/x/y written on it: the frames are then exact, nothing of
OSM's is copied or prefetched, and a wrong tile shows at once. Whether
the real services still answer is a by-hand check, as Gmail is for
mini-pim.

## Stages

1. **The map**: `Mercator`, `Tiles`, the window moved by dragging and
   zoomed by the wheel and keys; a User-Agent of its own; the worker; the
   credit. On Linux and mini-9pi, on the card, with recorded frames.
2. **The cache**: files on disk, the server's rules, conditional requests.
3. **Finding a place**: `Json`'s float, Nominatim on Enter (no
   autocomplete), a marker, the last places kept.
4. **The weather**: Open-Meteo, a panel for the place, the terminal's
   `weather`, `timezone=auto` so the service gives local days.
5. **A route**: after reading OSRM's terms; own A* only with a data
   source decided.

Estimate: 1,000 to 1,500 lines of `.ml`, an estimate, before routes.

## Open questions

- mini-pim's Home could show today's weather, and its events a place on
  the map. Both are natural once this exists; neither is in this plan.
- A Pi 1 redrawing a moving map of 256x256 tiles: not measured; a first
  check in stage 1, on the Pi 2 first.

## Status

2026-10-30: plan written. Nothing built.

2026-10-30: stage 1 built, `apps/maps/` (its README.md): `Mercator`,
`Tiles`, `Tile_worker`, `Map_window`; dragged, the arrows, the wheel, a
double click, `+` and `-`; a tile not there yet shown from an ancestor,
enlarged; the credit; its own User-Agent (`Http.saying` now replaces
ours). Real tiles of Tours from OSM once, by hand, a screen's worth.
By the tests: its frames by both compilers (`mini-httpd`, tiles of
`Make_tiles`). The Hershey font has no copyright sign, so the credit
reads "(c) OpenStreetMap contributors".
On mini-9pi it is built and on the card, not yet run there: the moving
map on a Pi (the open question below) is still not measured. The draw
platform now keeps as many pictures as 3 million pixels hold, four at
least, for those twenty tiles. Under mini-ml's threads a system call
stops all of them, so the window waits while a tile is fetched, as
mini-netscape's does.

2026-10-30: stage 2 built, `Tile_cache`: a file a tile, with until when it
is good and its ETag; `Cache-Control`, `Age`, `Expires`, `no-store`,
`no-cache`; an old tile asked again with `If-None-Match`, and shown if the
server does not answer; 32 MB, the least recently used going first.
mini-httpd says `ETag` and answers 304 for it, and `-max-age` says
`Cache-Control`, which is how `tests/cache.sh` sees what is asked.

2026-10-30: stage 3 built. `Json` has floats (`Float`, `Json.float`, read
as well from an integer), its other user, `Qmp`, unchanged. `Place`:
Nominatim's answer; `/` or a click opens the Find box, Enter asks, at most
once a second and never as one types; a word on the command line asks the
same; the window goes there, at the zoom the place's box fits (14 at
most), with a marker; the last 20 in the file `places` of the cache's
directory, listed in the box, not asked again. `Tile_worker` is now
`Map_worker`: it runs a job (a place, later a forecast) before more tiles.
One real search by hand. What OSM's tile servers really say, read that
day: `max-age=88280, stale-while-revalidate=604800,
stale-if-error=604800`, `Age: 124344`, so a tile arrives already old, and
each tile costs one `If-None-Match` a session (a 304 when unchanged).
`stale-while-revalidate` would allow showing it first and asking after;
not done, the rule followed being the stricter.
