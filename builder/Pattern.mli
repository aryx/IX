(* Patterns: a rule's target, and the names it matches.
 *
 * In mk every rule's target is a pattern, and one type covers the four
 * kinds, so that a simple rule is just a rule whose pattern is literal:
 *
 *     pattern       name           binding                     kind
 *     hello         hello          Exact                       literal
 *     %.5           hello.5        Stem "hello"                % : any string
 *     %.5           dir/hello.5    Stem "dir/hello"
 *     &.5           dir/hello.5    no match                    & : no '/', no '.'
 *     (.+)\.5  :R:  hello.5        Groups [|"hello.5"; "hello"|]   regexp: \0 .. \8
 *
 * The prerequisites are then the rule's prerequisite patterns with the
 * stem put back ([subst]). For example, %.5: %.c matched on hello.5
 * wants hello.c, and so does (.+)\.5: \1.c. A pattern has at most one
 * % or & (the first is the pattern character; any later one is
 * literal), as in principia's match.c.
 *
 * % generalizes make's suffix rules (.c.o:, Feldman 1976), which could
 * only say "a file with this extension comes from the file with that
 * one". mk's % can go anywhere in a name: lib%.a, %/mkfile,
 * test-%:V:.
 *
 * The regexps are Plan 9's, with egrep's syntax (( ) | * + ? [ ] . ^
 * $). Regex compiles them and matches them against the whole name,
 * with libregexp's algorithm, as mk's own code does. A '.' matches a
 * UTF-8 character, and \1 to \8 are the groups.
 *
 * References: mk(1), on meta-rules; Stuart Feldman, "Make -- A Program
 * for Maintaining Computer Programs", 1979 (suffix rules); Andrew
 * Hume, "Mk: a Successor to Make" (USENIX, 1987), whose abstract
 * counts "pattern-matching metarules rather than suffix
 * transformation rules" among mk's advantages over make, and which
 * warns that the :R: kind is "significantly slower than %
 * metarules" -- here it costs a regexp match per candidate name; principia's
 * match.c; regexp(6) for the syntax. *)

(* a metarule's target *)
type meta =
  | Percent of string * string   (* A%B: prefix and suffix *)
  | Amp of string * string       (* A&B: the same, but the stem has no / or . *)
  | Regexp of string * Regex.t   (* :R:, with the source kept for printing *)

type t = Literal of string | Meta of meta

(* how a rule matched a name: a literal matches exactly, % and & match
 * by a stem, and a regexp by its groups *)
(* It is a variant and not an array of strings, so that no code can
 * read the stem of an exact match, which has none. *)
type binding = Exact | Stem of string | Groups of string array

(* [of_target ~regexp s] is Literal if [s] has no % or &, unless the
 * rule is :R:. Raises Regex.Error on a bad regexp. *)
val of_target : regexp:bool -> string -> t

val is_meta : t -> bool

(* [matches m name] says how the metarule's target [m] matches [name],
 * if it does. It is Stem for % and &, and Groups [|\0; \1; ...|] for a
 * regexp, where \0 is the whole match, as $stem0. For example,
 * matches (Percent ("", ".5")) "hello.5" = Some (Stem "hello"). *)
val matches : meta -> string -> binding option

(* [subst b s] is the prerequisite [s] with each % and & replaced by
 * the stem, or with \0..\8 replaced by the groups (\9, or a group that
 * did not match, by nothing). It is unchanged for an exact match. For
 * example, subst (Stem "hello") "%.c" = "hello.c".
 *)
val subst : binding -> string -> string
