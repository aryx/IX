(* TinyBrowser's lines as plain text, one per line, for the tests to
 * compare (Host.ml on the host, Tm.ml on tiny-cpu): a run at its
 * column, a rule as dashes, a picture as [its alternative text, w x h]
 * on its first row. www itself never prints a page, so this is the
 * tests' and not the browser's (old: TinyBrowser.dump). *)

(* [dump page width]: the page's lines so far, [width] its columns *)
val dump : TinyBrowserPage.page -> int -> string
