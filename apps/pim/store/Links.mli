(* Links: links both ways (plan_pim.md, idea 2). An item names another
   by its id in a field's value, in words a person can read and grep:

       id: task:answer-alice
       stamp: task
       re: mail:1784                   <- a link: mail:1784 is an item
       with: contact:alice             <- another

   and the store knows the reverse, so every item has its page of what
   refers to it: alice's lists the task, and the mail with her. As
   Sheet keeps "read by" beside "reads" (apps/office/sheet).

   The reverse is computed when asked, over the items, not kept in a
   file of its own: nothing to keep in step when ed or mini-git
   changes an item, and the store is a person's, thousands of items,
   read in a moment. A word is a link when an item has that id; a
   message's From: is not one (an address, not an id) until People
   makes it one (plan_pim.md, stage 4). *)

(* [links items item]: the items [item] names, with the field naming
 * each, in the fields' order *)
val links : Item.t list -> Item.t -> (string * Item.t) list

(* [backlinks items item]: the items naming [item], with their field *)
val backlinks : Item.t list -> Item.t -> (string * Item.t) list
