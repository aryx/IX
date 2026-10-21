# Plan: libraries in the mkfiles, as xix's

**Status**: steps 1 and 2 done (2026-10-20): 16 libraries (lib_crypto,
lib_compression, lib_networking and its netcode, lib_graphics,
lib_playground and its apis, platforms and three platforms,
lib_physics, lib_juice, lib_gui, lib_audio); networking's programs,
mini-lynx, mini-netscape, lib_crypto's tests and every program of
games/mkgames's link them. Step 3 to do.

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
   Not changed: troff's and man's (their own copies of Affine, Zlib,
   the pictures' readers: step 3).
3. **mkprog's programs**: `$LIBA` in its start and link, for a
   program that sets LIBDIRS. version_control (Sha1, Zlib) then, with
   tiny/mkfile, which links version_control's Sha1 object: changed
   with its session. typesetting/troff and man, with lib_graphics and
   lib_compression (man takes troff's units).
   browsers/html, css and javascript as libraries of the browsers.
