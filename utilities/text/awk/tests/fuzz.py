#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A fuzzer for mini-awk: random programs on random lines, through
# principia's awk (reference.sh builds it) and mini-awk, which must
# print the same and end with the same status. Two kinds of programs:
# made by a grammar (patterns, every statement, every built-in but the
# ones reference.sh says are not Plan 9's there, and sqrt, exp, log,
# sin and cos, whose last bits are goken's library's; loops that end), and
# lines of random tokens, for which the two must agree on whether the
# text is a program, and on the first line of what they say if not (the
# C says more after it, and shows another context: CLI.mli). From the
# root, after dune build:
#
#   utilities/text/awk/tests/fuzz.py [seed] [count]
import random, subprocess, sys, os, re, tempfile
HERE=os.path.dirname(os.path.abspath(__file__))
AWK=os.environ.get("AWK", "/tmp/ix-awk-reference/awk")
T=os.environ.get("MINIAWK", os.path.join(HERE, "../../../../_build/default/utilities/text/awk/Main.exe"))
if not os.path.exists(AWK) and subprocess.run([os.path.join(HERE, "reference.sh"), os.path.dirname(AWK)], capture_output=True).returncode != 0:
    print("skipped: no awk at " + AWK); sys.exit(0)
R=random.Random(int(sys.argv[1]) if len(sys.argv)>1 else 0)
VARS=["x","y","n","s","t"]
ARRS=["a","b"]
WORDS=["foo","bar","baz","10","3.5","-2","0","abc","a1","x-y","héllo","0x1A","010","1e2",".5","A","bb","foo.bar","a:b:c","  "]
REGEX=["o","^a","a$","[0-9]+","b*","a|b","fo+","[a-c]","x.y","\\.","[^a]","(ab)+","^$","é","o?"]
def number(): return R.choice(["0","1","2","3","7","10","0.5","2.5","100","1e3","-1","12345.678",".25"])
def string(): return '"'+R.choice(WORDS+["","%d"," ","\\t","a b c","&","\\\\&"]).replace('"','')+'"'
def regex(): return "/"+R.choice(REGEX)+"/"
def lvalue():
    k=R.randint(0,9)
    if k<5: return R.choice(VARS)
    if k<7: return "$"+R.choice(["1","2","3","NF","(1+1)","0"])
    return R.choice(ARRS)+"["+R.choice([expr(3), string(), number(), "$1"])+"]"
def expr(d=0):
    k=R.randint(0,40)
    if d>3 or k<8: return R.choice([number(), string(), R.choice(VARS), "$"+str(R.randint(0,4)), "NF", "NR", "$NF", lvalue()])
    if k<14: return expr(d+1)+R.choice([" + "," - "," * "," / "," % "," ^ "])+expr(d+1)
    if k<17: return expr(d+1)+" "+expr(d+1)
    if k<21: return "("+expr(d+1)+R.choice([" < "," <= "," == "," != "," > "," >= "," && "," || "])+expr(d+1)+")"
    if k==21: return "("+expr(d+1)+R.choice([" ~ "," !~ "])+R.choice([regex(), string(), expr(d+1)])+")"
    if k==22: return "-"+expr(d+1)
    if k==23: return "!"+expr(d+1)
    if k==24: return "("+expr(d+1)+" ? "+expr(d+1)+" : "+expr(d+1)+")"
    if k==25: return lvalue()+R.choice([" = "," += "," -= "," *= "])+expr(d+1)
    if k==26: return R.choice(["++","--"])+lvalue()
    if k==27: return lvalue()+R.choice(["++","--"])
    if k==28: return "length("+R.choice([expr(d+1), ""])+")"
    if k==29: return "substr("+expr(d+1)+", "+expr(d+1)+R.choice(["", ", "+expr(d+1)])+")"
    if k==30: return "index("+expr(d+1)+", "+expr(d+1)+")"
    if k==31: return "match("+expr(d+1)+", "+R.choice([regex(), string()])+")"
    if k==32: return "split("+expr(d+1)+", "+R.choice(ARRS)+R.choice(["", ", "+string(), ", "+regex()])+")"
    if k==33: return R.choice(["sub","gsub"])+"("+R.choice([regex(), string()])+", "+string()+R.choice(["", ", "+lvalue()])+")"
    if k==34: return "sprintf("+fmt()+")"
    if k==35: return R.choice(["toupper","tolower","int","int","length"])+"("+expr(d+1)+")"
    if k==36: return "("+expr(d+1)+" in "+R.choice(ARRS)+")"
    if k==37: return R.choice(["f("+expr(d+1)+")", "g("+expr(d+1)+", "+expr(d+1)+")", "RSTART", "RLENGTH", "FNR", "length"])
    if k==38: return "("+expr(d+1)+")"
    return R.choice(VARS)
def fmt():
    convs=[R.choice(["%d","%5d","%-4d","%03d","%s","%6s","%-6s|","%.2s","%c","%f","%.2f","%8.3f","%e","%g","%.3g","%%","%i","%+d","%5.1f"]) for _ in range(R.randint(0,3))]
    n=sum(1 for c in convs if c!="%%")
    return '"'+" ".join(convs)+'\\n"'+"".join(", "+expr(2) for _ in range(n+R.choice([0,0,0,1,-1]) if n else 0))
def stmt(d=0, func=False, loop=False):
    k=R.randint(0,30)
    if d>2 or k<6: return "print "+", ".join(printable() for _ in range(R.randint(0,3)))
    if k<8: return "printf "+fmt()
    if k<12: return expr()
    if k==12: return "if ("+expr()+") "+stmt(d+1,func,loop)+R.choice(["", "; else "+stmt(d+1,func,loop)])
    if k==13: return "{ i%d = 0; while (i%d++ < %d) %s }" % (d,d,R.randint(0,3),stmt(d+1,func,True))
    if k==14: return "for (j%d = 0; j%d < %d; j%d++) %s" % (d,d,R.randint(0,3),d,stmt(d+1,func,True))
    if k==15: return "for (k in "+R.choice(ARRS)+") "+stmt(d+1,func,True)
    if k==16: return "{ "+"; ".join(stmt(d+1,func,loop) for _ in range(R.randint(0,3)))+" }"
    if k==17: return "delete "+R.choice(ARRS)+R.choice(["", "["+expr(3)+"]"])
    if k==18 and loop: return R.choice(["break","continue"])
    if k==19 and func: return "return "+R.choice(["",expr()])
    if k==20 and not func: return R.choice(["next","next","exit","exit "+number()])
    if k==21: return "{ m%d = 0; do { m%d++; %s } while (m%d < %d) }" % (d,d,stmt(d+1,func,True),d,R.randint(0,2))
    if k==22: return R.choice(["$0 = "+expr(), "NF = "+R.choice(["1","2","5"]), "$"+str(R.randint(1,5))+" = "+expr(), 'FS = '+R.choice(['":"','" "','"o"','""','"[0-9]"']), 'OFS = "-"', 'CONVFMT = "%.3g"', 'SUBSEP = ":"'])
    if k==23 and not func: return "getline"+R.choice([""," x"])
    return "print "+printable()
def printable():
    e=expr(1)
    # (a comparison, a >, or a pipe is not print's argument without its parentheses)
    return e
def rule():
    k=R.randint(0,14)
    pat=R.choice(["", "", "NR == "+str(R.randint(1,5)), regex(), "!"+regex(), expr(1), "$1 ~ "+regex(), "NR == 2, NR == 4", regex()+", "+regex(), "("+expr(1)+")", "NF > 2", "$2 > 5"])
    if k==0: return "BEGIN { "+stmt(0)+" }"
    if k==1: return "END { "+stmt(0)+"; print NR, x, length(a) }"
    if k==2: return pat or "1"
    return pat+" { "+"; ".join(stmt(0) for _ in range(R.randint(1,3)))+" }"
FUNCS="function f(p,   l) { l = p p; "+"%s"+"; return l }\nfunction g(p, q) { %s; return p + q }\n"
TOKENS=["1","2.5","x","y","a","$","$1","NF","(",")","{","}","[","]",",",";","\n","+","-","*","/","%","^","=","+=","==","!=","<",">",">=","&&","||","!","~","++","--","?",":","|",">>",
        "if","else","while","for","do","in","print","printf","return","function","func","next","exit","break","continue","delete","getline","BEGIN","END",
        "length","substr","split","sub","index","match","sprintf",'"s"','"',"/re/","#c","\\","f(","in a","/"]
def lines():
    return "".join(" ".join(R.choice(WORDS+["1","22","3","x","y z"]) for _ in range(R.randint(0,5)))+"\n" for _ in range(R.randint(0,6)))
def clean(out, prog):
    out=out.replace(prog.encode(), b"awk")
    out=re.sub(rb"(?m)^ source line \d+$", b" source line N", out)
    # (an integer past 2^53: its last digits are goken's print's)
    out=re.sub(rb"\d{17,}", lambda m: m.group(0)[:15]+b"0"*(len(m.group(0))-15), out)
    out=re.sub(rb"(\d\.\d{14})\d+e", rb"\1e", out)
    # (0 ^ -0.5: a NaN for goken's pow, an infinity for this machine's)
    return out.replace(b"pow argument out of domain", b"pow").replace(b"pow result out of range", b"pow")
def run(prog, path, data):
    try: r=subprocess.run([prog, "-f", path], input=data, capture_output=True, timeout=10)
    except subprocess.TimeoutExpired: return None
    if r.returncode<0: return None
    return (clean(r.stdout, prog), clean(r.stderr, prog), r.returncode)
count=int(sys.argv[2]) if len(sys.argv)>2 else 300
fails=passed=errors=0
with tempfile.TemporaryDirectory() as d:
    for i in range(count):
        soup=R.randint(0,5)==0
        if soup: text=" ".join(R.choice(TOKENS) for _ in range(R.randint(1,10)))+"\n"
        else: text=(FUNCS % (stmt(1,True), stmt(1,True)) if R.randint(0,2) else "")+"\n".join(rule() for _ in range(R.randint(1,4)))+"\n"
        data=lines().encode()
        path=os.path.join(d,"case.awk"); open(path,"w").write(text)
        a=run(AWK,path,data)
        if a is None: passed+=1; continue
        b=run(T,path,data)
        # (a function that calls itself for ever: awk dies of it, with nothing said)
        if b is None and a[2]!=0 and a[1]==b"": passed+=1; continue
        if b is not None and a[2]!=0 and b[2]!=0 and b" context is" in a[1]+b[1]:
            # an error in the text: the same first line
            errors+=1
            a=(a[0], a[1].split(b"\n")[0], a[2]); b=(b[0], b[1].split(b"\n")[0], b[2])
        if a!=b:
            fails+=1
            if fails<=int(os.environ.get("SHOW","5")): print("FAIL case %d\n%s--- input: %r\n--- awk: %r\n--- mini-awk: %r" % (i, text, data, a, (b[0][:300], b[1][:300], b[2]) if b else b))
print("%d programs (%d refused by both), %d where awk dies or loops, %d failures" % (count, errors, passed, fails))
sys.exit(1 if fails else 0)
