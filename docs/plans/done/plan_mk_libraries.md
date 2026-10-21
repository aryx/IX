# Plan: libraries in the mkfiles, as xix's

**Status**: done (steps 1 and 2 2026-10-20, step 3 2026-10-21): 21
libraries (lib_crypto,
lib_compression, lib_networking and its netcode, lib_graphics,
lib_playground and its apis, platforms and three platforms,
lib_physics, lib_juice, lib_gui, lib_audio; browsers/html, css,
javascript, engine, webapi); networking's programs, mini-lynx,
mini-netscape, mini-node, mini-troff, mini-man, mini-git and its two,
tiny-build, tiny-vcs, lib_crypto's and the engine's tests and every
program of games/mkgames's link them. Left: mini-man still takes
mini-troff's own units (troff's could be a library too); programs whose
units come from another program's directory (WITH in mkgames: scheme,
formula, office...) are not libraries.

The author, 2026-10-20, reading netscape's mkfile: "this long list of
modules ... why not use libraries? that collect together a set of
modules like we do in xix".

## What it was

A program's mkfile named every unit it stands on, its own and its
libraries', in their order, and compiled them all into its own
directory. lib_crypto's 13 units were listed in four mkfiles
(networking, lynx, netscape, lib_crypto/tests), lib_networking's 18 in
three, each compiling its own copy. Only lib_core was a library
(`lib_core.a`, by mini-ar).

## The design

As xix: a library's directory has a mkfile that lists its units in
order and includes `mkfiles/mklib`; a program names its libraries.

- **One library per `lib_xxx/`**, its subdirectories included, as
  lib_core is (xix has one per subdirectory: lib_graphics/draw/lib.cma).
  A library of many units costs a program nothing: it links only the
  units it uses (`Link.weak`), where it linked every unit it listed.
- **The archive carries its order.** `mini-ar t` lists a library's
  units in the order they were given, which is the order they start in;
  `mkfiles/units.sh` makes those names, which a program's start gives
  `mini-ml -start` (ocamlc reads a .cma's order the same way). Nothing
  changed in the tools.
- **A program asks its libraries' mkfiles** at each build
  (`mkfiles/mklibs`: the archive's rule out of date always, `:Pfalse:`,
  make -C's way). Each library's mini-mk says whether its archive is
  older than its files. A program built alone never links a library
  older than its sources, and is linked again only when an archive
  changed. The top mkfile makes the libraries first: the programs
  side by side would otherwise make one archive twice at once.
- **A library names the libraries it needs** (`NEEDS`), for their
  interfaces: each library's mkfile says its directories (mklib's
  `dirs`, a system's and a platform's among them, and those of the
  libraries it needs, since an interface names their types); a program's
  `LIBI` is the same question asked of its libraries.
- **A library is a directory with a mkfile**, a subdirectory too, when
  the start's order asks it: lib_playground's apis/ (Multiplayer) are
  over lib_networking/netcode, which is over lib_playground's Lehmer,
  so apis/ is a library of its own, after; each platform
  (platforms/ppm...) is one, a program naming the one it wants.
- **A unit nobody names** (browsers/javascript's Js_quicken and
  Js_compile, which tell Js_eval of themselves when the program starts:
  dune's -linkall) would be left in its archive: a program that links
  the library gives their objects on its link line (WHOLE), and
  mini-ld takes an object given always, a member only when named.
- **A library's mkfile may make a program too** (javascript's
  mini-node): mklibs asks a library for `lib`, mklib's target for the
  archive alone, and `all` is the library's and its program's.
- **A system's own file** (Plan 9's Tcp and Udp, `tcp/plan9/`) is the
  library's choice, by OS, as lib_core's Unix is: a program does not
  know it is there.

A library's mkfile (lib_networking's):

    TOP=..
    <$TOP/mkfiles/mkconfig
    LIB=lib_networking
    OSDIR=`{case $OS in plan9) echo tcp/plan9;; esac}
    DIRS=tcp tls http $OSDIR
    NEEDS=lib_crypto lib_compression
    UNITS=Udp Dns Tcp Base64 ... Keep_alive Http_client
    <$TOP/mkfiles/mklib

A program's (networking's):

    LIBDIRS=lib_crypto lib_compression lib_networking
    <$TOP/mkfiles/mklibs
    INCLUDES=-I . $LIBI $STDI
    $D/mini-curl: $D/Curl.$O $LIBA ...
    	$ML -start $STD $COMMONS `$TOP/mkfiles/units.sh $LIBA` Curl Std_exit -o ...
    	$LD $LDH -nofollow -o $target ... $STDOBJS $LIBA $D/Curl.$O $STDEND

## Steps

1. **lib_crypto, lib_compression, lib_networking** (tcp, tls, http).
   Done 2026-10-20. Their users: networking (mini-curl, mini-timesync,
   mini-httpd), mini-lynx, mini-netscape, lib_crypto's tests. Measured:
   the programs smaller, the units they do not use left out:
   mini-timesync 1.21 MB to 0.60, mini-httpd 1.24 to 0.73, mini-curl
   1.23 to 1.19. netcode/ (it names the playground's Lehmer) and 9p/
   (OCaml's only) are not in lib_networking.
   Checked: mini-curl and mini-lynx on https://example.com, netscape's
   frames 31 of 31 on mini-ml's build, the crypto vectors the same,
   the Plan 9 builds (networking, lynx, netscape; Tcp is
   `tcp/plan9/Tcp.ml` in Plan 9's archive), a library's file touched:
   its archive made again and the programs linked again, and nothing
   when nothing changed.
2. **lib_graphics and lib_playground**, and the libraries under the
   playground's APIs. Done 2026-10-20. lib_graphics: its folders and
   the draw device's client (48 units); lib_playground (core, random,
   layers); lib_playground/apis (with ways/), lib_playground/platforms
   (the renderers, the sessions, Plan9_loop), platforms/ppm, draw and
   software; lib_physics, lib_juice, lib_gui, lib_audio (not the MPEG
   decoders, OCaml's only), lib_networking/netcode. games/mkgames 258
   lines to 114: every library named, WITH now only for other
   programs' units (scheme, formula, office, sheet, undo, gui4, shmup,
   rebirth; physics, gui, audio, juice, multiplayer, ways, pdf and
   studio need nothing now). netscape's list of 150 units to 110, its
   own. Checked: the frames on mini-ml's build, games 37, examples 33,
   drscheme 8, office 26, netscape 31; mini-page and mini-rebirth built;
   the card (`make ix-usb card`: every Plan 9 program, the games with
   the software platform too), mini-9pi's check-quick (its five
   sessions' screens the same: wolf and drscheme among them). Found: mk makes `${DIRS:%=-I %}`
   `-Icore` (goken's mk too): mklib says `-I ./%`.
3. **mkprog's programs, troff and man, the browsers.** Done
   2026-10-21. mkprog includes mklibs: a program
   that sets LIBDIRS links them (its own LIBI kept as PROGI; mklibs's
   LIBA by a loop, which of no library is nothing, where
   `${LIBDIRS:%=...}` gave the name). mini-troff and mini-man link
   lib_compression and lib_graphics, where troff compiled their 14
   units (Affine, Zlib, Pdf_write, the pictures' readers); man still
   takes troff's own units. The browsers' five directories, libraries
   as dune's: html, css (html), javascript (lib_playground: Lehmer),
   engine (css, the network, the playground), webapi (engine,
   javascript; Script_types in its root). mini-netscape's list 110
   units to 7, its own; mini-lynx's 8 to none; the engine's Boxes 23
   to none; mini-node's 23 to 2 (CLI, Main), Lehmer from
   lib_playground's archive. Sizes about the same (troff 2.45 MB,
   netscape 5.66 MB: they used nearly all they compiled; lynx 1.44 to
   1.42, boxes 1.42 to 1.38). Checked: typesetting's sample.sh,
   netscape's frames 31 of 31 on mini-ml's build, boxes.sh, mini-node's
   scripts.sh (its map has Js_quicken's and Js_compile's), mini-lynx
   on a page and on https://example.com, every mkprog program built
   again and then up to date, the Plan 9 builds of troff, man, lynx,
   node, netscape and boxes.
   version_control the same day (the author chose to change
   tiny/mkfile with it): mini-git, mini-diff and mini-merge3 link
   lib_crypto and lib_compression, where they compiled Sha1 and Zlib;
   tiny-build and tiny-vcs link lib_crypto's archive, where they took
   version_control's Sha1 object. Checked: TinyBuildSystem_test.sh (21
   ok) and TinyVCS_test.sh (0 failures) on mini-mk's builds, mini-git's
   log of repo.sh's repository, its repack accepted by git fsck
   --strict and verify-pack, the same objects. (version_control is not
   built for Plan 9: Proto's Unix.socketpair.) The top mkfile: tiny
   no longer after version_control (that line made version_control a
   second time beside the loop's). The whole top mini-mk: 1 min 22 s,
   then nothing made in a second one, which still took 33 s: each
   program asks each of its libraries' mkfiles, and each library its
   NEEDS' dirs (to look at, if it matters: a library's dirs asked once
   a build).

## Next (the author, 2026-10-21: "let's put those next steps in their appropriate plan document")

1. **A build where nothing changed** — done 2026-10-21 (the author:
   "we can do like in xix and principia, just build the libraries in
   a certain order, so you can then assume than in another dir the
   library has already been built"; a stale library is then built
   again from the top, which the author accepted). Measured first:
   mini-9pi's programs (kernels/9pi's `card ix-usb`, what
   `./mini-pi -g mini-9pi` builds) took 3 min 21 s when nothing
   changed, 8.5 s on 2026-10-18; games/ alone 23 s. Now the top
   mkfile's `libs` makes the libraries one after the other, in their
   order (OS=plan9: the draw and software platforms, else ppm), and
   its `all`, tests/lite.sh and kernels/9pi's `ix` run it first; a
   library writes its `-I`s beside its archive (`$B/lib_xxx/dirs`,
   mklib), which mklib's NEEDI and mklibs's LIBI read; mklibs's rule
   for an archive says to build the libraries when one is missing,
   and asks no library's mkfile. mini-9pi's programs: 8.6 s, games/
   0.6 s; make test-lite 132 s (181 s before), 0 failures; the whole
   top mini-mk when nothing changed 2.0 s (33 s before; measured
   after bf2e9796, a first run making what had changed in 40 s, the
   second nothing). Given up:
   a program built alone no longer builds a library older than its
   sources.
2. **troff's units as a library** (`typesetting/troff`, its units
   but Main and CLI), so mini-man names it in LIBDIRS and stops
   listing troff's 26 units and its directories; the archive in
   troff's `lib` target, mini-troff made by `all` beside it, as
   browsers/javascript's mini-node. Small, mostly tidying.
   Done 2026-10-21 (the author: "let's do 2"): its 26 units, CLI
   among them (mini-man's `CLI.typeset`), Main alone outside; the
   library built by the top mkfile's `libs`, after lib_graphics, and
   mini-man in the loop with the others (no longer after troff), as
   in tests/lite.sh and kernels/9pi's IXDIRS. mklib takes a unit made
   in `$D` (pic's grammar, mini-yacc's): looked for there last, `-I
   $D`, and `$D` in the library's dirs. mini-man's old `-I
   $TOP/_mk/$O/...` was not `$B`'s (tests/lite.sh's `_mk/lite`, OS=plan9's
   `_mk/5-plan9`). Checked: sample.sh and latex.sh (21 books, 0
   failures) on mini-mk's mini-troff and mini-man, make test-lite (69
   jobs, 0 failures), O=5 OS=plan9's libs and mini-man, the top
   mini-mk when nothing changed 2.1 s.

