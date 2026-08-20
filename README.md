# Notification Sounds

Ocean sounds for your notifications—in the Omarchy shell.

Omarchy Notification Sounds voices every desktop notification with the KDE **Ocean** sound theme, following the freedesktop notification spec. Each category gets the sound the spec intends—email chimes, instant-message pings, call rings, device clicks, transfer jingles—and senders can pick their own sound or ask for silence. Everything stays quiet while **Do Not Disturb** is on.

Sounds ship inside the plugin, so there is nothing else to install.

## Why you will love it

- **Lightweight by design.** A ~3 MB folder of Ocean sounds and one tiny QML service—no browser, no Electron.
- **Made for Omarchy.** A speaker glyph sits at the far right of your bar, and a toggle lives under Trigger → Notification Sounds in the launcher menu.
- **Respects your focus.** Notifications you silence with Do Not Disturb stay silent, system-wide.
- **Speaks your apps' language.** Senders use standard `category` and `sound-name` hints; the plugin does the rest.
- **Optional USB alerts.** Plug in a drive for a *device-added* chime, unplug for *device-removed*.

## Every category has a sound

| Category | Sound |
|----------|-------|
| `device` | `device-added.oga` |
| `device.removed` | `device-removed.oga` |
| `email` / `email.bounced` | `message-new-email.oga` / `dialog-error.oga` |
| `im` | `message-new-instant.oga` |
| `network` / `network.disconnected` | `bell.oga` |
| `presence` | `message-contact-in.oga` |
| `transfer` / `transfer.failed` | `completion-success.oga` / `completion-fail.oga` |
| `call` / `call.unanswered` | `phone-incoming-call.oga` / `dialog-error.oga` |
| any `*error` | `dialog-error.oga` |

Any notification that does not fit a category falls back to the urgency sound: `dialog-information`, `message-highlight`, or `dialog-error-critical`.

Senders stay in control: a `sound-name` hint is honored if the theme has the file, and `suppress-sound: true` keeps things silent no matter what.

## Sounds are bundled

The full Ocean sound set lives in the plugin's `sounds/` folder—no system package needed. If you prefer to follow your system theme instead, install it with `omarchy pkg add ocean-sound-theme` and delete the `sounds/` folder; the plugin then falls back to `/usr/share/sounds/ocean/stereo`.

## Install

```bash
git clone https://github.com/fab679/virtuoso.notification-sounds.git
cd virtuoso.notification-sounds && ./install.sh
```

That one command copies the plugin into `~/.config/omarchy/plugins/`, enables it in `shell.json`, puts the speaker glyph at the far right of your bar, adds the launcher-menu toggle, installs the USB alert service, validates, and restarts the shell. It is idempotent—safe to re-run whenever you pull a new version.

Requires Omarchy and PipeWire/PulseAudio with `pw-play` (`pipewire-utils`):

```bash
omarchy pkg add pipewire-utils
```

Prefer the official path?

```bash
omarchy plugin add https://github.com/fab679/virtuoso.notification-sounds.git --enable
```

then run `~/.config/omarchy/plugins/virtuoso.notification-sounds/install.sh` once to place the bar widget, menu toggle, and USB alerts. Skip USB alerts with `./install.sh --no-usb`.

## Toggle

- **Bar widget** (speaker glyph, far right): click to mute or unmute.
- **Menu**: Trigger → Notification Sounds (shows ✓ when on).
- **Terminal**: `omarchy-shell virtuoso.notification-sounds toggle`

The state persists in `~/.local/state/omarchy/notification-sounds.json`.

## Remove

While the plugin is still installed:

```bash
~/.config/omarchy/plugins/virtuoso.notification-sounds/uninstall.sh
```

That removes the plugin folder, its `shell.json` entries, the launcher-menu toggle, and the USB alert service (`~/.local/bin/omarchy-device-alert` and the `omarchy-device-alert.service` user unit), then restarts the shell.

## Credits

Sound effects are from the KDE Ocean theme (CC BY-SA 4.0); the `.license` files ship alongside them in `sounds/`. Playback uses `pw-play`.

Omarchy Notification Sounds is an independent project and is not affiliated with KDE. Ocean is a trademark of KDE e.V.

Licensed under the MIT License.