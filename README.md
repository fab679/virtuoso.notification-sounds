# Notification Sounds

An [Omarchy](https://omarchy.org/) plugin that voices desktop notifications with
sounds from the KDE **Ocean** sound theme, following the freedesktop
notification spec. Includes a bar widget and a launcher-menu toggle.

- Plays a sound for every notification popup
- Category-aware: `email`, `im`, `device`, `network`, `presence`, `transfer`,
  `call` map to distinct Ocean sounds (plus urgency fallback)
- Honors sender hints: `sound-name` and `suppress-sound`
- Respects **Do Not Disturb** — silenced notifications stay silent (system-wide)
- Toggle from the bar widget or `Trigger → Toggle → Notification Sounds`

## Requirements

- Omarchy (Quickshell-based shell)
- `ocean-sound-theme` (KDE Ocean sounds, optional — see `soundDir`)
- PipeWire/PulseAudio with `pw-play` (`pipewire-utils`)

## Install

```bash
git clone https://github.com/<you>/virtuoso.notification-sounds
mkdir -p ~/.config/omarchy/plugins
cp -r virtuoso.notification-sounds ~/.config/omarchy/plugins/virtuoso.notification-sounds
```

Add to `~/.config/omarchy/shell.json`:

```jsonc
{
  "plugins": [
    { "id": "virtuoso.notification-sounds" }
  ],
  "bar": {
    "layout": {
      "right": [
        // ... your other widgets
        { "id": "virtuoso.notification-sounds" }   // far-right speaker toggle
      ]
    }
  }
}
```

Restart the shell: `omarchy restart shell`

## Usage

- **Bar widget** (speaker glyph, far right): click to mute/unmute.
- **Menu**: `Trigger → Toggle → Notification Sounds` (shows ✓ when on).
- **Terminal/IPC**:

  ```bash
  omarchy-shell virtuoso.notification-sounds isEnabled   # on | off
  omarchy-shell virtuoso.notification-sounds toggle      # toggle + persist
  omarchy-shell virtuoso.notification-sounds setEnabled true
  ```

State persists in `~/.local/state/omarchy/notification-sounds.json`.

## Configuration

All tuning lives at the top of `Service.qml`:

| Property | Default | Meaning |
|----------|---------|---------|
| `soundDir` | `/usr/share/sounds/ocean/stereo` | Sound theme directory |
| `categoryRules` | — | `[category-pattern, file]` map, most specific first |
| `knownSoundNames` | — | Valid `sound-name` hint values (theme files) |
| `lowSound` / `normalSound` / `criticalSound` | Ocean files | Urgency fallbacks |

Sound resolution order: `sound-name` hint → `category` hint → urgency.

## Categories

| Category | Sound |
|----------|-------|
| `device` | `device-added.oga` |
| `device.removed` | `device-removed.oga` |
| `email` | `message-new-email.oga` |
| `im` | `message-new-instant.oga` |
| `network` | `bell.oga` |
| `presence` | `message-contact-in.oga` |
| `transfer` | `completion-success.oga` |
| `call` | `phone-incoming-call.oga` |
| any `*error` | `dialog-error.oga` |

## License

MIT