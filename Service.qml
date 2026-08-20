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

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  readonly property var notificationService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var popupModel: notificationService ? notificationService.popupModel : null

  property string soundDir: "/usr/share/sounds/ocean/stereo"

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
  // Ordered: most specific sub-event first, base category after. Sub-events
  // containing "error" always fall back to dialog-error.oga.
  property var categoryRules: [
    ["device.removed", "device-removed.oga"],
    ["device", "device-added.oga"],
    ["email.bounced", "dialog-error.oga"],
    ["email", "message-new-email.oga"],
    ["im", "message-new-instant.oga"],
    ["network.disconnected", "bell.oga"],
    ["network", "bell.oga"],
    ["presence", "message-contact-in.oga"],
    ["transfer.failed", "completion-fail.oga"],
    ["transfer", "completion-success.oga"],
    ["call.unanswered", "dialog-error.oga"],
    ["call", "phone-incoming-call.oga"]
  ]

  property string lowSound: soundDir + "/message-highlight.oga"
  property string normalSound: soundDir + "/dialog-information.oga"
  property string criticalSound: soundDir + "/dialog-error-critical.oga"

  // Runtime on/off switch, persisted so it survives shell restarts. Toggled
  // from the menu via omarchy-shell virtuoso.notification-sounds toggle.
  property bool enabled: true
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
    if (typeof parsed.enabled === "boolean") root.enabled = parsed.enabled
    root.settingsLoaded = true
  }

  function saveSettings() {
    settingsFile.setText(JSON.stringify({ version: 1, enabled: root.enabled }, null, 2) + "\n")
  }

  Process {
    id: player
  }

  // ------------------------------------------------------------ IPC toggle

  // State-changing helpers, callable directly (bar widget) and via IPC (menu).
  function toggleEnabled(): string {
    root.enabled = !root.enabled
    root.saveSettings()
    return root.enabled ? "on" : "off"
  }
  function setEnabled(value: string): string {
    var v = String(value || "").toLowerCase()
    root.enabled = v === "true" || v === "1" || v === "on" || v === "yes"
    root.saveSettings()
    return root.enabled ? "on" : "off"
  }

  IpcHandler {
    target: "virtuoso.notification-sounds"

    function status(): string {
      return root.enabled ? "on" : "off"
    }
    function isEnabled(): string {
      return root.enabled ? "on" : "off"
    }
    function toggle(): string {
      return root.toggleEnabled()
    }
    function setEnabled(value: string): string {
      return root.setEnabled(value)
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
    var hints = live && live.hints ? live.hints : null
    if (!hints) return ""

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
      if (cat.indexOf("error") !== -1) return root.soundDir + "/dialog-error.oga"
      for (var i = 0; i < root.categoryRules.length; i++) {
        if (cat.indexOf(root.categoryRules[i][0]) === 0)
          return root.soundDir + "/" + root.categoryRules[i][1]
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
      if (!root.enabled) return

      var sound = root.soundFor(row)
      if (sound) root.play(sound)
    }
  }

  Component.onCompleted: {
    Qt.callLater(function() { settingsFile.reload() })
  }
}