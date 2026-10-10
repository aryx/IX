#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-machine's page (tiny/TinyMachineWeb.ml, plan_web.md stage 0) in
# a browser without a screen: Chrome, driven by its debugging protocol.
# The page's directory is built (./tiny-machine -web), served, opened;
# then keys are typed and the mouse moved as a person would:
#
# - ls typed: the console's text has the programs' names;
# - tiny-windows typed, then windows.events' first gestures (the right
#   button's menu, New, a rectangle swept, ls typed in the window): the
#   canvas is no longer black, and what it shows is saved (-o png);
# - the status line's speed is printed.
#
# The screen is not compared with a recorded one: the page's time is
# the browser's clock, not the machine's instructions, so two runs do
# not type at the same instruction (the recorded sessions, by
# tiny-machine -events, do; under node too: plan_web.md).
#
# With -kernel v6 (or t6), tiny-os's kernel and its disk instead: the
# prompt, and ls typed; it has no screen.
#
# With -url, a page already served (the website's: docs/t-ix.html, or
# https://aryx.github.io/IX/t-ix.html), nothing built; -kernel then
# says which kernel that page boots.
#
# Usage: TinyMachineWeb_test.py [-kernel v6|t6] [-url page] [-o screen.png] [-chrome program]
# Needs: google-chrome or chromium, python3's websockets; not in make
# test (a browser, and half a minute).

import asyncio, base64, functools, http.server, json, os, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.request
import websockets

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
args = sys.argv[1:]
png = args[args.index("-o") + 1] if "-o" in args else None
kernel = args[args.index("-kernel") + 1] if "-kernel" in args else "tiny-kernel"
url = args[args.index("-url") + 1] if "-url" in args else None
chrome = args[args.index("-chrome") + 1] if "-chrome" in args else shutil.which("google-chrome") or shutil.which("chromium")
if not chrome:
    sys.exit("TinyMachineWeb_test: no google-chrome or chromium")

def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p

class Page:
    def __init__(self, ws): self.ws = ws; self.n = 0
    async def send(self, method, **params):
        self.n += 1
        await self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            m = json.loads(await self.ws.recv())
            if m.get("id") == self.n:
                if "error" in m: raise Exception(f"{method}: {m['error']}")
                return m["result"]
    async def js(self, expr):
        r = await self.send("Runtime.evaluate", expression=expr, returnByValue=True)
        return r["result"].get("value")
    async def type(self, text):
        for ch in text:
            key = "Enter" if ch == "\n" else ch
            await self.send("Input.dispatchKeyEvent", type="keyDown", key=key)
            await self.send("Input.dispatchKeyEvent", type="keyUp", key=key)
            await asyncio.sleep(0.03)
    # the machine's buttons (1 left, 2 middle, 4 right) at a place of the
    # canvas; the protocol's are the browser's (1 left, 2 right, 4 middle)
    async def mouse(self, x, y, buttons):
        box = await self.js("(r => [r.left, r.top])(document.getElementById('screen').getBoundingClientRect())")
        b = (buttons & 1) | (2 if buttons & 4 else 0) | (4 if buttons & 2 else 0)
        await self.send("Input.dispatchMouseEvent", type="mouseMoved", x=box[0] + x, y=box[1] + y, buttons=b,
                        button="left" if b & 1 else "right" if b & 2 else "middle" if b & 4 else "none")
        await asyncio.sleep(0.25)
    async def wait(self, what, expr, seconds=30):
        end = time.time() + seconds
        while time.time() < end:
            if await self.js(expr): return
            await asyncio.sleep(0.2)
        raise Exception(f"not seen in {seconds} s: {what}; status: {await self.js(STATUS)}; console: {await self.js(CONSOLE)!r}")

STATUS = "document.getElementById('status').textContent"
CONSOLE = "document.getElementById('console').textContent"
# the canvas's pixels that are not black
LIT = """(c => { const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data; let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i] | d[i+1] | d[i+2]) n++; return n; })(document.getElementById('screen'))"""

async def session(port, debug):
    for _ in range(100):
        try:
            tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{debug}/json"))
            tab = next(t for t in tabs if t["type"] == "page"); break
        except Exception: await asyncio.sleep(0.1)
    else: raise Exception("the browser's debugging port does not answer")
    async with websockets.connect(tab["webSocketDebuggerUrl"], max_size=None) as ws:
        p = Page(ws)
        await p.send("Page.navigate", url=url or f"http://127.0.0.1:{port}/" + ("" if kernel == "tiny-kernel" else "?image=kernel.img&disk=fs.img"))
        await p.wait("the shell's prompt", f"{CONSOLE}.includes('$ ')")
        print("ok the kernel boots: the shell's prompt on the console")
        await p.type("ls")
        await asyncio.sleep(0.5)
        shown = await p.js(CONSOLE)
        assert shown.rstrip("\xa0").endswith("$ ls"), f"the keys typed are not shown before Enter: {shown[-20:]!r}"
        assert await p.js("document.getElementById('cursor') !== null"), "no cursor on the console"
        await p.type("\n")
        await p.wait("ls's answer", f"{CONSOLE}.includes('{'tetris' if kernel == 'tiny-kernel' else 'cat'}')")
        assert "$ ls\n" in await p.js(CONSOLE), "the line typed is not echoed on the console"
        print("ok ls typed: the line echoed, the programs' names")
        if kernel != "tiny-kernel":
            print("   status:", await p.js(STATUS)); return
        assert await p.js(LIT) == 0, "the screen is not black before a program draws"
        await p.type("tiny-windows\n")
        await p.wait("tiny-windows' screen", f"{LIT} > 100000")
        # windows.events' first gestures: the menu by the right button,
        # New, a rectangle swept by the left one, ls typed in its shell
        for x, y, b in [(300, 200, 0), (300, 200, 4), (310, 208, 4), (310, 208, 0), (40, 40, 0), (40, 40, 1), (200, 150, 1), (360, 260, 1), (360, 260, 0)]:
            await p.mouse(x, y, b)
        await asyncio.sleep(3)
        before = await p.js(LIT)
        await p.type("ls\n")
        await asyncio.sleep(6)
        after = await p.js(LIT)
        assert after != before, f"ls typed in the window changes no pixel ({before} lit)"
        print(f"ok tiny-windows: a window swept, ls typed in it (pixels not black: {before}, then {after})")
        print("   status:", await p.js(STATUS))
        if png:
            data = await p.js("document.getElementById('screen').toDataURL('image/png')")
            open(png, "wb").write(base64.b64decode(data.split(",")[1]))
            print("   screen:", png)

def main():
    web = tempfile.mkdtemp()
    profile = tempfile.mkdtemp()
    browser = None
    try:
        if not url: subprocess.run([os.path.join(ROOT, "tiny-machine"), "-web", web, kernel], check=True, stderr=subprocess.DEVNULL)
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *a): pass
        handler = functools.partial(Quiet, directory=web)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        debug = free_port()
        browser = subprocess.Popen([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", f"--remote-debugging-port={debug}", "--remote-allow-origins=*",
                                    f"--user-data-dir={profile}", "--window-size=800,900", "about:blank"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        asyncio.run(session(server.server_address[1], debug))
    except Exception as e:
        print("FAIL", e); return 1
    finally:
        if browser: browser.terminate(); browser.wait()
        shutil.rmtree(web, ignore_errors=True); shutil.rmtree(profile, ignore_errors=True)
    return 0

sys.exit(main())
