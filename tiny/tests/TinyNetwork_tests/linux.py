#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-kernel's network meeting programs that are not ours
# (plan_tiny_network.md, "On Linux"), on this machine alone: no
# Internet, no root. tiny-machine is run on a terminal of its own (a
# pty: with a file as its input it reads it whole first, and a server
# needs its keys while it runs), and:
#
# - out: a web server of Python's on a port of this machine, serving
#   tiny/tests/www; in tiny-kernel, get /hello.txt 127.0.0.1 port, by
#   the address and by the name localhost (tiny-machine -net-out:
#   TinyLibPeer's gateway, tiny-machine-socket's connection); a port
#   nothing listens on, a name nobody has;
# - in: httpd typed in tiny-kernel, tiny-machine -net-forward: this
#   script asks http://127.0.0.1:port/ as a browser would: the page
#   that lists the files, a file written by echo, a program's bytes
#   (cat, 70 KB: many messages), a file that is not there;
# - the capture (-net-pcap), read back: its packets counted.
# usage: linux.py tiny-machine boot.img www
import functools, http.server, os, pty, select, socket, struct, sys, tempfile, threading, time, urllib.error, urllib.request

machine, image, www = sys.argv[1:4]
failures = 0

def check(what, ok, said=""):
    global failures
    print(("ok " if ok else "FAIL ") + what + ("" if ok else ": " + repr(said)))
    failures += not ok

def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=www))
threading.Thread(target=server.serve_forever, daemon=True).start()
out, closed, forward = server.server_address[1], free_port(), free_port()
capture = tempfile.mktemp(suffix=".pcap")

pid, tty = pty.fork()
if pid == 0:
    os.execv(machine, [machine, "-net", www, "-net-out", "-net-forward", f"{forward}:80", "-net-pcap", capture, image])
seen = b""

def wait(what, seconds=60):
    """the terminal's text until it has what, a string"""
    global seen
    end = time.time() + seconds
    while what.encode() not in seen and time.time() < end:
        if select.select([tty], [], [], 0.2)[0]:
            try: seen += os.read(tty, 65536).replace(b"\r", b"")
            except OSError: break
    return what.encode() in seen

def typed(line, what, seconds=60):
    """a line typed; what the terminal says after it, when it has what"""
    global seen
    seen = b""
    os.write(tty, line.encode() + b"\n")
    ok = wait(what, seconds)
    return ok, seen.decode(errors="replace").replace("\r", "")

def page(path):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{forward}{path}", timeout=60) as r: return r.status, r.headers.get("Content-Type"), r.read()
    except urllib.error.HTTPError as e: return e.code, e.headers.get("Content-Type"), e.read()
    except Exception as e: return 0, "", repr(e).encode()

try:
    check("the kernel boots", wait("$ "))
    ok, said = typed(f"get /hello.txt 127.0.0.1 {out}", "from the other end of the wire.\n$ ")
    check("out: a file of a web server's on this machine, by its address", ok and "HTTP/1.0 200 OK" in said, said)
    ok, said = typed(f"get /il.txt localhost {out} | wc", "$ ")
    size = os.path.getsize(os.path.join(www, "il.txt"))
    check("out: by its name, a longer one whole", ok and wait("\n$ ") and any(l.split()[-1:] and l.split()[-1].isdigit() and int(l.split()[-1]) > size for l in seen.decode(errors="replace").splitlines()), seen)
    ok, said = typed(f"get / 127.0.0.1 {closed}", "$ ")
    check("out: a port nothing listens on: the dial fails", "nothing answers at 127.0.0.1" in said, said)
    ok, said = typed("get / no-such-name.invalid 80", "$ ", 30)
    check("out: a name nobody has: said", "nothing answers at no-such-name.invalid" in said, said)
    ok, said = typed("get hello.txt", "$ ")
    check("the wire's own end still answers", "from the other end of the wire." in said, said)
    typed("echo hello from tiny-kernel > hi.txt", "$ ")
    ok, said = typed("httpd", "listening on port 80")
    check("in: httpd listens in tiny-kernel", ok, said)
    status, kind, body = page("/")
    check("in: / is a page that lists the files", status == 200 and kind == "text/html" and b'<a href="/hi.txt">' in body and b'<a href="/tetris">' in body, (status, kind, body[:200]))
    status, kind, body = page("/hi.txt")
    check("in: a file written by echo", status == 200 and kind == "text/plain" and body == b"hello from tiny-kernel\n", (status, kind, body))
    status, kind, body = page("/cat")
    check(f"in: a program's bytes, {len(body)} of them, the image's", status == 200 and len(body) > 60000 and body in open(image, "rb").read(), (status, kind, len(body)))
    status, kind, body = page("/nothing")
    check("in: a file that is not there: 404", status == 404, (status, body))
    check("httpd said each request", wait("httpd: /nothing"), seen)
    os.write(tty, b"\x03")
    ok, said = typed("", "$ ")
    check("^C ends httpd, the shell is back", ok, said)
    os.write(tty, b"\x04")
    for _ in range(100):
        if os.waitpid(pid, os.WNOHANG)[0]: pid = 0; break
        time.sleep(0.1)
    check("the machine halts at the input's end", pid == 0)
    data = open(capture, "rb").read() if os.path.exists(capture) else b""
    n, at = 0, 24
    while at + 16 <= len(data):
        n += 1; at += 16 + struct.unpack("<I", data[at + 8:at + 12])[0]
    check(f"the capture: {n} packets, read to its end", data[:4] == b"\xd4\xc3\xb2\xa1" and n > 100 and at == len(data), (len(data), n, at))
finally:
    if pid:
        try: os.kill(pid, 9)
        except OSError: pass
    if os.path.exists(capture): os.remove(capture)
print(f"TinyNetwork linux: {failures} failures")
sys.exit(failures > 0)
