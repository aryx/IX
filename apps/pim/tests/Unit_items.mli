(* Items, Item, Mail_item: the store's worked example (an item saved,
 * found, saved over, a plain file; the cache), and a message's item
 * updated by the server with what a person added kept *)
type caps = < Cap.env ; Cap.open_in ; Cap.open_out ; Cap.readdir >

val tests : caps -> Testo.t list
