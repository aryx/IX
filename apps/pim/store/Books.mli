(* Books: the money (plan_pim.md, stage 6), double entry under
   Quicken's register. A transaction is an item stamped money, its
   postings summing to zero, ledger's way (John Wiegley's ledger, 2003,
   plain text accounting):

       id: money:1730193600.1
       stamp: money
       date: 2026-10-30
       payee: EDF
       num: 101
       posting: Expenses:Utilities  62.40     <- an account, two spaces,
       posting: Assets:Checking                  an amount; one may be
       cleared: *                                left out: the rest's
                                                 opposite

   A category is an account: a payment's Groceries is
   Expenses:Groceries, a deposit's Salary Income:Salary, and a transfer
   is written [Assets:Savings], Quicken's brackets. So a register (an
   account's lines, each its posting's amount and the other account as
   its category, Ledger.txn) and a category report are the same books
   read two ways, and the books always balance.

   A bill is a task with postings (idea 1: stamped task money, due
   the 5th): it is in the books once done, on the day it was paid. *)

type posting = { account : string; amount : Money.cents }

(* the item's posting: lines, the one left out filled in *)
val postings : Item.t -> posting list

(* in the books: postings, and not a task still to do *)
val is_transaction : Item.t -> bool

(* the accounts the books name, by name *)
val accounts : Item.t list -> string list

(* an account's balance: its postings' sum *)
val balance : Item.t list -> string -> Money.cents

(* [register items account]: its transactions as a register's lines,
 * by date *)
val register : Item.t list -> string -> (Item.t * Ledger.txn) list

(* "Expenses:Groceries" -> "Groceries", "Assets:Savings" ->
 * "[Assets:Savings]"; and back, a payment's category an expense, a
 * deposit's an income *)
val category : string -> string
val account_of : amount:Money.cents -> string -> string

(* [of_txn ~id ~account txn]: a register's line as an item: its
 * amount posted to [account], the opposite to its category's *)
val of_txn : id:string -> account:string -> Ledger.txn -> Item.t

(* cleared: as the status says *)
val with_status : Ledger.status -> Item.t -> Item.t

(* [fresh register txns]: those not already there, the bank's file
 * matched to the register (the same amount, three days apart at
 * most) *)
val fresh : Ledger.txn list -> Ledger.txn list -> Ledger.txn list

(* the month's [Expenses:] and [Income:] sums by account, a
 * report's lines *)
val report : Item.t list -> year:int -> month:int -> (string * Money.cents) list
