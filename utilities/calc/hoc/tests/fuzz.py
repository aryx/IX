#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A fuzzer for mini-hoc: random programs (expressions of every operator,
# assignments, loops that end, functions and procedures, calls of the
# wrong shape, and lines of random tokens for the errors), through
# goken's hoc and mini-hoc, which must print the same. A program on
# which hoc itself dies is passed (bugs/goken.md: a return alone under
# an if). Not among the random tokens: return (outside a definition
# and before a token that is no expression's, hoc says so where mini-hoc
# says a syntax error: CLI.mli). For dune's mini-hoc: ix's own has
# Plan 9's C library, whose log10(0), 0^-1 and sin(PI) are not this
# machine's. From the root, after dune build:
#
#   utilities/calc/hoc/tests/fuzz.py [seed] [count]
import random, subprocess, sys, os, tempfile
HOC=os.environ.get("HOC", os.path.expanduser("~/goken/ROOT/arch/boot-gcc/bin/hoc"))
T=os.environ.get("MINIHOC", os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../_build/default/utilities/calc/hoc/Main.exe"))
R=random.Random(int(sys.argv[1]) if len(sys.argv)>1 else 0)
VARS=["a","b","c","n","_","PI"]
TOKENS=["1","2.5",".","1e","a","b","f","p","sin","(",")","{","}",",",";","+","-","*","/","%","^","=","+=","==","!=","<",">=","&&","||","!","++","--",
        "if","else","while","for","print","func","proc","read",'"s"','"',"#","\\","|","&","0x1"]
PRELUDE='a = 3\nb = 0.5\nc = -2\nn = 4\nfunc f(n) { if (n <= 0) { return 1 }\n return n * f(n-1) }\nfunc g(a, b) return a - b\nproc p(n) print n, "\\n"\n1\n'
def number(): return R.choice(["0","1","2","3","7","10","0.5","2.5","1e3","1e-2",".25","100","1e10","12345.678"])
def expr(d=0):
    k=R.randint(0,22)
    if d>3 or k<5: return R.choice([number(), number(), R.choice(VARS)])
    if k<11: return expr(d+1)+R.choice([" + "," - "," * "," / "," % ","^"," > "," >= "," < "," <= "," == "," != "," && "," || ","-","+"])+expr(d+1)
    if k==11: return "("+expr(d+1)+")"
    if k==12: return "-"+expr(d+1)
    if k==13: return "!"+expr(d+1)
    if k==14: return R.choice(["sin","cos","atan","exp","sqrt","int","abs","log10","tanh","asin"])+"("+expr(d+1)+")"
    if k==15: return R.choice(["++","--"])+R.choice(VARS)
    if k==16: return R.choice(VARS)+R.choice(["++","--"])
    if k==17: return R.choice(VARS)+R.choice([" = "," += "," -= "," *= "," /= "])+expr(d+1)
    if k==18: return "f("+", ".join(expr(d+1) for _ in range(R.choice([1,1,1,0,2])))+")"
    if k==19: return "g("+", ".join(expr(d+1) for _ in range(R.choice([2,2,2,1,3])))+")"
    return R.choice(VARS)
def stmt(d=0, inside=False):
    k=R.randint(0,16)
    if d>2 or k<5: return expr()
    if k<7: return "print "+", ".join(R.choice([expr(), '"s "', '"\\t\\n"']) for _ in range(R.randint(1,3)))
    if k==7: return "if ("+expr()+") "+stmt(d+1,inside)
    if k==8: return "if ("+expr()+") "+stmt(d+1,inside)+" else "+stmt(d+1,inside)
    # (a counter of its own for each depth: the loops end)
    if k==9: return "{ i%d = 0\n while (i%d < %d) { i%d++\n %s } }" % (d, d, R.randint(0,4), d, stmt(d+1,inside))
    if k==10: return "for (j%d = 0; j%d < %d; j%d++) %s" % (d, d, R.randint(0,4), d, stmt(d+1,inside))
    if k==11: return "{ "+R.choice(["\n"," "]).join(stmt(d+1,inside) for _ in range(R.randint(0,3)))+" }"
    if k==12: return "p("+", ".join(expr() for _ in range(R.choice([1,1,0,2])))+")"
    if k==13 and inside: return "{ return "+R.choice(["",expr()])+" }"
    if k==14 and inside: return "return "+expr()
    return expr()
def line():
    k=R.randint(0,30)
    if k==0: return "func f("+R.choice(["n","a","n, a",""])+") "+stmt(0,True)
    if k==1: return "func f(n) { if (n <= 0) { return "+expr()+" }\n return "+R.choice(["f(n-1)","n * f(n-1)","f(n-1) + f(n-2)", "f(n+1)"])+" }"
    if k==2: return "func g(a, b) { "+stmt(1,True)+"\n return "+expr()+" }"
    if k==3: return "proc p("+R.choice(["n","a",""])+") "+stmt(0,True)
    if k==4: return " ".join(R.choice(TOKENS) for _ in range(R.randint(1,6)))
    if k==5: return expr()+" "+R.choice(TOKENS)
    if k==6: return "# "+expr()
    if k==7: return expr()+" \\\n "+R.choice(["+ 1", "", "* 2"])
    return stmt()
def run(prog, path, how):
    try:
        if how==0: r=subprocess.run([prog], stdin=open(path,"rb"), capture_output=True, timeout=10)
        elif how==1: r=subprocess.run([prog], input=open(path,"rb").read(), capture_output=True, timeout=10)
        else: r=subprocess.run([prog, os.path.basename(path)], cwd=os.path.dirname(path), stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
    except subprocess.TimeoutExpired: return None
    if r.returncode<0: return None
    return (r.stdout, r.stderr.replace(prog.encode(), b"hoc"), r.returncode)
count=int(sys.argv[2]) if len(sys.argv)>2 else 300
fails=passed=0
with tempfile.TemporaryDirectory() as d:
    for i in range(count):
        # a few lines: an error ends a file, so short programs see more of them
        text="\n".join(line() for _ in range(R.randint(1,8)))+"\n"
        # most of them with their names defined: fewer end at the first one
        if R.randint(0,3): text=PRELUDE+text
        path=os.path.join(d,"case.hoc"); open(path,"w").write(text)
        how=R.randint(0,2)
        a=run(HOC,path,how)
        if a is None:
            passed+=1
            if os.environ.get("DIES"): print("--- hoc dies or loops:\n"+text)
            continue
        b=run(T,path,how)
        if a!=b:
            fails+=1
            if fails<=int(os.environ.get("SHOW","5")): print("FAIL case %d (%s)\n%s--- hoc: %r\n--- mini-hoc: %r" % (i, ["file","pipe","argument"][how], text, a, b))
print("%d programs, %d where hoc dies or loops, %d failures" % (count, passed, fails))
sys.exit(1 if fails else 0)
