#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What mini-qemu's page allocates while mini-9pi boots (plan_web.md,
# stage 2): Chrome without a screen, its sampling of allocations kept
# also for what the collector took back (node 18's does not keep it),
# for some seconds of the boot; then the bytes by the function that
# asked for them, and the seconds of the profile by function.
#
# Usage: page_alloc.py directory [seconds, default 40]
#   directory: a page's (index.html, MiniQemuWeb.js built with
#   js_of_ocaml --pretty --debug-info for the names, kernel.img,
#   card.img.gz), as MiniQemuWeb_test.py makes one.
# Needs: google-chrome or chromium, python3's websockets.

import asyncio, collections, functools, http.server, json, shutil, socket, subprocess, sys, tempfile, threading, urllib.request
import websockets

web = sys.argv[1]; seconds = int(sys.argv[2]) if len(sys.argv) > 2 else 40
chrome = shutil.which("google-chrome") or shutil.which("chromium")

async def session(port, debug):
    for _ in range(100):
        try:
            tab = next(t for t in json.load(urllib.request.urlopen(f"http://127.0.0.1:{debug}/json")) if t["type"] == "page"); break
        except Exception: await asyncio.sleep(0.1)
    async with websockets.connect(tab["webSocketDebuggerUrl"], max_size=None) as ws:
        n = 0
        async def send(method, **params):
            nonlocal n; n += 1
            await ws.send(json.dumps({"id": n, "method": method, "params": params}))
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") == n:
                    if "error" in m: raise Exception(f"{method}: {m['error']}")
                    return m["result"]
        await send("Page.navigate", url=f"http://127.0.0.1:{port}/?kernel=kernel.img&card=card.img.gz")
        await asyncio.sleep(12)   # the files fetched, the board started
        await send("HeapProfiler.enable"); await send("Profiler.enable")
        await send("HeapProfiler.startSampling", samplingInterval=16384, includeObjectsCollectedByMajorGC=True, includeObjectsCollectedByMinorGC=True)
        await send("Profiler.start")
        await asyncio.sleep(seconds)
        cpu = (await send("Profiler.stop"))["profile"]
        heap = (await send("HeapProfiler.stopSampling"))["profile"]
        status = (await send("Runtime.evaluate", expression="document.getElementById('status').textContent", returnByValue=True))["result"].get("value")
        print("status:", status)
        own = collections.Counter()
        def walk(x):
            f = x["callFrame"]; own[(f["functionName"] or "(a closure)") + ":" + str(f["lineNumber"])] += x["selfSize"]
            for c in x["children"]: walk(c)
        walk(heap["head"]); total = sum(own.values())
        print(f"allocated, sampled: {total / 1e6:.0f} MB in {seconds} s")
        for k, v in own.most_common(14): print(f"  {100 * v / total:5.1f}%  {v / 1e6:8.1f} MB  {k}")
        nodes = {x["id"]: x for x in cpu["nodes"]}; t = collections.Counter()
        for s, d in zip(cpu["samples"], cpu["timeDeltas"]):
            f = nodes[s]["callFrame"]; t[(f["functionName"] or "(a closure)") + ":" + str(f["lineNumber"])] += d
        all_ = sum(t.values())
        print("time:")
        for k, v in t.most_common(14): print(f"  {100 * v / all_:5.1f}%  {k}")

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=web))
threading.Thread(target=server.serve_forever, daemon=True).start()
s = socket.socket(); s.bind(("127.0.0.1", 0)); debug = s.getsockname()[1]; s.close()
profile = tempfile.mkdtemp()
browser = subprocess.Popen([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", f"--remote-debugging-port={debug}", "--remote-allow-origins=*",
                            f"--user-data-dir={profile}", "--window-size=1100,1100", "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try: asyncio.run(session(server.server_address[1], debug))
finally: browser.terminate(); browser.wait(); shutil.rmtree(profile, ignore_errors=True)
