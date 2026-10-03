# Build and test ix with OCaml 4.14.2 via opam on Ubuntu: dune builds
# it, then make test-lite runs the short tests (tests/lite.sh: every
# family of programs, ix built by ix and a kernel booted; what the
# image has no reference for is said, "skip"), or, with
# --build-arg TESTS=all, make test-all, the whole suite (tests/all.sh:
# hours; for an arm64 machine, since ix's tools make arm64 programs,
# which the tests run). The references of mini-rc, mini-ed and
# tiny-editor are 9base's rc, ed and sam; those outside the repository
# (goken, ocaml-light, chidb, principia, xv6) are not in the image and
# their suites are skipped.
# See also .github/workflows/docker.yml, and make build-docker.

FROM ubuntu:24.04

# A C toolchain (for opam's OCaml), opam, 9base for the references,
# SDL2 and libffi for tsdl (mini-qemu's window), python3 and curl for
# version_control/tests/net.sh's http server, and GNU's binutils for
# arm and arm64 (the tiny ARM tests' and the decoders' reference: a plain
# objdump knows only its host's), bc for the tests' seconds, and
# qemu-user for the arm programs of the whole suite (qemu-arm)
RUN apt-get update && apt-get install -y build-essential git opam 9base libsdl2-dev libffi-dev pkg-config python3 curl binutils-arm-linux-gnueabihf binutils-aarch64-linux-gnu bc qemu-user

# OCaml
RUN opam init --disable-sandboxing -y  # (no sandboxing in Docker)
ARG OCAML_VERSION=4.14.2
RUN opam switch create ${OCAML_VERSION} -v

WORKDIR /src

# The dependencies, as dune-project lists them, before the sources, so
# that a change to the code does not rebuild this layer
COPY dune-project ./
RUN eval $(opam env) && opam install -y dune caps fpath logs fmt testo alcotest tsdl js_of_ocaml-compiler

# Build. The sources are made a git repository again (.git is not
# copied): the tests over "every file of ix" list them with git ls-files
COPY . .
RUN git init -q && git add -A
RUN eval $(opam env) && make

# Test: lite (make test-lite, the default) or all (make test-all)
ARG TESTS=lite
RUN eval $(opam env) && make test-${TESTS}
