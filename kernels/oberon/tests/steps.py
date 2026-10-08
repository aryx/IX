#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Makes session.steps (the steps tests/graphics.py plays: mini-mk check)
# from places on the screen, x and y from its top left corner: a move
# is to where a word is, from where the mouse was (it starts at the
# screen's centre). When the layout or System.Tool changes, the places
# here change; then mini-mk check's screens are looked at and their
# MD5s recorded again (session.md5).
#   tests/steps.py tests/session.steps
import sys
pos=[512,383]; steps=[]
def to(x,y):
    steps.append(('move', x-pos[0], y-pos[1])); pos[0]=x; pos[1]=y
def click(*keys):
    steps.append(('buttons', [('down',k) for k in keys]+[('up',k) for k in reversed(keys)]))
def drag(key, dx, dy, then=None):
    seq=[('down',key),('move',dx,dy)]
    if then: seq+= [('down',then),('up',then)]
    seq.append(('up',key)); steps.append(('buttons',seq)); pos[0]+=dx; pos[1]+=dy
# the texts
to(200,48); click('left'); steps.append(('type','hello oberon'))
to(60,24); drag('right',60,0); drag('right',40,0,'middle'); drag('right',50,0,'left')
to(8,96); click('left'); click('right')
# the commands
to(840,279); click('middle')                       # System.Watch
to(772,351); click('right'); to(690,339); click('middle')   # *.Text selected, System.Directory ^
to(372,6); click('middle')                         # Edit.Store (the text's menu)
to(170,6); click('middle')                         # System.Copy
to(240,6); click('middle')                         # System.Grow
to(110,6); click('middle')                         # System.Close (the grown one)
# the viewers
to(900,518); drag('left',0,100)
steps.append(('buttons',[('down','left'),('down','middle'),('move',-500,-200),('up','middle'),('up','left')])); pos[0]-=500; pos[1]-=200
# the programs
to(690,485); click('middle')                       # PCLink1.Run: no such command
to(700,461); click('middle')                       # System.ShowModules
to(685,495); click('middle')                       # Hilbert.Draw
to(880,495); click('middle')                       # Stars.Open
for x, y in [(258,600),(258,600)]: to(x, y); click('middle')        # Stars.Step, twice
open(sys.argv[1],'w').write('[' + ',\n '.join(repr(s) for s in steps) + ']\n')
print(len(steps),'steps')
