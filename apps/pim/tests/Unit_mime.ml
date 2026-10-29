(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/tests/Unit_mime.ml *)

(* See Unit_mime.mli *)

let str = Alcotest.(check string)

let multipart =
  "Content-Type: multipart/mixed; boundary=\"xyz\"\n\
   \n\
   This is a multi-part message in MIME format.\n\
   --xyz\n\
   \n\
   Here are the photos.\n\
   --xyz\n\
   Content-Type: image/png\n\
   Content-Transfer-Encoding: base64\n\
   Content-Disposition: attachment; filename=\"picture.png\"\n\
   \n\
   iVBORw0K\n\
   GgoAAAA=\n\
   --xyz--\n\
   the epilogue\n"

let digest =
  "Content-Type: multipart/digest; boundary=\"d\"\n\
   \n\
   --d\n\
   \n\
   From: Carol <carol@tiny>\n\
   Subject: first\n\
   \n\
   one\n\
   --d--\n"

let tests =
  Testo.categorize "Mime"
    [
      Testo.create "quoted-printable, the worked example" (fun () ->
          str "decoded" "café au lait, and a line too long to be sent as it is, so cut here"
            (Mime.quoted_printable_decode "caf=C3=A9 au lait, and a line too long to be sent as it is, so=\n cut here");
          let long = String.make 100 'a' ^ " é \n" in
          let e = Mime.quoted_printable_encode long in
          Alcotest.(check bool) "lines of 76 at most" true (List.for_all (fun l -> String.length l <= 76) (String.split_on_char '\n' e));
          str "and back" long (Mime.quoted_printable_decode e));
      Testo.create "encoded words, Q and B" (fun () ->
          str "Q" "café" (Mime.decode_words "=?utf-8?Q?caf=C3=A9?=");
          str "B" "café" (Mime.decode_words "=?utf-8?B?Y2Fmw6k=?=");
          str "latin-1" "café" (Mime.decode_words "=?iso-8859-1?Q?caf=E9?=");
          str "between two, no space" "le café" (Mime.decode_words "=?utf-8?Q?le_?= =?utf-8?Q?caf=C3=A9?=");
          str "plain words kept" "Re: le café ici" (Mime.decode_words "Re: =?utf-8?Q?le_caf=C3=A9?= ici");
          str "there and back" "le café" (Mime.decode_words (Mime.encode_words "le café")));
      Testo.create "parameters" (fun () ->
          let t, ps = Mime.parameters "Multipart/Mixed; Boundary=\"x;y\"; charset=utf-8" in
          str "type" "multipart/mixed" t;
          Alcotest.(check (list (pair string string))) "params" [ ("boundary", "x;y"); ("charset", "utf-8") ] ps);
      Testo.create "a multipart: the text and a picture" (fun () ->
          let m = Mail.parse multipart in
          Alcotest.(check int) "two parts" 2 (List.length (Mime.parts m));
          str "the text" "Here are the photos." (Mime.text m);
          match Mime.attachments m with
          | [ a ] ->
              str "image/png" "image/png" a.mime;
              Alcotest.(check (option string)) "its name" (Some "picture.png") a.filename;
              str "its bytes" "\137PNG\r\n\026\n\000\000\000" a.data
          | l -> Alcotest.failf "%d attachments" (List.length l));
      Testo.create "a digest: its parts are messages" (fun () ->
          let m = Mail.parse digest in
          str "introduced" "----- From: Carol <carol@tiny>\n----- Subject: first\n\none" (Mime.text m);
          Alcotest.(check int) "nothing to save" 0 (List.length (Mime.attachments m)));
      Testo.create "written, then read back: a text and an attachment" (fun () ->
          let bytes = String.init 200 Char.chr in
          let headers, body = Mime.multipart ~boundary:"=_b" [ Mime.text_part "un café"; Mime.attachment ~filename:"a.png" bytes ] in
          let m = Mail.make (("Subject", "x") :: headers) body in
          let m = Mail.parse (Mail.to_string m) in
          str "the text" "un café" (Mime.text m);
          (match Mime.attachments m with
          | [ a ] ->
              str "its type" "image/png" a.mime;
              str "its bytes" bytes a.data
          | l -> Alcotest.failf "%d attachments" (List.length l));
          Alcotest.(check bool) "7-bit lines of 76 at most" true
            (List.for_all (fun l -> String.length l <= 76 && String.for_all (fun c -> Char.code c < 128) l) (String.split_on_char '\n' body)));
      (* ix's: Windows-1252 and ISO-8859-15, not read as Latin-1 *)
      Testo.create "charsets: Windows-1252's quotes, the euro" (fun () ->
          str "the mli's example" "“café”" (Mime.to_utf8 "windows-1252" "\x93caf\xe9\x94");
          str "Latin-1 read as Windows'" "l’été" (Mime.to_utf8 "ISO-8859-1" "l\x92\xe9t\xe9");
          str "a hole kept" "\xc2\x81" (Mime.to_utf8 "windows-1252" "\x81");
          str "Latin-9's euro" "5 €" (Mime.to_utf8 "iso-8859-15" "5 \xa4");
          str "Latin-1's ¤ there" "5 ¤" (Mime.to_utf8 "iso-8859-1" "5 \xa4");
          str "not known: as it is" "\xe9" (Mime.to_utf8 "x-unknown" "\xe9"));
          (* ix's: real mail's, HTML only (Mail_text) *)
      Testo.create "HTML only: made text, its links listed" (fun () ->
          let m =
            Mail.parse
              "Content-Type: multipart/alternative; boundary=\"a\"\n\n\
               --a\nContent-Type: text/plain\n\n \n\
               --a\nContent-Type: text/html; charset=windows-1252\n\n\
               <html><head><style>p {}</style></head><body>\
               <h1>Shipped</h1><p>Your order, \x93a caf\xe9\x94. \
               <a href=\"https://shop/42\">Track it</a>.</p></body></html>\n\
               --a--\n"
          in
          str "the HTML's text" "Shipped\n\nYour order, “a café”. Track it[1].\n\n[1] https://shop/42"
            (String.concat "\n" (List.map String.trim (String.split_on_char '\n' (Mail_text.text m)))));
      Testo.create "a plain part that says something is read" (fun () ->
          let m = Mail.parse multipart in
          str "the text, the picture said" "Here are the photos.\n\n[attached: picture.png, image/png, 11 bytes]"
            (Mail_text.text m));
]
