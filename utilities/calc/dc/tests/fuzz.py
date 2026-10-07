#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A fuzzer for mini-dc: random commands (numbers of every shape, the
# arithmetic at random scales and bases, registers, arrays, strings,
# macros and comparisons), through principia's dc (reference.sh builds
# it) and mini-dc, which must print the same; a program that takes from
# an empty stack is passed. Not among the commands: X, whose 0 has a
# byte, which the C's multiplication keeps (0 times 1.5 prints as 00.0).
# From the root, after
# dune build:
#
#   utilities/calc/dc/tests/fuzz.py [seed] [count]
import random, subprocess, sys, os
HERE=os.path.dirname(os.path.abspath(__file__))
DC=os.environ.get("DC", "/tmp/ix-dc-reference/dc")
T=os.environ.get("MINIDC", os.path.join(HERE, "../../../../_build/default/utilities/calc/dc/Main.exe"))
if not os.path.exists(DC) and subprocess.run([os.path.join(HERE, "reference.sh"), os.path.dirname(DC)], capture_output=True).returncode != 0:
    print("skipped: no dc at " + DC); sys.exit(0)
R=random.Random(int(sys.argv[1]) if len(sys.argv)>1 else 0)
def number():
    k=R.randint(0,12)
    sign=R.choice(["","","","_"])
    if k<4: return sign+str(R.randint(0,20))
    if k<6: return sign+str(R.randint(0,10**R.randint(1,30)))
    if k<9: return sign+str(R.randint(0,999))+"."+"".join(R.choice("0123456789") for _ in range(R.randint(1,8)))
    if k==9: return sign+"."+"".join(R.choice("0123456789") for _ in range(R.randint(1,5)))
    if k==10: return R.choice(["0","1","100","99","0.0","10","1.50","A","F","1F"])
    return sign+str(R.randint(0,10**R.randint(1,6)))
REG="abcx"
def command(d=0):
    k=R.randint(0,60)
    if k<18: return number()
    if k<34: return R.choice(["+","-","*","/","%","+","-","*","/","p","p","d","v","z","Z","f"])
    if k<36: return str(R.randint(0,6))+" ^"
    if k<39: return str(R.choice([0,0,1,2,3,5,10,20,45]))+"k"
    if k==39: return R.choice(["16o","8o","2o","10o","10o","100o","3o","12o","17o"])
    if k==40: return R.choice(["16i","8i","2i","10i","10i","A i"])
    if k<44: return R.choice(["s","l","S","L"])+R.choice(REG)
    if k==44: return str(R.randint(0,5))+R.choice([":",";"])+R.choice("mn")
    if k==45: return R.choice(["K","I","O","c"])
    if k==46 and d<2: return "["+" ".join(command(d+1) for _ in range(R.randint(0,4)))+"]"+R.choice(["x","s"+R.choice(REG),"p",""])
    if k==47: return R.choice(["<","=",">","!<","!=","!>"])+R.choice(REG)
    if k==48: return "["+R.choice(["hi","A B","x y z","Zz","12"])+"]"+R.choice(["P","p",""])
    if k==49 and d>0: return R.choice(["q","1Q","2Q"])
    return R.choice(["p","+","*"])
def run(prog, text):
    try: r=subprocess.run([prog], input=text, capture_output=True, timeout=10)
    except subprocess.TimeoutExpired: return None
    if r.returncode<0: return None
    return (r.stdout, r.stderr, r.returncode)
count=int(sys.argv[2]) if len(sys.argv)>2 else 500
fails=passed=0
for i in range(count):
    # (a few numbers first: fewer programs start on an empty stack)
    text=(" ".join(number() for _ in range(R.randint(2,6)))+"\n"+"\n".join(" ".join(command() for _ in range(R.randint(1,8))) for _ in range(R.randint(1,6)))+"\n").encode()
    a=run(DC,text)
    # (not compared: after an operator found its stack empty, or a number
    # was run as a macro, the C goes on with blocks that are no value)
    if a is None or a[2]!=0 or b"stack empty" in a[0] or b"unimplemented" in a[0]: passed+=1; continue
    b=run(T,text)
    if a!=b:
        fails+=1
        if fails<=int(os.environ.get("SHOW","5")): print("FAIL case %d\n%s--- dc: %r\n--- mini-dc: %r" % (i, text.decode(), a, (b[0][:400], b[1][:300], b[2]) if b else b))
print("%d programs, %d passed (dc dies, loops, or an empty stack), %d failures" % (count, passed, fails))
sys.exit(1 if fails else 0)
