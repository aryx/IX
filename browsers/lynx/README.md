# browsers/lynx: mini-lynx

The web in a terminal: a page as lines of text, its links numbered, a
number typed to follow one
([`plan_browser.md`](../../docs/plans/plan_browser.md), stage 4). One
file, `Lynx.ml`, written for ix after the author's mini-chrome's
`tools/lynx`, over `browsers/html` (`Line_mode`) and `lib_networking`.

    mini-lynx [-dump] [-w width] address

An address is a file when there is one of that name, else a host;
https:// by ix's own TLS. Not mini-chrome's: nothing. Changed: a
relative file's links are resolved against its whole path (they were
against `file://name`).

Built by dune (`bin/mini-lynx`) and by mini-mk
(`_mk/7/browsers/lynx/`).

Tests: `tests/session.sh` (two pages served by mini-httpd, a link
followed, back, a wrong number, quit; `-dump` of a file; a 404),
against `session.expected`; it takes mini-mk's directory (`_mk/7`),
dune's by default.
