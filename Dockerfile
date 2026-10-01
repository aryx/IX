# Build and test ix with OCaml 4.14.2 via opam on Ubuntu: dune builds
# it, then make test runs the tests, whose references for TinyShell and
# TinyEditor are 9base's rc and sam (the goken tests, make test-goken,
# need ~/goken and are not run here).
# See also .github/workflows/docker.yml, and make build-docker.

FROM ubuntu:24.04

# A C toolchain (for opam's OCaml), opam, 9base for the references,
# SDL2 and libffi for tsdl (mini-qemu's window), python3 and curl for
# version_control/tests/net.sh's http server, and GNU's binutils for
# arm and arm64 (the tiny ARM tests' and the decoders' reference: a plain
# objdump knows only its host's)
RUN apt-get update && apt-get install -y build-essential opam 9base libsdl2-dev libffi-dev pkg-config python3 curl binutils-arm-linux-gnueabihf binutils-aarch64-linux-gnu

# OCaml
RUN opam init --disable-sandboxing -y  # (no sandboxing in Docker)
ARG OCAML_VERSION=4.14.2
RUN opam switch create ${OCAML_VERSION} -v

WORKDIR /src

# The dependencies, as dune-project lists them, before the sources, so
# that a change to the code does not rebuild this layer
COPY dune-project ./
RUN eval $(opam env) && opam install -y dune caps fpath logs fmt testo alcotest tsdl js_of_ocaml-compiler

# Build
COPY . .
RUN eval $(opam env) && make

# Test
RUN eval $(opam env) && make test
