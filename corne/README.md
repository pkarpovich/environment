# corne

A cheat sheet for the Corne v4.1 layout: all four layers at once, key colour is
the finger that owns it, live highlight of whatever you press.

The large glyph on a key is **what actually gets typed**, not what the keycap
says. The macOS "Universal" layout from [`../universal-layout/`](../universal-layout)
rearranges the symbols and the stock QMK firmware knows nothing about it. The
small caption underneath is the keycap legend, and it only shows up where the
two disagree.

## Running it

Zed -> task palette -> **corne: dev (page + key tap)**. The task lives in
[`../.zed/tasks.json`](../.zed/tasks.json) and calls `mise run dev`.

By hand, the same thing:

```fish
mise run install                  # once, page dependencies
mise run dev                      # page and daemon together
mise run web                      # page only
mise run tap                      # daemon only
```

`dev` is `mise run tap ::: web`: two processes in parallel, output prefixed with
`[tap]` and `[web]`. Ctrl+C takes both down, no separate cleanup needed. Node,
pnpm and rust versions are pinned in [`.mise.toml`](.mise.toml).

Served at **https://corne.localhost**, registered in
[`../dotfiles/Caddyfile`](../dotfiles/Caddyfile).

| host | port | what |
|---|---|---|
| `corne.localhost` | 50500 | the page (Vite) |
| `corne-keytap.localhost` | 50501 | key event stream (SSE) |

Vite's default port `5173` is not available here, `ask-agent.localhost` already
claimed it.

The proxy to the daemon declares `flush_interval -1`. Without it Caddy would
buffer the SSE stream and the highlight would arrive in bursts.

Without the daemon the highlight only works while the window has focus: a plain
browser window does not receive keys in the background.

## From another device

Open `http://<this-mac-ip>:50500` on an iPad or anything else on the same
network. Both the dev server and the daemon bind every interface, and the page
derives the stream address from its own origin, so nothing needs configuring per
device.

Caddy is deliberately not involved here. It exists for the `.localhost` names
and HTTPS on this Mac; putting it in front of a LAN client would only pin the
machine's IP into a config file that DHCP will invalidate.

Two things bite on the first attempt:

- **Little Snitch** asks about incoming connections to `keytap` and to `node`.
  Until both are allowed the page loads but the stream stays silent, because the
  page is served by one process and the stream by another. The built-in macOS
  firewall being off says nothing about this.
- The stream is **plain HTTP with no authentication**, so anyone on the same
  network can read every keystroke, passwords included. That is the accepted
  trade for opening it by IP. The daemon only runs while you run it; on an
  untrusted network, do not.

## Two modes

**Sheet** - all four layers at once, scrollable. Meant to be glanced at while
you type in another window.

**Live** - a single board filling the screen with no scrolling, adapting to
whatever you are holding. The choice is remembered in localStorage.

What the live board can actually see:

| holding | visible immediately | why |
|---|---|---|
| Shift | yes | a real modifier, it goes out over USB |
| Option | yes | same, and it opens the layout's Option layer |
| Lower / Raise | **no** | `MO(1)`/`MO(2)` never leave the keyboard |

QMK handles `MO()` internally: it keeps the layer to itself and sends the host
an already resolved keycode. While a layer key is merely held, nothing goes out
over USB, so there is nothing to react to. The layer is therefore inferred from
the first key pressed on it: `Digit1` only exists on Lower, `Minus` only on
Raise. Hence the `≈` in front of the layer name in the UI.

Shift is what separates Lower from Raise on the top row: `!` from Lower is
`Digit1` without Shift, while `1` from Raise is the same `Digit1` with Shift.

Reading the layer honestly would take custom firmware (`layer_state_set_user`
plus Raw HID). Deliberately not done: reflashing both halves for the sake of a
caption is not worth the risk while the keyboard is still being learned.

## keytap

`keytap/` is a small Rust daemon. It installs a listen-only `CGEventTap`,
translates macOS virtual keycodes into DOM names (`KeyA`, `Semicolon`, ...) and
serves the stream on `127.0.0.1:50501` as SSE. The page consumes it through
`EventSource` and, while the daemon is alive, ignores its own window events,
otherwise everything would arrive twice when the window is focused.

The page derives the stream address from its own origin: opened through
`corne.localhost` it talks to `corne-keytap.localhost`, opened on any other host
it talks to that same host on port 50501. That keeps both direct access and
other devices working without Caddy.

Each connection is greeted on its own thread. Doing the handshake inline in the
accept loop meant one client that connected and then went quiet - a sleeping
iPad, a half-open Wi-Fi socket - wedged the listener and no one else could
connect. Reads during the handshake time out after 5s and writes to a client
after 2s, so a dead peer drops out instead of stalling the broadcast.

The first run hits **Input Monitoring**: the daemon raises the system prompt and
exits. Then System Settings -> Privacy & Security -> Input Monitoring, enable
`keytap`, run it again. This is the same permission Karabiner already holds;
macOS grants nothing weaker for global capture.

`mise run tap` builds and then launches `keytap/target/release/keytap` directly
rather than going through `cargo run`: TCC keys the permission to the binary
path, and an intermediate cargo process confuses the record. If the checkbox
does not appear on its own, add that path with the "+" button.

The daemon writes nothing to disk and makes no network calls: it listens on
loopback only, the connection drops when the page closes, and capture disappears
with the process. It is started by hand on purpose - there is no permanently
running key tap here.

### Why SSE and not a message bus

A browser cannot speak to NATS directly. That needs either a websocket listener
on the broker plus `nats.ws`, or a bridge. There is no local broker here, and
routing keystrokes through the homelab would mean everything typed - passwords
in any window included - leaves the machine, buying a network round trip for
something that has to render instantly. For one producer and one consumer on the
same machine, SSE is that same bus one hop long, and the browser understands it
with no library and with reconnection built in.

If the stream is ever needed elsewhere, the daemon gains a NATS publisher and
the page stays as it is.

## Where the data comes from

- geometry and layers: `keyboards/crkbd` from QMK, the stock `default` keymap,
  `LAYOUT_split_3x6_3_ex2` (46 keys: the 42-key board plus an inner column of
  two modifiers per half), column coordinates, key heights and the 1.5u thumbs
  out of `info.json`. Thumb rotation is not in that data and was matched to the
  physical board by eye.
- what gets typed: parsed from `../universal-layout/Universal.bundle`, both the
  EN and RU layouts, base, Shift and Option maps
- the EN/RU switch in the UI follows the first character you type

## Theme

Light and dark follow the OS through `light-dark()`; there is no toggle.

Keycap colours are deliberately outside that: they stand for physical caps, so
they and the text printed on them keep fixed values in both themes. Only the
page around the board flips. That is why the key text reads from `--key-ink`
rather than `--ink` - inheriting the theme ink would have put light glyphs on
light keycaps as soon as the page went dark.
