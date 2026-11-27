# Build and test ix with OCaml 4.14.2 via opam, and gcc on Ubuntu
#
# dune builds it, then make test-lite runs the short tests (tests/lite.sh: every
# family of programs, ix built by ix and a kernel booted; what the
# image has no reference for is said, "skip"), or, with
# --build-arg TESTS=all, make test-all, the whole suite (tests/all.sh:
# half an hour; for an arm64 machine, since ix's tools make arm64 programs,
# which the tests run).
#
# The references of mini-rc, mini-ed and tiny-editor are 9base's rc, 
# ed and sam; those outside the repository
# (goken, ocaml-light, chidb, principia, xv6) are not in the image and
# their suites are skipped.
#
# See also .github/workflows/docker.yml, and make build-docker.

FROM ubuntu:24.04

# The packages from Azure's copy of Ubuntu's archive, where GitHub's
# runners are: on 2026-11-23 archive.ubuntu.com gave them 70 kB/s, and
# self.yml's mix jobs spent up to 100 minutes of their 3 hours in
# apt-get, the build of ix on the card hardly begun. Any machine can
# read it; --build-arg APT_MIRROR=archive.ubuntu.com for Ubuntu's own.
# (amd64's archive and security only: an arm64 image, as on a Mac,
# reads ports.ubuntu.com, which Azure has no copy of)
ARG APT_MIRROR=azure.archive.ubuntu.com
RUN sed -i -E "s,//(archive|security)\.ubuntu\.com/ubuntu/,//$APT_MIRROR/ubuntu/," /etc/apt/sources.list.d/ubuntu.sources

# Here are the packages installed and why:
# - A C toolchain (for opam's OCaml), 
# - opam
# - 9base for the references,
# - SDL2 and libffi for tsdl (mini-qemu's window), 
# - python3 for the tests written in Python (the fuzzers, the sessions, make
#   test's and test-lite's; the build does without it) and, with curl,
#   version_control/tests/net.sh's http server,
# - GNU's binutils for arm and arm64 for the tiny ARM tests' and the decoders'
#   reference: a plain objdump knows only its host's
# - bc for the tests' seconds
# - qemu-user for the arm programs of the whole suite (qemu-arm)
# - qemu-system-arm for make test's m-ix built in mini-9pi (QEMU's Pi 2:
#   kernels/9pi/tests/smoke.sh; its kernel by ix's tools since 3fc9d624,
#   no ocaml-light), and make self-mix's
# (noninteractive: a package QEMU pulls in, tzdata, asks no question)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git opam 9base libsdl2-dev libffi-dev pkg-config python3 curl binutils-arm-linux-gnueabihf binutils-aarch64-linux-gnu bc qemu-user qemu-system-arm

# OCaml
RUN opam init --disable-sandboxing -y  # (no sandboxing in Docker)
ARG OCAML_VERSION=4.14.2
RUN opam switch create ${OCAML_VERSION} -v

WORKDIR /src

# The dependencies, as dune-project lists them, before the sources, so
# that a change to the code does not rebuild this layer
COPY dune-project ./
# caps by its commit on GitHub, not opam's release: ix takes what
# ocaml-caps has before opam's repository has it (0.1.1: Cap.clock,
# Cap.pipe, CapUnix.getpid; CapSys.set_signal and the files', CapUnix's
# network, mkfifo, setitimer, _exit; Cap.audio). A new ocaml-caps for
# ix is a new hash here (CAPS, for tix's second switch too, below)
ARG CAPS=git+https://github.com/aryx/ocaml-caps.git#56f7748a8f7939bab88eb53ea5b7f78501cd8858
RUN eval $(opam env) && opam pin add -y -n caps ${CAPS}
RUN eval $(opam env) && opam install -y dune caps fpath logs fmt testo alcotest tsdl js_of_ocaml-compiler js_of_ocaml ppx_deriving menhir

# For make self (.github/workflows/self.yml, --build-arg SELF=tix or
# mix): mix wants QEMU's Pi 2 (above), gcc for arm, and sfdisk
# (kernels/9pi/tests/self.sh reads the card's partitions). mini-9pi is
# built by ix's own tools, mini-ml and mini-cc (kernels/9pi/Makefile's
# COMPILER=ix, the Pi 2's default): ix built by ix needs no ocaml-light.
# (old: ocaml-light cloned here and built for arm by
# kernels/ocaml-light.sh before make self-mix, for the kernel it built
# until 2026-11-19)
ARG SELF=
# (apt-get update again: the first layer's lists may be an old cache's)
RUN if [ "$SELF" = mix ]; then apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc-arm-linux-gnueabihf fdisk; fi
# tix's make self runs tiny-kernel on four cores, each on an OCaml 5
# domain (tiny/TinyKernel/Makefile's OCAML5, plan_tiny_self_speed.md's
# step 7): a second switch, for tiny-machine alone, with the same
# packages (--no-switch: ix itself is built by the first). Without it,
# make self runs on one core, twice as long
RUN if [ "$SELF" = tix ]; then \
  opam switch create 5.5.1 --no-switch -v && \
  opam pin add -y -n --switch=5.5.1 caps ${CAPS} && \
  opam install -y --switch=5.5.1 dune caps fpath logs fmt testo alcotest tsdl js_of_ocaml-compiler js_of_ocaml ppx_deriving menhir; fi

# Build
COPY . .
RUN eval $(opam env) && make

# Test: lite (make test-lite, the default) or all (make test-all); or
# make self-tix, self-mix. make self's whole output goes to /src/self.out
# and only its last lines to the log: BuildKit keeps 2 MB of a step's
# log, which mix's kernel and card builds fill in its first minutes, so
# GitHub's log of the nightly job stopped there, 85 minutes before the
# result (self.sh's ok and FAIL lines, a failed directory's errors).
# Each of those last lines cut to 300 characters, and self.sh's own
# lines first: one of the last 80 was the card's image's command, its
# thousands of files on one line, past the 2 MB, and the log of the
# runs of 2026-11-23 stopped before it, without the self: lines (the
# card's time, the kernel's lock) that self.yml puts on the run's page.
# old: tail -80 /src/self.out
ARG TESTS=lite
RUN eval $(opam env) && \
  if [ -n "$SELF" ]; then \
    make self-$SELF > /src/self.out 2>&1; s=$?; \
    grep -a '^self: \|^ok \|^FAIL' /src/self.out | cut -c1-300; \
    tail -80 /src/self.out | cut -c1-300; exit $s; \
  else make test-${TESTS}; fi
