(* Mail_thread: a mailbox's messages as conversations, by Jamie
   Zawinski's algorithm ("message threading", 1997, written for
   Netscape Mail 2.0 and published as an essay; RFC 5256 took it for
   IMAP's THREAD=REFERENCES).

   A reply says what it answers. In-Reply-To: names the one message,
   and References: names the whole chain back to the first (Mail.mli).
   So threading is building a tree from those links. But the links are
   in the messages you *have*, and they name messages you may not
   have:

       <1> the plan                    <1> (never received)
         <2> Re: the plan    --->      +-- <2> Re: the plan
           <3> Re: the plan              +-- <3> Re: the plan
         <4> Re: the plan              +-- <4> Re: the plan

   Here is the algorithm, in the essay's steps:

   1. There is a *container* for each Message-ID, found or made. It
      holds its message if we have it, and is empty if we only heard of
      it. The References of each message link the containers in a
      chain, from parent to child (a container keeps its first parent,
      and no link is made that would make a loop). The message's own
      container becomes the child of the last one.
   2. The containers with no parent are the roots.
   3. The empty containers are pruned. One with no children is
      removed; one with children is replaced by them, except at the top
      with several children, where the empty one stays to hold them
      together (a thread whose first message you never got).
   4. The roots are grouped by subject, for the mailers that sent no
      references at all: "Re: lunch" goes under "lunch" (the subject
      without its "Re:"s is [base_subject]).
   5. The brothers are sorted by date.

   The tests check worked examples. The playground's thread of five
   (the Our_mail of its TinyEudora) is one tree: <plan1> is at the top,
   <plan2> is under it, and under that are <plan3> (with <plan5> under
   it) and <plan4>. Two replies to a message never received hang from
   an empty container. "Re: lunch" with no references goes under
   "lunch". A message that names itself in its References makes no
   loop.

   References: Jamie Zawinski, "message threading",
   https://www.jwz.org/doc/threading.html (1997, 2002); RFC 5256,
   "Internet Message Access Protocol - SORT and THREAD Extensions"
   (2008), section 2.2, which is the same algorithm. *)

(* a thread: a message (None for one we never received, known only by
 * the replies that name it) and its replies *)
type 'a tree = Node of 'a option * 'a tree list

(* [threads ~id ~references ~subject ~date messages] is the
 * conversations, oldest first. [references] gives the ids that the
 * message names, oldest first: those of References:, then the one of
 * In-Reply-To: if it is not already there. *)
val threads :
  id:('a -> string option) -> references:('a -> string list) -> subject:('a -> string) -> date:('a -> float) -> 'a list -> 'a tree list

(* the subject without its "Re:", "RE:", "Re[2]:" and "Fwd:" prefixes,
 * trimmed, in lower case: what a reply and its original share *)
val base_subject : string -> string

(* does the subject say that it is a reply ("Re: ...")? *)
val is_reply : string -> bool

(* the trees flattened, depth first: each message with its depth *)
val flatten : 'a tree list -> ('a * int) list

(* the same for mail: the ids come from Message-ID:, References: and
 * In-Reply-To:, the subject is decoded, and the date is the
 * message's *)
val of_mail : ('a -> Mail.t) -> 'a list -> 'a tree list
