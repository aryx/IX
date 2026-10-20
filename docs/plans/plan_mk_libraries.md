# Plan: libraries in the mkfiles, as xix's

**Status**: step 1 done (2026-10-20): lib_crypto, lib_compression and
lib_networking are libraries; networking's programs, mini-lynx,
mini-netscape and lib_crypto's tests link them. Steps 2 and 3 to do.

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
- **A system's own file** (Plan 9's Tcp and Udp, `tcp/plan9/`) is the
  library's choice, by OS, as lib_core's Unix is: a program does not
  know it is there.

A library's mkfile (lib_networking's):

    TOP=..
    <$TOP/mkfiles/mkconfig
    LIB=lib_networking
    OSDIR=`{case $OS in plan9) echo tcp/plan9;; esac}
    DIRS=tcp tls http $OSDIR
    INCLUDES=-I tcp -I tls -I http -I ../lib_crypto -I ../lib_compression $STDI
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
2. **lib_graphics and lib_playground**: games/mkgames (258 lines, its
   lists by WITH), netscape's, the office's, troff's. The platform
   (ppm, draw, SDL) stays a program's choice: a library of its own per
   platform, or the platform's units in the program.
3. **mkprog's programs**: `$LIBA` in its start and link, for a
   program that sets LIBDIRS. version_control (Sha1, Zlib) then, with
   tiny/mkfile, which links version_control's Sha1 object: changed
   with its session. typesetting/man, which takes troff's units.
   browsers/html, css and javascript as libraries of the browsers.
