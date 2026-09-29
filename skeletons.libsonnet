// The skeletons ix's programs share, for the code map's configs
// (the code map: ~/github/ocaml-elm-playground's tinybox codemap, its
// docs/claude_notes/codemapconfig_guidelines.md): a function of the
// files, its bones' anchors defaulting to the usual names.
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
}
