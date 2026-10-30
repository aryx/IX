(* Money_window: the suite's money (plan_pim.md, stage 6), Quicken's
   face over the books (Books: double entry, ledger's):

       Pim   Register   Account
       Checking                                    balance 1,395.43
      +-----------+---------------------------------------------------+
      |#Checking##| Date       Num  Payee    Category  Payment Deposit|
      | Savings   | 2026-10-01      Acme     Salary           2,000.00|
      | Categories| 2026-10-05 101  EDF      Utilities  62.40       * |
      |           | 2026-10-12      savings  [Assets:Savings] 500.00  |
      |           | [date] [num] [payee  ] [category ] [pay] [dep] Record
      +-----------+---------------------------------------------------+

   The register of an account (Quicken's, 1984: the checkbook people
   already kept), each line's balance after it, a payment negative. n
   writes a line in the columns at the foot, QuickFill copying a payee's
   last line when it is typed; Enter or Record keeps it (Books.of_txn:
   its amount posted to the account, the opposite to its category's
   account); c marks it cleared. r reconciles: the statement's ending
   balance typed, the lines it lists ticked (space or c), the
   difference shown with what explains it (Reconcile.hints: a line not
   ticked, one ticked too many, a wrong sign, two digits swapped, a
   multiple of 9), f finishing when it is zero, the ticked lines
   reconciled (R). Tab goes to the next account, then to the month's
   categories (Books.report: what came in and went out, by account).

   Not yet: envelopes (YNAB's budget), a split line written in the
   window, the bank's CSV and OFX files (a QIF one: the terminal's
   import), a repeating bill's next one. *)

type caps = Mail_window.caps

type model

(* today= the tests' day, else the clock's; the register of
 * Assets:Checking *)
val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the line [id] selected in its account's register *)
val show : caps -> model -> string -> model

val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
