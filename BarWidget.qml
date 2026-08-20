// Bar widget for the Virtuoso notification-sounds plugin: a speaker glyph in
// the bar that reflects the sound on/off state and toggles it on click. State
// is shared with the Service.qml instance (the same plugin's service entry).

import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "virtuoso.notification-sounds"

  // Reach the long-running service through the bar host, same pattern the
  // first-party bar widgets use.
  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var soundService: hostShell && hostShell.firstPartyServiceFor
    ? hostShell.firstPartyServiceFor("virtuoso.notification-sounds") : null
  readonly property bool soundsOn: soundService ? !!soundService.soundEnabled : true

  function toggle() {
    if (soundService && typeof soundService.toggleEnabled === "function")
      soundService.toggleEnabled()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.soundsOn ? "󰓃" : "󰝟"
    active: root.soundsOn
    dimmed: !root.soundsOn
    tooltipText: root.soundsOn
      ? "Notification sounds: on — click to mute"
      : "Notification sounds: off — click to enable"
    onPressed: function(b) {
      if (b === Qt.LeftButton || b === Qt.RightButton) root.toggle()
    }
  }
}