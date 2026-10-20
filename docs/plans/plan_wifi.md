# Plan: WiFi, the protocol in OCaml and a radio simple enough to teach it (`lib_networking/wifi/`, `tiny/`, `raspberry/`, `kernels/9pi/network/`)

The author (2026-10-20), after asking whether mini-9pi, principia, Plan 9
or 9front had a driver for a Realtek USB dongle: "I have a Pi4. Does it
support Wifi?"; then "would be good because of the teaching context of
principia, m-ix (and t-ix), to explain how wifi works, but ideally the
code for it would not be too complicated, with a not too complicated
device"; then "yes, write the plan in docs/plans/"; then "it makes sense to not
support those realtek and focus on the Pi4 wifi embedded device if we
want to showcase wifi in IX".

Status: a plan, nothing written. The numbers of lines below are
estimates, not measures. **Decided: the target is the Pi 4's own chip,
the CYW43455 (section 5); no USB dongle.** The emulators come after it,
as a model of that chip (section 4).

## 1. Where things are today

- **Nobody has WiFi.** mini-9pi's only network driver is `Etherusb.ml`
  (QEMU's CDC Ethernet, SMSC's LAN95xx), on the DWC USB of the Pi 1/2/3.
  On the Pi 4 mini-9pi has no network at all: no GENET (its Ethernet),
  no PCIe and xHCI (its USB-A ports, behind a VL805), no SDIO.
  principia's `kernel/buses/user/usb/ether/` is wired only (asix, cdc,
  smsc). Plan 9 had the WaveLAN of ISA and PCMCIA cards.
- **9front has WiFi** (from memory, no 9front tree on this machine):
  an 802.11 layer in the kernel (`wifi.c`), the handshake in a user
  program (`aux/wpa`), drivers for Intel's and Ralink's PCI cards, and
  `ether4330` for the Broadcom chip of the Pi 3, the Pi Zero W and
  (I believe) the Pi 4, from Richard Miller's Plan 9 Pi kernel. These
  are the C references, as principia is elsewhere.
- **The crypto is mostly there.** `lib_crypto` has `Aes`, `Hmac`, `Sha1`
  (and TinyLibCore a `Sha1`). Missing: PBKDF2, 802.11's PRF, AES key
  wrap (RFC 3394), CCM.
- **The emulators have a wire each.** tiny-machine's four words at
  `-48(r0)` with `-net`, `-net-out`, `-net-pcap`; mini-qemu's
  `raspberry/usb/Usernet.ml`, a user network behind a USB adapter.

## 2. The idea: two layers, and the device that hides neither

```
    a program: ip, curl, netscape            (unchanged: frames of Ethernet)
        |
    the 802.11 layer (lib_networking/wifi/)  <- what is taught
        |  scan: beacons and probes; join: authentication, association
        |  WPA2: the 4-way handshake (EAPOL), then CCMP on each frame
        |  an Ethernet frame <-> an 802.11 data frame (LLC/SNAP header)
        |
    the radio: send a frame, receive a frame, set the channel
        |
    the air: an emulator's access point, or a real one
```

- **The protocol is the lesson, the chip is not.** 802.11 is frames
  with three (or four) addresses, management frames whose bodies are
  type-length-value elements, and a state machine; WPA2-Personal is a
  key derived from a password, a handshake of four messages, and AES
  on every frame. All of that is OCaml over strings, tested on the
  host against the standard's vectors and recorded handshakes, with
  no radio.
- **The device should be a SoftMAC radio with nothing else**: it sends
  and receives whole 802.11 frames on a channel, and the host does
  the rest. Real SoftMAC chips are that plus thousands of lines of
  undocumented register tables and radio calibration (Linux's
  `rtl8xxxu`, `mt7601u`, `ath9k_htc`); an emulated one is only that.
- **On real hardware, take the FullMAC chip the board already has.**
  The Pi 4's CYW43455 runs 802.11 in its firmware: the host says
  "scan", "join this SSID", and exchanges Ethernet frames. The
  handshake's EAPOL frames still come to the host as Ethernet frames
  (type 0x888e) when the firmware is not told the key, so the WPA2
  part of the layer is used on the board as on the emulator; scanning
  and joining are the firmware's.

## 3. The 802.11 layer (`lib_networking/wifi/`), about 800 lines

1. **Frames** (`Frame`): the header (frame control, duration, the
   addresses, sequence), the types used (beacon, probe request and
   response, authentication, association request and response,
   deauthentication, data, QoS data), the information elements (SSID,
   rates, channel, RSN). An Ethernet frame into a data frame and back
   (the LLC/SNAP header of 8 bytes). Printing a frame, for `-net-trace`
   and for the docs.
2. **The station** (`Station`): a state machine, scanning (listen to
   beacons, or send probes, channel after channel), then open
   authentication (two frames, a formality kept by WPA2), association,
   then the handshake. As a pure function, an event (a frame, a tick)
   to a state and frames to send, as `netcode`'s `Lockstep` is: the
   tests replay a session.
3. **WPA2-Personal** (`Wpa`):
   - PMK = PBKDF2-HMAC-SHA1(password, SSID, 4096, 32).
   - The handshake: the access point's nonce (ANonce), ours (SNonce),
     PTK = PRF-384(PMK, "Pairwise key expansion", the two addresses
     and the two nonces sorted), split into KCK (the MIC's key), KEK
     (the key that wraps), TK (the traffic's); message 3 carries the
     group key wrapped by AES key wrap under KEK; each message's MIC
     an HMAC-SHA1 under KCK.
   - CCMP: AES-CCM with TK, a packet number of 48 bits (replays
     refused), the header's fields in the MIC; for the data frames.
   - Not WPA3 (SAE needs elliptic curves over a prime field, `Ecdsa`'s
     neighbor, and is a later chapter), not TKIP, not WEP (WEP could
     be a page of history in the docs: RC4 and its known break).
4. **`lib_crypto`'s additions**, about 150 lines: `Pbkdf2`, `Aes_wrap`
   (RFC 3394, wrap and unwrap), `Ccm` (CTR and CBC-MAC over `Aes`), the
   PRF in `Wpa` itself. Their tests: RFC 6070 (PBKDF2), RFC 3394,
   RFC 3610 (CCM), and 802.11's annex J vectors (the PMK of a known
   SSID and password, a PTK, a CCMP frame).

## 4. The emulated radio and the access point

Second to the board (the author's choice, above). What follows was
written before it; to revisit once the board works. The likely change:
mini-qemu models the CYW43455 itself, its firmware's protocol of
section 5 (BCDC commands, SDPCM frames) on the Arasan EMMC, instead of
a USB radio of its own, so mini-9pi has one WiFi driver and it is
tested without the board (as `-ips` models a board's speed). Its
firmware model is then where 802.11's frames and the access point live.
t-ix's radio stays the simple one below, if t-ix gets WiFi at all.

### t-ix: tiny-machine's radio, about 150 lines in the machine

- **A radio is the wire with a channel.** Same four words (address,
  length, command, status) at a new place, a command more: set the
  channel. What the kernel sends is an 802.11 frame, what it takes is
  one. No rates, no power, no signal strength (or one number, for
  the scan's list).
- **The access point is the host's**, as `-net dir`'s peer is:
  `-wifi ssid:password` makes tiny-machine run an access point on
  channel 6 (beacons every 100 ms of the machine's time, its half of
  the handshake, CCMP) in front of the existing wire, so `-net-out`
  and `-net-forward` work through the air. `-wifi-trace` prints the
  frames decoded, `-net-pcap` saves them with a radiotap header so
  Wireshark shows them as 802.11. A wrong password is a handshake
  that fails at message 2's MIC: a test.
- **The kernel**: tiny-kernel's 802.11 in a file of its own
  (`TinyKernelWifi.ml`, `TinyLibCore`'s `Sha1`, an AES to write there
  or in TinyLib), under `TinyKernelNetwork.ml` where the wire's frames
  go now. A `tiny-wifi` command: `scan`, `join ssid password`.
  Times counted in instructions, so a session is the same each run
  and `make check` can keep one.

### m-ix: mini-qemu's USB radio, about 200 lines in `raspberry/usb/`

- **A USB device of mini-qemu's own** (`Usbwifi.ml`), on the DWC bus
  as `Usernet`'s adapter is: one bulk endpoint each way carrying
  802.11 frames, a control request for the channel, its own vendor
  and product numbers. The access point is mini-qemu's, in front of
  `Usernet` (`-wifi ssid:password`). The same OCaml as the layer
  (`lib_networking/wifi/`), linked by the emulator: the access point
  is the station's other half, and testing one tests the other.
- **mini-9pi**: `Etherwifi.ml` beside `Etherusb.ml`, the layer in the
  kernel or, as 9front, the handshake in a user program
  (`networking/Wpa.ml`) writing the keys to `/net/ether0/` (the
  author to choose: the kernel is simpler to read in one place, the
  user program is Plan 9's way and keeps AES and SHA out of the
  kernel). `/net/ether0/` keeps showing Ethernet frames, so `ip` and
  everything above it do not change.
- **QEMU has no WiFi device**, so this runs under mini-qemu only, not
  under QEMU: a first in m-ix, which runs under both. Said in the
  docs; the real board (section 5) is the second machine.
- **Two machines in the same air**, later: two mini-qemu sharing a
  UDP multicast socket as the air, one as the access point (hostapd's
  half, already written for the emulator) and one as a station.
  Tronscroll over WiFi.

## 5. The real board: the Pi 4's CYW43455, about 1,500 lines

In this order, each a step that can be seen to work:

1. **SDIO.** On a real Pi 4 the SD card is on EMMC2 and the WiFi chip
   on the older Arasan EMMC at 0xfe300000 (GPIO 34 to 39, alt3), the
   controller that `raspberry/boards/Pi4.ml` emulates for the card,
   as QEMU's raspi4b does. So mini-9pi's SD driver, given SDIO's
   commands 52 and 53, may be most of the host's half. To check first:
   does mini-9pi boot on a real Pi 4 today, and from which controller.
2. **The chip's firmware**: `brcmfmac43455-sdio.bin`, its NVRAM text
   and its CLM blob, from the Pi's firmware repository, uploaded into
   the chip's RAM over SDIO (the backplane window), then the chip's
   ARM core started. On the card's `/lib/firmware`, said by the
   origin notice.
3. **The firmware's protocol**: BCDC (a command, `ioctl` or `iovar`,
   and its answer) and SDPCM (the frames with a header of 12 bytes).
   `escan` for the scan, `join` for the network.
4. **WPA2 by the host**: the firmware told "WPA2-PSK, the supplicant
   is the host" (`sup_wpa` 0), the EAPOL frames go through the layer's
   `Wpa`, the keys given back to the firmware (`wsec_key`). CCMP is
   the chip's.

References: `ether4330.c` (Plan 9, 9front), Linux's `brcmfmac`, and
Cypress's datasheet for the SDIO side. No emulator has the chip:
like the SMSC driver of `plan_tronscroll_network.md`, it is the
author's to run first, on the board.

**Before step 1, maybe GENET**: the Pi 4's wired Ethernet, one
memory-mapped device and a few hundred lines, gives the Pi 4 a network
by itself and a way to fetch what the WiFi steps need.

## 6. Devices considered and not chosen

| Device | Why not |
|---|---|
| The author's Realtek dongles: RTL8188EUS (0bda:8179), RTL8188CU (0bda:8176) | SoftMAC: the host does 802.11, fine, but also the chip's MAC and radio by register tables and calibration (Linux's `rtl8xxxu`, several thousand lines, no documentation) |
| MediaTek MT7601U, Atheros AR9271 | The same in smaller (AR9271's firmware is open, the best documented of the three), still mostly tables |
| An ESP8266 or ESP32 on a UART, with its AT firmware | Simplest of all (`AT+CWJAP="ssid","pw"`), but the module is a modem: nothing of 802.11 is taught |
| A USB dongle on the Pi 4 | Its USB-A ports are behind PCIe and the VL805: an xHCI driver first |

## 7. The docs

- A chapter for each layer, with the frames drawn: a beacon, the
  four messages of the handshake with what each carries and which key
  checks it, a CCMP frame's bytes.
- Why the handshake is four messages, and what each proves (the
  password is never sent; both sides show they have the PMK by a MIC).
- Why the radio is so much simpler in the emulator than in a chip,
  and what the chip's thousands of lines do (calibration, power,
  rates): a page, not code.
- History: WaveLAN and Plan 9; WEP and its break; WPA and TKIP as a
  firmware upgrade; WPA2 and CCMP; WPA3 and SAE.

## 8. Order

1. `lib_crypto`'s `Pbkdf2`, `Aes_wrap` (and `Ccm` if the host ever
   encrypts; on the board CCMP is the chip's), with their RFC vectors.
2. `lib_networking/wifi/`'s `Wpa` against annex J, and the EAPOL
   frames of the handshake; tests on the host with a recorded one.
3. The Pi 4: GENET maybe, then the CYW43455's four steps (section 5);
   curl through the air on the board.
4. Later, the emulators (section 4): mini-qemu modeling the CYW43455,
   then maybe t-ix's radio.
