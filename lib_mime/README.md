# lib_mime: what a file is, which program takes it

`File_kind` (a file's content type, by its first bytes, then its name)
and `Helpers` (from a content type or a site to a program: `~/.mailcap`,
RFC 1524, and the built-in rules). What mini-netscape does not show and
what mini-files and mini-open are given go the same way. The plan:
[`plan_files.md`](../docs/plans/plan_files.md).

`File_kind`'s magic numbers are the author's playground's
`apps/media/Media.ml` (its `by_bytes`, `by_name`); not the rest of that
module, which decodes the file.
