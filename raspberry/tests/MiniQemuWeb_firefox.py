#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-qemu's page in Firefox without a screen (WebDriver BiDi): the
# shell's prompt and the status line, a command typed on the serial
# line, then rio typed and the status every few seconds. A look, not a
# test: what MiniQemuWeb_test.py checks in Chrome is not checked here.
#
# Usage: MiniQemuWeb_firefox.py URL
#   URL: a page served, as MiniQemuWeb_test.py -serve PORT gives one
#   (http://127.0.0.1:PORT/?kernel=kernel.img&card=card.img.gz)
# Needs: firefox, python3's websockets.

import asyncio, json, os, shutil, subprocess, sys, tempfile, time
import websockets

url = sys.argv[1]
STATUS = "document.getElementById('status').textContent"
CONSOLE = "document.getElementById('console').textContent"

async def main():
    # (in the home directory: a Firefox packaged as a snap does not see /tmp)
    profile = tempfile.mkdtemp(prefix="ix-firefox-", dir=os.path.expanduser("~"))
    ff = subprocess.Popen(["firefox", "--headless", "--remote-debugging-port=9444", "--profile", profile, "--no-remote"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(200):
            try:
                ws = await websockets.connect("ws://127.0.0.1:9444/session", max_size=None); break
            except Exception: await asyncio.sleep(0.3)
        n = 0
        async def send(method, **params):
            nonlocal n; n += 1
            await ws.send(json.dumps({"id": n, "method": method, "params": params}))
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") == n:
                    if m.get("type") == "error": raise Exception(f"{method}: {m}")
                    return m["result"]
                if m.get("method") == "log.entryAdded": print("   the page's log:", m["params"].get("text"))
        await send("session.new", capabilities={})
        await send("session.subscribe", events=["log.entryAdded"])
        ctx = (await send("browsingContext.getTree"))["contexts"][0]["context"]
        t0 = time.time()
        await send("browsingContext.navigate", context=ctx, url=url, wait="complete")
        async def js(e):
            r = await send("script.evaluate", expression=e, target={"context": ctx}, awaitPromise=False)
            return r["result"].get("value")
        async def type(text):
            acts = []
            for ch in text: acts += [{"type": "keyDown", "value": ch}, {"type": "keyUp", "value": ch}, {"type": "pause", "duration": 60}]
            await send("input.performActions", context=ctx, actions=[{"type": "key", "id": "k", "actions": acts}])
        while time.time() - t0 < 400 and not await js(f"{CONSOLE}.includes('% ')"): await asyncio.sleep(1)
        print(f"the shell's prompt after {time.time() - t0:.0f} s; status:", await js(STATUS))
        await type("ls /bin | wc")
        await asyncio.sleep(8)
        print("ls /bin | wc:", (await js(CONSOLE)).split("wc\n")[-1].split("\n")[0].split())
        await type("rio")
        for k in range(4):
            await asyncio.sleep(5)
            print(f"rio typed, after {5 * (k + 1)} s:", await js(STATUS))
    finally:
        ff.terminate(); ff.wait()
        shutil.rmtree(profile, ignore_errors=True)

asyncio.run(main())
