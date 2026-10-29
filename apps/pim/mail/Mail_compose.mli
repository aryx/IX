(* Mail_compose: a message being written (plan_mail.md, stage 7): new,
   a reply, a reply to all, a forward; kept as a draft in the store
   while it is written; made the message SMTP sends.

   A reply, Gmail's and every mailer's since the 1980s:

       To: Carol <carol@ix>               <- Reply-To:, else From:
       Cc: bob@ix                         <- to all: To: and Cc: too,
       Subject: Re: the plan                 less me and the To:
       In-Reply-To: <2@ix>                <- what threads it: the
       References: <1@ix> <2@ix>             conversation's ids
                                             (Mail_thread, X-GM-THRID)
       (the cursor, an empty line)
       On Thu, 29 Oct 2026 11:00:00 +0100, Carol <carol@ix> wrote:
       > "Yes", à midi.                    <- the text quoted

   A forward: "Fwd: ", no thread, the message's headers then its text,
   its attachments sent again (taken from the cache when it is sent:
   the draft names the message, not its bytes).

   A draft is an item (Item, plan_pim.md's idea 1) stamped draft, its
   fields the message's own, so the file reads as the message:

       id: draft:1730193600.4
       stamp: draft
       to: Carol <carol@ix>
       subject: Re: the plan
       in-reply-to: <2@ix>
       references: <1@ix> <2@ix>

       See you there.

   The message sent has a Date: and a Message-ID: of the time it is
   sent, MIME-Version:, the text a text part (UTF-8, quoted-printable
   when it is not ASCII), the subject an encoded word when not ASCII;
   with attachments, a multipart/mixed. *)

type draft = {
  id : string; (* the item's id, draft:... *)
  to_ : string;
  cc : string;
  subject : string;
  in_reply_to : string; (* "" for none, as the three below *)
  references : string;
  forward : string; (* the cache's key of the message forwarded *)
  attach : string; (* files to attach, separated by spaces *)
  text : string;
}

(* [blank ~id]: a new message *)
val blank : id:string -> draft

(* [reply ~id ~all ~me headers text]: the reply to the message of
 * [headers] whose text to read is [text]; [me] the account, left out
 * of a reply to all *)
val reply : id:string -> all:bool -> me:string -> Mail.t -> string -> draft

(* [forward ~id ~key headers text]: [key] the message's in the cache *)
val forward : id:string -> key:string -> Mail.t -> string -> draft

(* a draft as an item and back *)
val to_item : draft -> Item.t
val of_item : Item.t -> draft

(* [message ~from ~date ~msgid ~files draft]: the message sent, From:
 * [from], [date] seconds since the epoch at [offset] minutes east,
 * [files] each attachment's name and bytes *)
val message :
  from:string -> date:float -> offset:int -> msgid:string ->
  files:(string * string) list -> draft -> Mail.t

(* a message's file to send, as the author wrote it: when its text is
 * not ASCII and it says nothing of its type, MIME's headers, the text
 * UTF-8 in quoted-printable (its Date: and Message-ID:, when it has
 * none, are the server's: Gmail adds them) *)
val complete : Mail.t -> Mail.t

(* "<1730193600.4.mini-pim@ix>": an id unique to this time and
 * counter, at the sender's domain *)
val new_msgid : from:string -> float -> int -> string
