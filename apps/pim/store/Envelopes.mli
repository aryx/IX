(* Envelopes: YNAB's "give every dollar a job" (You Need A Budget,
   Jesse Mecham, 2004; plan_pim.md's Money): the money there is assigned
   to envelopes before it is spent, each spending taken from one, so a
   budget is what one has, not a forecast. The envelopes of a
   household's kitchen drawer, on a screen.

       To assign: 1,037.60          <- the cash less what is in envelopes
       Groceries    400.00   42.17   357.83     assigned, spent,
       Rent         900.00  900.00     0.00     available (the next
       Utilities     50.00   62.40   -12.40     month's too: kept)

   In double entry an envelope costs little: it is an expense account
   (Expenses:Groceries), its spending what the books already post to
   it, and an assignment an item of its own:

       id: budget:1761900000.1
       stamp: budget
       envelope: Expenses:Groceries
       amount: 400.00
       date: 2026-11-01

   What is left in an envelope stays in it, month after month (YNAB's
   rule, unlike a monthly budget); one overspent is red, and what is to
   assign is the cash (the Assets: accounts) less what the envelopes
   hold. Moving money between envelopes is two assignments, one
   negative. *)

type envelope = {
  account : string; (* Expenses:Groceries *)
  assigned : Money.cents;
  spent : Money.cents;
  available : Money.cents;
}

(* the envelopes with money assigned, by name *)
val envelopes : Item.t list -> envelope list

(* the cash less what the envelopes hold: every dollar has a job when
 * it is 0 *)
val to_assign : Item.t list -> Money.cents

(* [assign ~id today envelope amount]: an assignment, "Groceries" an
 * expense's account (Books.account_of) *)
val assign : id:string -> Civil.date -> string -> Money.cents -> Item.t
