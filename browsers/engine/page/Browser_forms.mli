(* Browser_forms: what a person does to a page's form, and what it
 * makes the browser do.
 *
 *   a click on
 *     a text field, a password, a textarea  -> it takes the keys
 *     a checkbox                            -> it turns on or off
 *     a radio button                        -> it is on, and no other of
 *                                              its name in its form is
 *     a select                              -> it shows its next option
 *                                              (Motif popped a menu)
 *     a submit button                       -> its form is sent, with the
 *                                              button named in it
 *     a reset button                        -> its form is as the page
 *                                              gave it
 *   a key in a field
 *     Backspace, Return (its form is sent; a new line in a textarea),
 *     Escape (the keys are given up)
 *
 * A submission is a request. The form's fields (Forms.submission) are
 * encoded (Urlencoded) and sent to its action, resolved against the
 * page: a GET sends them as the URL's query, and a POST as the body.
 * The values are the page's (Browser_page.values) and are kept with
 * it, so that the history gives a half-filled form back half filled. *)

(* what a click or a key does to a form (it is called outcome, not
 * effect, because effect is a keyword since OCaml 5.3) *)
type outcome =
  | Nothing
  | Focus of Dom.element (* the field takes the keys *)
  | Unfocus (* it gives them up *)
  | Changed of Browser_page.t (* a value changed: the page with the new value *)
  | Submit of { url : string; post : (string * string) option; page : Browser_page.t }
      (* go there (with a POST's content type and body); the page is left
       * as it is *)

(* the request a submission makes: the URL, and a POST's content type and
 * body *)
val submission : Browser_page.t -> Forms.form -> submitter:Dom.element option -> string * (string * string) option

(* a click on a control *)
val click : Browser_page.t -> Dom.element -> outcome

(* a key (its name lowercased: "backspace", "enter"...) while a field
 * has the keys *)
val key : Browser_page.t -> Dom.element -> string -> outcome

(* text typed while a field has the keys: the page with the text
 * added *)
val typed : Browser_page.t -> Dom.element -> string -> Browser_page.t
