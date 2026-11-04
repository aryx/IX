// The skeletons ix's programs share, for the code map's configs
// (the code map: ~/github/ocaml-elm-playground's tinybox codemap, its
// docs/claude_notes/codemapconfig_guidelines.md): a function of the
// files, its bones' anchors defaulting to the usual names. The shapes
// after cli are xix's (~/github/xix/skeletons.libsonnet), the same names.
{
  // a mini program: Main.ml runs Cap.main, which calls its CLI's main,
  // which parses the command line and hands it to the program's core
  // ([core]: [anchor, role] pairs, the first called by the CLI, each the
  // next's caller)
  cli(name, core, main='Main.ml', cli='CLI.ml:def:main')::
    local bones = [[main, 'the program: Cap.main, the capabilities'], [cli, 'the command line: flags, arguments']] + core;
    {
      name: name,
      bones: [{ at: b[0], role: b[1] } for b in bones],
      joints: [{ from: bones[i][0], to: bones[i + 1][0] } for i in std.range(0, std.length(bones) - 2)],
    },

  // a chain: [anchor, role, say] each, the first calling (or handing
  // its data to) the second, ... -- a path across files (a compiler's
  // passes, a request's way down); the first step's say is unused
  chain(name, steps):: {
    name: name,
    bones: [{ at: s[0], role: s[1] } for s in steps],
    joints: [{ from: steps[i][0], to: steps[i + 1][0], say: steps[i + 1][2] } for i in std.range(0, std.length(steps) - 2)],
  },

  // a one-file program (a utility, a tiny program): its Cap.main and its
  // main in [file], then its core ([anchor, role, say] each, the first
  // called by main). Extend with bones+: and joints+: for a loop.
  onefile(name, file, core, main='def:main')::
    self.chain(name, [
      [file + ':code:"Cap.main"', 'the program: Cap.main, the capabilities', ''],
      [file + ':' + main, 'the command line: flags, arguments', 'the capabilities'],
    ] + core),

  // a module's own chain, its anchors in the file: [name, role, say]
  // each, a bare definition name (def:) in [file]
  module(file, name, steps)::
    self.chain(name, [[file + ':def:' + s[0], s[1], s[2]] for s in steps]),

  // a star: [center] calls each of [callees] ([anchor, role, say] each),
  // for a main calling ten initializations, a dispatcher its commands
  calls(name, center, center_role, callees):: {
    name: name,
    bones: [{ at: center, role: center_role }] + [{ at: c[0], role: c[1] } for c in callees],
    joints: [{ from: center, to: c[0], say: c[2] } for c in callees],
  },

  // a module's star: [center] (a bare name) calls each of [callees]
  // ([name, role, say] each), all defined in [file]
  module_calls(file, name, center, center_role, callees)::
    self.calls(name, file + ':def:' + center, center_role,
               [[file + ':def:' + c[0], c[1], c[2]] for c in callees]),

  // a loop dispatching events (a window's thread over Event.select, a
  // kernel's trap handler): the loop, then a bone per case, each an
  // [anchor, role, say] (a case is code: `code:"| Key"` reaches it); the
  // cases go back to the loop
  select(name, loop, loop_role, cases):: {
    name: name,
    bones: [{ at: loop, role: loop_role }] + [{ at: c[0], role: c[1] } for c in cases],
    joints: [{ from: loop, to: c[0], say: c[2] } for c in cases]
            + [{ from: c[0], to: loop, say: 'again' } for c in cases],
  },

  // a tiny program (tiny/): started by TinyLibSystem.main on the host or
  // on tiny-kernel, not Cap.main; its core as in onefile (written as a
  // local in tiny/'s config by the 2026-11-04 pass, lifted here)
  prog(name, file, core)::
    self.chain(name, [
      [file + ':code:"TinyLibSystem.main"', 'the program: TinyLibSystem.main, the host or tiny-kernel', ''],
      [file + ':def:main', 'the command line: -h, flags, files', 'the capabilities'],
    ] + core),

  // a lib_playground program (games/, examples/, apps/ on Playground):
  // Model-View-Update down to its `let () = Cap.main` (no def:main), and
  // its heart reached from [from] (view or update); written as a local
  // in five configs by the 2026-11-04 pass, lifted here
  mvu(file, heart, role, say, from='def:view'):: {
    local at(a) = file + ':' + a,
    name: 'Model-View-Update, and its heart: ' + std.split(heart, ':')[1],
    bones: [
      { at: at('type:model'), role: 'the state' },
      { at: at('def:initial_model'), role: 'the first state' },
      { at: at('def:update'), role: 'a frame: model -> model' },
      { at: at('def:view'), role: 'a picture: model -> shapes' },
      { at: at('def:app'), role: 'the app: the three given to game' },
      { at: at('code:"Cap.main"'), role: 'the program: the app run, with the capabilities' },
      { at: at(heart), role: role },
    ],
    joints: [
      { from: at('def:initial_model'), to: at('type:model') },
      { from: at('type:model'), to: at('def:update'), say: 'stepped' },
      { from: at('def:update'), to: at('type:model'), say: 'the next state' },
      { from: at('type:model'), to: at('def:view'), say: 'drawn' },
      { from: at('def:app'), to: at('def:update'), say: 'steps with' },
      { from: at('def:app'), to: at('def:view'), say: 'draws with' },
      { from: at('code:"Cap.main"'), to: at('def:app'), say: 'runs' },
      { from: at(from), to: at(heart), say: say },
    ],
  },

  // a directory's parts as whole units (a path each, no anchor): a
  // layered picture, [path, role] each, and joints [from, to, say]
  parts(name, bones, joints):: {
    name: name,
    bones: [{ at: b[0], role: b[1] } for b in bones],
    joints: [{ from: j[0], to: j[1], say: j[2] } for j in joints],
  },
}
