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
# - the screen clicked, and rio typed on the keyboard: the canvas
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
#   -then KEYS  with -game: keys typed to the game after that (a space,
#         < > ^ the arrows), each held 0.4 s; the screen saved shows it
#   -serve PORT  no browser: the page's directory made and served there,
#         for a person's own browser (from another machine: ssh -L PORT:localhost:PORT)
#   -game  after rio's menu: a window swept, and this program typed in
#         it (cameltry): the status every 8 seconds (-seconds N: for N
#         seconds, 32), the screen at the end
#   -trace  with -game: what Chrome's threads do for 6 seconds of it, by its own trace
#   -profile  with -game: Chrome's profile of 15 seconds of it, by function
#   -query  more of the page's address (ips=30&jit=0: the board's pace,
#         no translation to JavaScript)
# Needs: google-chrome or chromium, python3's websockets; mini-9pi built
# (./mini-pi -g -n mini-9pi's files: make -C kernels/9pi ix-web card).
# Not in make test: a browser, and minutes.

import asyncio, base64, functools, gzip, http.server, json, os, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.request
import websockets

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
args = sys.argv[1:]
opt = lambda name, default=None: args[args.index(name) + 1] if name in args else default
png, url, js, kernel, query = opt("-o"), opt("-url"), opt("-js"), opt("-kernel"), opt("-query", "")
game = opt("-game")
serve = opt("-serve")
chrome = opt("-chrome", shutil.which("google-chrome") or shutil.which("chromium"))
if not chrome and "-serve" not in args:
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
            if self.on_event: self.on_event(m)
    on_event = None
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
        await p.send("Page.navigate", url=url or f"http://127.0.0.1:{port}/?kernel=kernel.img&card=card.img.gz" + ("&" + query if query else ""))
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
        print(f"ok rio typed on the keyboard: its screen after {time.time() - t0 - 5:.0f} s (white pixels: {white}, then {await p.js(WHITE)})")
        print("   status:", await p.js(STATUS))
        # the mouse: idle, then moved for some seconds (the status says
        # what the kernel then costs); the cursor is the browser's, in
        # the kernel's shape; the right button gives rio's menu
        box = await p.js("(r => [r.left, r.top])(document.getElementById('screen').getBoundingClientRect())")
        t0 = time.time()
        await p.wait("rio waiting (under 2 million instructions a second)", f"parseFloat({STATUS}) < 2", 120)
        await asyncio.sleep(2)
        print(f"   rio waits after {time.time() - t0 - 2:.0f} s more; idle:", await p.js(STATUS))
        t0 = time.time(); k = 0
        while time.time() - t0 < 6:
            k += 1
            await p.send("Input.dispatchMouseEvent", type="mouseMoved", x=box[0] + 100 + (k * 3) % 400, y=box[1] + 100 + (k * 2) % 250)
            await asyncio.sleep(1 / 60)
        print("   the mouse moving:", await p.js(STATUS))
        cursor = await p.js("document.getElementById('screen').style.cursor")
        print(("ok" if cursor.startswith("url(") else "FAILED") + " the cursor is the browser's, in the kernel's shape:", cursor[:30] + "...", cursor[-16:])
        before = await p.js(SUM); t0 = time.time()
        await p.send("Input.dispatchMouseEvent", type="mousePressed", x=box[0] + 300, y=box[1] + 200, button="right", buttons=2, clickCount=1)
        await p.wait("rio's menu under the right button", f"{SUM} != '{before}'", 60)
        print(f"ok the right button: the screen changes (rio's menu) after {time.time() - t0:.1f} s")
        await asyncio.sleep(1)
        if png:
            data = await p.js("document.getElementById('screen').toDataURL('image/png')")
            open(png.replace(".png", "-menu.png"), "wb").write(base64.b64decode(data.split(",")[1]))
        if not game:
            await p.send("Input.dispatchMouseEvent", type="mouseReleased", x=box[0] + 500, y=box[1] + 400, button="right", buttons=0, clickCount=1)
            await asyncio.sleep(2)
        else:
            # New (under the mouse), a window swept with the right button, a
            # click in it, and the game typed there: what the status says
            # after some seconds of it
            async def mouse(kind, x, y, button="none", buttons=0):
                await p.send("Input.dispatchMouseEvent", type=kind, x=box[0] + x, y=box[1] + y, button=button, buttons=buttons, clickCount=1 if kind != "mouseMoved" else 0)
                await asyncio.sleep(0.3)
            await mouse("mouseReleased", 300, 200, "right", 0)
            await asyncio.sleep(1)
            await mouse("mousePressed", 100, 100, "right", 2)
            for k in range(1, 7): await mouse("mouseMoved", 100 + 100 * k, 100 + 80 * k, "right", 2)
            await mouse("mouseReleased", 700, 580, "right", 0)
            t0 = time.time()
            await p.wait("the window's shell waiting", f"parseFloat({STATUS}) < 2", 120)
            print(f"ok a window swept: quiet after {time.time() - t0:.0f} s")
            await mouse("mousePressed", 400, 300, "left", 1); await mouse("mouseReleased", 400, 300, "left", 0)
            await p.type(game + "\n", pause=0.1)
            for k in range(int(opt("-seconds", "32")) // 8):
                await asyncio.sleep(8)
                print(f"   {game}, after {8 * (k + 1)} s:", await p.js(STATUS))
            if opt("-then"):
                # (keys for the game itself, each held a moment: a space starts cameltry)
                for ch in opt("-then"):
                    key = {"<": "ArrowLeft", ">": "ArrowRight", "^": "ArrowUp"}.get(ch, ch)
                    await p.send("Input.dispatchKeyEvent", type="keyDown", key=key, code=key if len(key) > 1 else code(ch))
                    await asyncio.sleep(0.4)
                    await p.send("Input.dispatchKeyEvent", type="keyUp", key=key, code=key if len(key) > 1 else code(ch))
                    await asyncio.sleep(0.6)
                await asyncio.sleep(4)
                print(f"   {game}, after its keys:", await p.js(STATUS))
            if "-trace" in args:
                # what Chrome's threads do, 6 seconds of the game: the events
                # of its own trace, their own time by name (a thread a column)
                events = []
                p.on_event = lambda m: events.extend(m["params"]["value"]) if m.get("method") == "Tracing.dataCollected" else None
                await p.send("Tracing.start", traceConfig={"includedCategories": ["devtools.timeline", "v8", "v8.execute", "blink", "toplevel", "disabled-by-default-v8.compile", "disabled-by-default-v8.runtime", "disabled-by-default-v8.gc", "disabled-by-default-v8.turbofan", "disabled-by-default-v8.maglev", "disabled-by-default-v8.runtime_stats"]})
                await asyncio.sleep(6)
                await p.send("Tracing.end")
                while True:
                    m = json.loads(await p.ws.recv())
                    if m.get("method") == "Tracing.tracingComplete": break
                    p.on_event(m)
                p.on_event = None
                by = {}
                for e in events:
                    if e.get("ph") == "X": by.setdefault((e["pid"], e["tid"]), []).append(e)
                for (pid, tid), l in sorted(by.items(), key=lambda kv: -sum(e.get("tdur", e["dur"]) for e in kv[1] if True))[:3]:
                    # own time: an event's duration less its children's (nested by time)
                    l.sort(key=lambda e: (e["ts"], -e["dur"])); own = {}; stack = []
                    for e in l:
                        while stack and stack[-1]["ts"] + stack[-1]["dur"] <= e["ts"]: stack.pop()
                        if stack: own[id(stack[-1])] = own.get(id(stack[-1]), stack[-1]["dur"]) - e["dur"]
                        own.setdefault(id(e), e["dur"]); stack.append(e)
                    names = {}
                    for e in l: names[e["name"]] = names.get(e["name"], 0) + own[id(e)]
                    total = sum(names.values())
                    print(f"   thread {pid}/{tid}: {total / 1e6:.2f} s in events of 6")
                    for name, d in sorted(names.items(), key=lambda kv: -kv[1])[:12]: print(f"      {d / 1e3:8.0f} ms  {name}")
            if "-profile" in args:
                # where the browser's time goes, 15 seconds of the game (the
                # names are OCaml's when -js was made with js_of_ocaml --pretty)
                await p.send("Profiler.enable"); await p.send("Profiler.start")
                await asyncio.sleep(15)
                prof = (await p.send("Profiler.stop"))["profile"]
                nodes = {x["id"]: x for x in prof["nodes"]}; own = {}; total = 0
                for sample, d in zip(prof["samples"], prof["timeDeltas"]):
                    f = nodes[sample]["callFrame"]
                    name = f["functionName"] or ("(a block)" if f["url"] == "" else f"(a closure, line {f['lineNumber']})")
                    own[name] = own.get(name, 0) + d; total += d
                for name, d in sorted(own.items(), key=lambda kv: -kv[1])[:22]: print(f"   {100 * d / total:5.1f}%  {name}")
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
        if serve:
            # (for a person's browser: the page served, and no more)
            print(f"mini-qemu's page: http://127.0.0.1:{serve}/?kernel=kernel.img&card=card.img.gz (Ctrl-C ends it)")
            http.server.ThreadingHTTPServer(("0.0.0.0", int(serve)), functools.partial(Quiet, directory=web)).serve_forever()
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=web))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        debug = free_port()
        browser = subprocess.Popen([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", f"--remote-debugging-port={debug}", "--remote-allow-origins=*",
                                    f"--user-data-dir={profile}", "--window-size=1100,1100", "about:blank"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        asyncio.run(session(server.server_address[1], debug))
    except KeyboardInterrupt: return 0
    except Exception as e:
        print("FAIL", e); return 1
    finally:
        if browser: browser.terminate(); browser.wait()
        shutil.rmtree(web, ignore_errors=True); shutil.rmtree(profile, ignore_errors=True)
    return 0

sys.exit(main())
