#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-qemu's page (raspberry/web/MiniQemuWeb.ml, plan_web.md stage 1)
# in a browser without a screen: Chrome, driven by its debugging
# protocol. A directory is made (the page, the board compiled to
# JavaScript, mini-9pi's kernel with mini-usbd, its card by gzip),
# served, opened; then, as a person would:
#
# - the shell's prompt on the serial line's text: the seconds it took;
# - ls /bin | wc typed there: its three numbers;
# - the screen clicked, and rio typed on the USB keyboard: the canvas
#   is rio's, grey where the console drawn was white; saved (-o png);
# - the status line (the speed, the board's clock) is printed.
#
# Usage: MiniQemuWeb_test.py [-js MiniQemuWeb.bc.js] [-kernel image] [-url page] [-o screen.png] [-chrome program]
#   -kernel  the kernel booted (default: kernels/9pi/kernel-pi1-web.img,
#         the one built for a page: make -C kernels/9pi ix-web; the
#         Pi's with mini-usbd is kernel-pi1-ixu.img)
#   -js   the board's JavaScript, already built (default: dune build
#         --profile release, as mini-pi builds mini-qemu)
#   -url  a page already served; nothing built
# Needs: google-chrome or chromium, python3's websockets; mini-9pi built
# (./mini-pi -g -n mini-9pi's files: make -C kernels/9pi ix-web card).
# Not in make test: a browser, and minutes.

import asyncio, base64, functools, gzip, http.server, json, os, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.request
import websockets

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
args = sys.argv[1:]
opt = lambda name, default=None: args[args.index(name) + 1] if name in args else default
png, url, js, kernel = opt("-o"), opt("-url"), opt("-js"), opt("-kernel")
chrome = opt("-chrome", shutil.which("google-chrome") or shutil.which("chromium"))
if not chrome:
    sys.exit("MiniQemuWeb_test: no google-chrome or chromium")

def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p

# a key's code, where it is on the keyboard: what the page gives the USB keyboard
def code(ch):
    if ch == "\n": return "Enter"
    if ch == " ": return "Space"
    if ch.isalpha(): return "Key" + ch.upper()
    if ch.isdigit(): return "Digit" + ch
    return {"/": "Slash", "-": "Minus", ".": "Period"}.get(ch, "")

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
    async def type(self, text, pause=0.05):
        for ch in text:
            key = "Enter" if ch == "\n" else ch
            await self.send("Input.dispatchKeyEvent", type="keyDown", key=key, code=code(ch))
            await asyncio.sleep(pause)
            await self.send("Input.dispatchKeyEvent", type="keyUp", key=key, code=code(ch))
            await asyncio.sleep(pause)
    async def click(self, x, y):
        box = await self.js("(r => [r.left, r.top])(document.getElementById('screen').getBoundingClientRect())")
        for kind in ["mousePressed", "mouseReleased"]:
            await self.send("Input.dispatchMouseEvent", type=kind, x=box[0] + x, y=box[1] + y, button="left", buttons=1 if kind == "mousePressed" else 0, clickCount=1)
            await asyncio.sleep(0.2)
    async def wait(self, what, expr, seconds):
        end = time.time() + seconds
        while time.time() < end:
            if await self.js(expr): return
            await asyncio.sleep(0.5)
        raise Exception(f"not seen in {seconds} s: {what}; status: {await self.js(STATUS)}; console: {(await self.js(CONSOLE))[-400:]!r}")

STATUS = "document.getElementById('status').textContent"
CONSOLE = "document.getElementById('console').textContent"
# a sum of the canvas's pixels: whether what it shows changed
SUM = """(c => { const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data; let n = 0;
  for (let i = 0; i < d.length; i += 4) n = (n * 31 + d[i] + d[i+1] * 3 + d[i+2] * 7) | 0; return c.width + 'x' + c.height + ' ' + n; })(document.getElementById('screen'))"""

WHITE = """(c => { const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data; let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i] > 240 && d[i+1] > 240 && d[i+2] > 240) n++; return n; })(document.getElementById('screen'))"""

async def session(port, debug):
    for _ in range(100):
        try:
            tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{debug}/json"))
            tab = next(t for t in tabs if t["type"] == "page"); break
        except Exception: await asyncio.sleep(0.1)
    else: raise Exception("the browser's debugging port does not answer")
    async with websockets.connect(tab["webSocketDebuggerUrl"], max_size=None) as ws:
        p = Page(ws)
        t0 = time.time()
        await p.send("Page.navigate", url=url or f"http://127.0.0.1:{port}/?kernel=kernel.img&card=card.img.gz")
        await p.wait("the shell's prompt", f"{CONSOLE}.includes('% ')", 400)
        print(f"ok mini-9pi boots: the shell's prompt on the serial line after {time.time() - t0:.0f} s")
        print("   status:", await p.js(STATUS))
        await p.type("ls /bin | wc\n")
        await p.wait("wc's answer", f"/\\n\\s+\\d+\\s+\\d+\\s+\\d+\\n/.test({CONSOLE})", 120)
        print("ok ls /bin | wc typed on the serial line:", (await p.js(CONSOLE)).split("wc\n")[-1].split("\n")[0].split())
        before = await p.js(SUM)
        await p.click(300, 200)
        assert await p.js("document.activeElement === document.getElementById('screen')"), "a click does not give the screen the keys"
        await p.type("rio\n", pause=0.15)
        await p.wait("rio typed, shown by the console drawn", f"{SUM} != '{before}'", 60)
        # rio's screen is grey where the console's was white
        white = await p.js(WHITE)
        t0 = time.time()
        await p.wait("rio's screen", f"{WHITE} < {white // 2}", 300)
        await asyncio.sleep(5)
        print(f"ok rio typed on the USB keyboard: its screen after {time.time() - t0 - 5:.0f} s (white pixels: {white}, then {await p.js(WHITE)})")
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
        if not url:
            built = js
            if not built:
                subprocess.run(["dune", "build", "--profile", "release", "./raspberry/web/MiniQemuWeb.bc.js"], cwd=ROOT, check=True, stderr=subprocess.DEVNULL)
                built = os.path.join(ROOT, "_build/default/raspberry/web/MiniQemuWeb.bc.js")
            k = os.path.join(ROOT, "kernels/9pi")
            shutil.copy(built, os.path.join(web, "MiniQemuWeb.js"))
            shutil.copy(os.path.join(ROOT, "raspberry/web/MiniQemuWeb.html"), os.path.join(web, "index.html"))
            shutil.copy(kernel or os.path.join(k, "kernel-pi1-web.img"), os.path.join(web, "kernel.img"))
            with open(os.path.join(k, "build/card.img"), "rb") as f, gzip.open(os.path.join(web, "card.img.gz"), "wb", compresslevel=1) as g:
                shutil.copyfileobj(f, g)
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *a): pass
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=web))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        debug = free_port()
        browser = subprocess.Popen([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", f"--remote-debugging-port={debug}", "--remote-allow-origins=*",
                                    f"--user-data-dir={profile}", "--window-size=1100,1100", "about:blank"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        asyncio.run(session(server.server_address[1], debug))
    except Exception as e:
        print("FAIL", e); return 1
    finally:
        if browser: browser.terminate(); browser.wait()
        shutil.rmtree(web, ignore_errors=True); shutil.rmtree(profile, ignore_errors=True)
    return 0

sys.exit(main())
