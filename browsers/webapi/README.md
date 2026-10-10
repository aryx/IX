# browsers/webapi: scripts in a page

The author's mini-chrome's `src/webapi` (`~/github/mini-chrome`, its
`8af888e`), in its four directories, for
[`plan_browser.md`](../../docs/plans/plan_browser.md)'s stage 9: what
a page's scripts see of the page and of the browser. 16 modules, 3,732
lines of `.ml` here (2,715 there but the two not taken), and 1,073 of
JavaScript in a string. Over `browsers/javascript` (the engine),
`browsers/html` (`Dom`, `Html_tree`) and `browsers/css` (the
selectors).

    page's Dom  --thaw-->  nodes  <--  scripts (through the host objects)
                             |
      layout  <--  Dom  <--freeze (when changed)

| directory | modules | what |
|---|---|---|
| `dom/` | `Script_dom`, `Script_host`, `Script_element`, `Script_document`, `Script_events`; `Shadow_tree` | the page's tree as a script changes it (a mutable copy, frozen back into a `Dom.element` to lay out); an element's, the document's and an event's host objects; a shadow tree (mini-chrome's `libs/dom`) |
| `window/` | `Script_window`, `Script_url`, `LocalStorage` | `window`, `location`, `navigator`, `history`; `URL`; `localStorage` (as long as the page) |
| `net/` | `Script_fetch`, `XMLHttpRequest`, `Cors` | a request a script makes, queued for the browser and answered later; the same-origin policy |
| `run/` | `Browser_script`, `Event_loop`, `Script_modules`; `Script_prelude` | a page's scripts run in order, its modules, an event dispatched (bubbling), the timers on the page's clock; `Script_prelude`: mini-chrome's `data/prelude/web/*.js` (12 files) in a string |
| | `Script_types.mli` | the types they share: a node, a request, the page's state |

Who uses it: `browsers/netscape/Tab` (`Browser_script.create_with`,
`run_scripts_with`, `click`, `input`, `advance`, `take_requests` and
`answer`, `take_navigation`, `tree`).

`tests/`: mini-chrome's `Unit_browser_script`, `Unit_script_dom`,
`Unit_script_modules`, `Unit_xhr` and `Unit_cors` (67, Testo, dune's
only).

## What changed

For mini-ml, and for ix's capabilities:

- **No optional argument**: `Browser_script.create_with options` (a
  record: seed, log, base, epoch, viewport, cookies) and `create`;
  `run_scripts_with source` and `run_scripts`; `click` and `click_at`;
  `window_event` and `window_event_at`; `Script_dom.make` and
  `make_with text attributes`; the others said (`Script_events.make
  ~bubbles`, `Event_loop.add ~frame`, `Script_fetch.ask ~cors ~headers
  ~ahead`, `escape ~quote`, `dispatch_event ~nested`).
- **No `lazy`**: the prelude, and `Script_dom.select`'s elements, kept
  by hand.
- **The page's scripts reach no system**: the debugging switches are
  values a host sets (`Script_host.says_missing`, `events_said`,
  `Browser_script.page_budget`), where they were the logs' level and
  the environment's `JS_MISSING`, `JS_EVENTS`, `JS_BUDGET`; what they
  say goes to `Js_value.say`.
- **Left out**: `WebSocket` (97 lines) and `AudioContext` (35), which
  the plan does not take, with `Script_types`' sockets; `Stopwatch`.
- `browsers/html` gained what these ask of mini-chrome's later HTML:
  `Dom.comment_name` and `Dom.hash`, and `Html_tree.parse_with
  ~comments` (a comment kept as an element, for a script that reads
  them).

## Remains

- Nothing was cut inside the files (shadow trees, frames, modules,
  `Cors`: the plan's "never run" list).
- A request's answer has only its `Content-Type` of the server's
  headers (`Tab` gives it); no cookie jar (`document.cookie` is "").
- Not linked by mini-mk (mini-netscape is not yet): compiled by
  mini-ml, run by OCaml's build only.
