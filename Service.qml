import QtQuick
import Quickshell
import Quickshell.Io

// Notification sound plugin for the Omarchy shell.
//
// Plays a sound from the Ocean theme whenever a new notification popup appears,
// following the freedesktop notification spec:
//   sound-name hint > category hint > urgency fallback.
// Notifications silenced by Do Not Disturb never reach the popup model, so no
// sound is played while DND is on. Enable/disable via the "plugins" array in
// ~/.config/omarchy/shell.json.

Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader). Declaring these
  // properties is what makes the loader inject them.
  property var shell: null
  property var manifest: null

  readonly property var notificationService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var popupModel: notificationService ? notificationService.popupModel : null

  // Bundled Ocean sounds ship inside the plugin folder (sounds/). The shell
  // stamps each plugin manifest with its own source directory, so this works
  // wherever the plugin is installed. Falls back to the system theme.
  property string soundDir: root.manifest && root.manifest.__sourceDir
    ? root.manifest.__sourceDir + "/sounds" : "/usr/share/sounds/ocean/stereo"

  // Freedesktop sound names that exist in the Ocean theme; a sender-provided
  // "sound-name" hint is only played if it resolves to one of these.
  property var knownSoundNames: [
    "alarm-clock-elapsed", "audio-volume-change", "battery-caution", "battery-full",
    "battery-low", "bell", "bell-window-system", "button-pressed-modifier",
    "button-pressed", "complete-media-burn", "complete-media-error", "completion-fail",
    "completion-partial", "completion-rotation", "completion-success", "desktop-login",
    "desktop-logout", "device-added", "device-removed", "dialog-error-critical",
    "dialog-error", "dialog-error-serious", "dialog-information", "dialog-question",
    "dialog-warning-auth", "dialog-warning", "game-over-loser", "game-over-winner",
    "media-insert-request", "message-attention", "message-contact-in",
    "message-contact-out", "message-highlight", "message-new-email",
    "message-new-instant", "message-sent-instant", "outcome-failure",
    "outcome-success", "phone-incoming-call", "power-plug", "power-unplug",
    "service-login", "service-logout", "theme-demo", "trash-empty"
  ]

  // Standard notification categories (freedesktop spec) -> Ocean sound.
  // Ordered: most specific sub-event first, base category after, because the
  // match is a prefix test and "device" would otherwise swallow
  // "device.removed". Sub-events containing "error" fall back to
  // dialog-error.oga before this table is consulted at all.
  property var categoryRules: [
    ["device.added", "device-added.oga"],
    ["device.removed", "device-removed.oga"],
    ["device", "device-added.oga"],
    ["email.arrived", "message-new-email.oga"],
    ["email.bounced", "dialog-error.oga"],
    ["email", "message-new-email.oga"],
    ["im.received", "message-new-instant.oga"],
    ["im.sent", "message-sent-instant.oga"],
    ["im", "message-new-instant.oga"],
    ["network.connected", "service-login.oga"],
    ["network.disconnected", "service-logout.oga"],
    ["network", "bell.oga"],
    ["presence.offline", "message-contact-out.oga"],
    ["presence.online", "message-contact-in.oga"],
    ["presence", "message-contact-in.oga"],
    ["transfer.complete", "completion-success.oga"],
    ["transfer.failed", "completion-fail.oga"],
    ["transfer", "completion-success.oga"],
    ["call.incoming", "phone-incoming-call.oga"],
    ["call.unanswered", "dialog-error.oga"],
    ["call.ended", "message-contact-out.oga"],
    ["call", "phone-incoming-call.oga"],
    ["mount", "media-insert-request.oga"],
    ["alarm", "alarm-clock-elapsed.oga"],
    ["battery.full", "battery-full.oga"],
    ["battery.critical", "battery-caution.oga"],
    ["battery", "battery-low.oga"],
    ["power.connected", "power-plug.oga"],
    ["power.disconnected", "power-unplug.oga"],
    ["trash", "trash-empty.oga"],
    ["question", "dialog-question.oga"],
    ["auth", "dialog-warning-auth.oga"],
    ["warning", "dialog-warning.oga"],
    ["x-omarchy.crash", "dialog-error-serious.oga"],
    ["media.error", "complete-media-error.oga"],
    ["media", "complete-media-burn.oga"],
    ["outcome.failure", "outcome-failure.oga"],
    ["outcome", "outcome-success.oga"]
  ]

  // Omarchy's own notifications carry an "omarchy-glyph" hint instead of a
  // category -- that glyph IS the event identity across the whole distro, so
  // matching it is what gets first-party events (a reminder firing, a download
  // finishing, a crash being captured) onto the right sound without patching
  // any of the omarchy-* scripts.
  //
  // Every codepoint below was read out of the live /usr/bin/omarchy-* scripts
  // rather than guessed from a Nerd Font chart, and is written as an escape so
  // the table survives an editor or terminal that cannot render the glyph.
  //
  // Third column is the critical-urgency variant, because Omarchy reuses one
  // glyph for both halves of an outcome: 󰒊 is "Sent to $name" AND, at critical,
  // "Could not send to $name". Without the split, a failure would chime like a
  // success.
  //   [glyph, normal sound, critical sound (optional)]
  // Keyed by NUMERIC codepoint, compared against g.codePointAt(0). These glyphs
  // live in Plane 15 (U+F0000+), so a "\uf088c" string escape would silently be
  // wrong -- JavaScript's \u takes exactly four hex digits, making that U+F088
  // followed by a literal "c", which matches nothing. Numbers sidestep the
  // escaping question entirely and read the same in any editor.
  //   [codepoint, normal sound, critical sound (optional)]
  property var glyphRules: [
    [0xF088C, "alarm-clock-elapsed.oga"],                               // reminder
    [0xF140B, "battery-low.oga", "battery-low.oga"],                    // time to recharge
    [0xF0079, "battery-full.oga"],                                      // battery status
    [0xF012C, "completion-success.oga"],                                // download complete
    [0xF0156, "completion-fail.oga"],                                   // download failed
    [0xF0D11, "completion-partial.oga"],                                // OCR text captured
    [0xF014D, "button-pressed.oga"],                                    // URL copied
    [0xF0432, "button-pressed-modifier.oga", "outcome-failure.oga"],    // QR copied / not found
    [0xF048A, "message-sent-instant.oga", "outcome-failure.oga"],       // sent to device / failed
    [0xF0BC9, "game-over-winner.oga", "game-over-loser.oga"],           // game installed / no cores
    [0xF0379, "bell-window-system.oga"],                                // display configuration
    [0xF10AC, "bell-window-system.oga"],                                // workspace layout
    [0xF1104, "bell-window-system.oga"],                                // screensaver toggled
    [0xF04B2, "bell.oga"],                                              // suspend availability
    [0xF16A1, "dialog-error-serious.oga"],                              // crash captured
    [0x0F021, "dialog-warning.oga"],                                    // pending migrations
    [0x0270B, "dialog-warning.oga"],                                    // screensaver refused
    [0x0EC12, "message-attention.oga"],                                 // voxtype ready
    [0x0F03E, "complete-media-burn.oga"],                               // transcode finished
    [0x0F03D, "media-insert-request.oga"],                              // transcode started
    [0x0F2D0, "button-pressed-modifier.oga"],                           // aspect ratio toggled
    [0x0F268, "trash-empty.oga"],                                       // web app removed
    [0x0F489, "trash-empty.oga"]                                        // TUI removed
  ]

  // Notification icon -> Ocean sound, checked after category and before the
  // urgency fallback. This is how first-party Omarchy notifications that carry
  // no category hint still land on the right sound: omarchy-battery-low sends
  // its warning with -i battery-caution and urgency critical, which would
  // otherwise come out as the generic dialog-error-critical klaxon. Matching
  // the icon keeps it to ONE sound for the event -- adding a battery-low.d
  // hook instead would play a second one over the top of the toast's.
  property var iconRules: [
    ["battery-caution", "battery-low.oga"],
    ["battery-low", "battery-low.oga"],
    ["battery-full", "battery-full.oga"],
    ["battery-charging", "power-plug.oga"],
    ["drive-removable-media-usb", "device-added.oga"],
    ["dialog-password", "dialog-warning-auth.oga"],
    ["dialog-question", "dialog-question.oga"],
    ["dialog-warning", "dialog-warning.oga"],
    ["mail-unread", "message-new-email.oga"],
    ["user-trash", "trash-empty.oga"]
  ]

  property string lowSound: soundDir + "/message-highlight.oga"
  property string normalSound: soundDir + "/dialog-information.oga"
  property string criticalSound: soundDir + "/dialog-error-critical.oga"

  // Runtime on/off switch, persisted so it survives shell restarts. Toggled
  // from the menu via omarchy-shell virtuoso.notification-sounds toggle.
  property bool soundEnabled: true
  property bool settingsLoaded: false
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/"
  readonly property string settingsPath: stateDir + "notification-sounds.json"

  // Signature (timestamp + id) of the newest popup we have already sounded.
  property string lastSignature: ""
  // Current popup count; guards against replaying on dismissals.
  property int lastCount: -1

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
  }

  function loadSettings(raw) {
    if (root.settingsLoaded) return
    var parsed = {}
    try { parsed = JSON.parse(raw || "") } catch (e) { }
    if (typeof parsed.enabled === "boolean") root.soundEnabled = parsed.enabled
    root.settingsLoaded = true
  }

  function saveSettings() {
    settingsFile.setText(JSON.stringify({ version: 1, enabled: root.soundEnabled }, null, 2) + "\n")
  }

  Process {
    id: player
  }

  // ------------------------------------------------------------ IPC toggle

  // State-changing helpers, callable directly (bar widget) and via IPC (menu).
  function toggleEnabled(): string {
    root.soundEnabled = !root.soundEnabled
    root.saveSettings()
    root.confirmEnabled()
    return root.soundEnabled ? "on" : "off"
  }
  function setEnabled(value: string): string {
    var v = String(value || "").toLowerCase()
    var was = root.soundEnabled
    root.soundEnabled = v === "true" || v === "1" || v === "on" || v === "yes"
    root.saveSettings()
    if (root.soundEnabled !== was) root.confirmEnabled()
    return root.soundEnabled ? "on" : "off"
  }

  // Switching sound back on plays the Ocean theme's own demo sample, so the
  // click that unmutes is also the confirmation that audio actually works --
  // otherwise re-enabling is silent and indistinguishable from a broken sink.
  // Muting stays silent, which is the whole point of muting.
  function confirmEnabled() {
    if (root.soundEnabled) root.play(root.soundDir + "/theme-demo.oga")
  }

  IpcHandler {
    target: "virtuoso.notification-sounds"

    // Guard against a Quickshell reload bug: IpcHandler destructors can leave
    // the handler stranded in the registry (basecamp/omarchy #7362,
    // quickshell-mirror/quickshell #898), which later writes through freed
    // memory and segfaults during hot reload. Deregistering while the QML
    // context is still alive avoids it.
    Component.onDestruction: enabled = false

    function status(): string {
      return root.soundEnabled ? "on" : "off"
    }
    function isEnabled(): string {
      return root.soundEnabled ? "on" : "off"
    }
    function toggle(): string {
      return root.toggleEnabled()
    }
    function setEnabled(value: string): string {
      return root.setEnabled(value)
    }

    // Play one Ocean sound by name, for callers that already have the shell in
    // hand. Scripts should prefer the omarchy-sound CLI: it works during login
    // and logout, when this shell is not yet up or already gone.
    function play(name: string): string {
      var n = String(name || "").replace(/\.(oga|ogg)$/i, "")
      if (root.knownSoundNames.indexOf(n) === -1) return "unknown sound: " + n
      if (!root.soundEnabled) return "muted"
      root.play(root.soundDir + "/" + n + ".oga")
      return "playing " + n
    }

    // Every sound this plugin can resolve, newline separated.
    function sounds(): string {
      return root.knownSoundNames.join("\n")
    }
  }

  function play(sound) {
    console.log("[notification-sounds] playing:", sound)
    if (player.running) player.running = false
    player.command = ["pw-play", sound]
    player.running = true
  }

  // Resolve the sound for a new popup: hints first, urgency as fallback.
  // Returns "" when the notification must stay silent (suppress-sound).
  function soundFor(row) {
    var sound = root.soundFromHints(row)
    if (sound === "silent") return ""
    if (sound) return sound
    var urgency = row ? Number(row.urgency) : 1
    if (urgency === 2) return root.criticalSound
    if (urgency === 0) return root.lowSound
    return root.normalSound
  }

  // Read the live notification's freedesktop hints: suppress-sound, sound-name,
  // and category. Returns "" when nothing applies so the caller falls back.
  function soundFromHints(row) {
    var live = root.notificationService && row
      ? root.notificationService.liveRefs[row.originalId] : null
    if (!live) return ""
    var hints = live.hints ? live.hints : {}

    // suppress-sound: the caller explicitly asks us not to make noise.
    if (hints["suppress-sound"] === true || String(hints["suppress-sound"]) === "true")
      return "silent"

    // sound-name: the caller explicitly picked a theme sound.
    var name = hints["sound-name"]
    if (name) {
      var n = String(name).replace(/\.(oga|ogg)$/i, "")
      if (root.knownSoundNames.indexOf(n) !== -1)
        return root.soundDir + "/" + n + ".oga"
    }

    // category: map standard freedesktop categories to Ocean sounds.
    var category = hints["category"]
    if (category) {
      var cat = String(category).toLowerCase()

      // Three passes, in this order, because a single pass gets it wrong both
      // ways round. Sub-event rules ("media.error") have to beat the generic
      // "anything with error in it" shortcut, or media.error would come out as
      // the plain error buzz. The shortcut in turn has to beat the base-category
      // rules, or an unlisted "network.error" would chime like ordinary network
      // news instead of a failure.
      var i
      for (i = 0; i < root.categoryRules.length; i++) {
        if (root.categoryRules[i][0].indexOf(".") === -1) continue
        if (cat.indexOf(root.categoryRules[i][0]) === 0)
          return root.soundDir + "/" + root.categoryRules[i][1]
      }
      if (cat.indexOf("error") !== -1) return root.soundDir + "/dialog-error.oga"
      for (i = 0; i < root.categoryRules.length; i++) {
        if (root.categoryRules[i][0].indexOf(".") !== -1) continue
        if (cat.indexOf(root.categoryRules[i][0]) === 0)
          return root.soundDir + "/" + root.categoryRules[i][1]
      }
    }

    // omarchy-glyph: first-party Omarchy events, keyed on the glyph they show.
    var glyph = hints["omarchy-glyph"]
    if (glyph) {
      var g = String(glyph)
      var cp = g.length ? g.codePointAt(0) : -1
      var critical = Number(hints["urgency"]) === 2
      for (var k = 0; k < root.glyphRules.length; k++) {
        if (cp !== root.glyphRules[k][0]) continue
        var pick = critical && root.glyphRules[k][2]
          ? root.glyphRules[k][2] : root.glyphRules[k][1]
        return root.soundDir + "/" + pick
      }
    }

    // appIcon: the last chance to identify an event before urgency decides.
    // Exact match only -- a substring test would let "battery-full" be caught
    // by the "battery-low" rule depending on table order.
    var icon = live.appIcon ? String(live.appIcon).toLowerCase() : ""
    if (icon) {
      for (var j = 0; j < root.iconRules.length; j++) {
        if (icon === root.iconRules[j][0])
          return root.soundDir + "/" + root.iconRules[j][1]
      }
    }
    return ""
  }

  // Adopt the current state silently whenever the model reference changes
  // (null -> real model), so pre-existing or restored toasts never fire a sound.
  onPopupModelChanged: {
    if (!root.popupModel) return
    root.lastCount = root.popupModel.count
    var first = root.popupModel.count > 0 ? root.popupModel.get(0) : null
    root.lastSignature = first ? String(first.timestamp) + "-" + String(first.originalId) : ""
  }

  Connections {
    target: root.popupModel

    function onCountChanged() {
      var model = root.popupModel
      if (!model) return
      if (model.count === 0) {
        root.lastCount = 0
        return
      }
      // Only react to inserts; dismissals (count decreasing) are ignored.
      if (model.count <= root.lastCount) {
        root.lastCount = model.count
        return
      }
      root.lastCount = model.count

      var row = model.get(0)
      var signature = String(row.timestamp) + "-" + String(row.originalId)
      if (signature === root.lastSignature) return
      root.lastSignature = signature

      // Toasts restored from a previous shell process are not new notifications.
      if (root.notificationService && typeof root.notificationService.isRestoredRow === "function") {
        try {
          if (root.notificationService.isRestoredRow(row)) return
        } catch (e) { }
      }

      // Respect the runtime toggle: no sound while the plugin is disabled.
      if (!root.soundEnabled) return

      var sound = root.soundFor(row)
      if (sound) root.play(sound)
    }
  }

  Component.onCompleted: {
    Qt.callLater(function() { settingsFile.reload() })
  }
}