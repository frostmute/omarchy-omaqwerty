import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root
    property bool opened: false
    property string page: "abc"
    property bool shift: false
    property var queue: []

    readonly property var alphaRows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        [{ label: "⇧", action: "shift", weight: 1.5 }, "z", "x", "c", "v", "b", "n", "m", { label: "⌫", action: "backspace", weight: 1.5 }]
    ]
    readonly property var numberRows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [{ label: "#+=", action: "symbols", weight: 1.5 }, ".", ",", "?", "!", "'", { label: "⌫", action: "backspace", weight: 1.5 }]
    ]
    readonly property var symbolRows: [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
        [{ label: "123", action: "numbers", weight: 1.5 }, ".", ",", "?", "!", "'", { label: "⌫", action: "backspace", weight: 1.5 }]
    ]
    // A deliberately large three-column keypad for touch entry.
    readonly property var numpadRows: [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"]
    ]
    readonly property var navigationKeys: [
        { label: "Esc", action: "key", key: "Escape" },
        { label: "Tab", action: "key", key: "Tab" },
        { label: "←", action: "key", key: "Left" },
        { label: "↑", action: "key", key: "Up" },
        { label: "↓", action: "key", key: "Down" },
        { label: "→", action: "key", key: "Right" },
        { label: "Home", action: "key", key: "Home" },
        { label: "End", action: "key", key: "End" },
        { label: "Pg↑", action: "key", key: "Page_Up" },
        { label: "Pg↓", action: "key", key: "Page_Down" }
    ]

    function rows() {
        return page === "abc" ? alphaRows : (page === "123" ? numberRows : (page === "numpad" ? numpadRows : symbolRows))
    }
    function bottomRow() {
        return page === "abc"
            ? [{ label: "123", action: "numbers", weight: 1.4 }, { label: ",", value: "," }, { label: "space", action: "space", weight: 4.3 }, { label: ".", value: "." }, { label: "↵", action: "enter", weight: 1.4 }]
            : [{ label: "ABC", action: "letters", weight: 1.4 }, { label: "space", action: "space", weight: 4.3 }, { label: "↵", action: "enter", weight: 1.4 }]
    }
    function keySpec(key) {
        return typeof key === "string" ? { label: key, value: key, weight: 1 } : key
    }
    function enqueue(command) {
        queue.push(command)
        drain()
    }
    function drain() {
        if (typeProcess.running || queue.length === 0) return
        typeProcess.command = queue.shift()
        typeProcess.running = true
    }
    function press(raw) {
        const key = keySpec(raw)
        switch (key.action) {
        case "shift": shift = !shift; return
        case "letters": page = "abc"; shift = false; return
        case "numbers": page = "123"; shift = false; return
        case "symbols": page = "sym"; shift = false; return
        case "backspace": enqueue(["wtype", "-k", "BackSpace"]); return
        case "enter": enqueue(["wtype", "-k", "Return"]); return
        case "space": enqueue(["wtype", " "]); return
        case "key": enqueue(["wtype", "-k", key.key]); return
        }
        let value = key.value === undefined ? key.label : key.value
        if (shift && /^[a-z]$/.test(value)) value = value.toUpperCase()
        enqueue(["wtype", value])
        if (shift) shift = false
    }
    function open(payloadJson) { opened = true }
    function close() { opened = false }
    function toggle() { opened = !opened }

    Process {
        id: typeProcess
        onExited: root.drain()
    }

    PanelWindow {
        id: panel
        visible: root.opened
        // Bottom-only anchors give this layer surface the keyboard's real
        // height. Auto then publishes that height as Hyprland work area.
        anchors { bottom: true; left: true; right: true }
        implicitHeight: card.height + Style.spacing.lg
        color: "transparent"
        mask: Region { item: card }
        WlrLayershell.namespace: "io.github.frostmute.tablet-keyboard"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Auto

        BorderSurface {
            id: card
            readonly property bool portrait: panel.screen && panel.screen.height > panel.screen.width
            readonly property int headerHeight: Style.space(48)
            width: Math.min(panel.width - Style.spacing.popupPadding * 2, portrait ? Style.space(560) : Style.space(960))
            // Leave enough vertical room for all four key rows, including the
            // numbers/space/enter row on short landscape displays.
            height: portrait ? Style.space(500) : Style.space(440)
            x: (panel.width - width) / 2
            y: Style.spacing.lg
            radius: Style.cornerRadius
            color: Color.popups.background
            borderSpec: Border.hyprlandActiveSpec(Color.accent, 2)

            Column {
                anchors.fill: parent
                anchors.margins: Style.spacing.md
                spacing: Style.spacing.sm

                Row {
                    width: parent.width
                    height: card.headerHeight
                    spacing: Style.spacing.sm
                    Flickable {
                        id: navigation
                        width: parent.width - tools.implicitWidth - parent.spacing
                        height: parent.height
                        clip: true
                        contentWidth: navigationRow.width
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        Row {
                            id: navigationRow
                            height: navigation.height
                            spacing: Style.spacing.sm
                            Repeater {
                                model: root.navigationKeys
                                delegate: Rectangle {
                                    required property var modelData
                                    width: Math.max(Style.space(54), navLabel.implicitWidth + Style.spacing.md * 2)
                                    height: parent.height
                                    radius: Style.cornerRadius
                                    color: navTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                                    Text { id: navLabel; anchors.centerIn: parent; text: parent.modelData.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                                    MouseArea { id: navTap; anchors.fill: parent; onClicked: root.press(parent.modelData) }
                                }
                            }
                        }
                    }
                    Row {
                        id: tools
                        height: parent.height
                        spacing: Style.spacing.sm
                        Repeater {
                            model: [
                                { label: "Numpad", action: "numpad" },
                                { label: "Clipboard", action: "clipboard" },
                                { label: "Trackpad", action: "trackpad" },
                                { label: "Close", action: "close" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: toolLabel.implicitWidth + Style.spacing.md * 2
                                height: parent.height
                                radius: Style.cornerRadius
                                color: toolTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                                Text { id: toolLabel; anchors.centerIn: parent; text: parent.modelData.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
                                MouseArea {
                                    id: toolTap
                                    anchors.fill: parent
                                    onClicked: {
                                        if (parent.modelData.action === "close") root.close()
                                        else if (parent.modelData.action === "numpad") { root.page = "numpad"; root.shift = false }
                                        else if (parent.modelData.action === "clipboard") root.enqueue(["omarchy-shell", "shell", "toggle", "omarchy.clipboard"])
                                        else root.enqueue(["omarchy-shell", "shell", "toggle", "io.github.frostmute.onscreen-trackpad"])
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    // Repeater delegates do not reliably contribute to a
                    // Column's implicit height; declare this explicitly so
                    // the fixed bottom row stays inside the panel.
                    height: ((card.height - Style.spacing.md * 2 - card.headerHeight - Style.spacing.sm * 5) / 4) * 3 + Style.spacing.sm * 2
                    spacing: Style.spacing.sm
                    Repeater {
                        model: root.rows()
                        delegate: Item {
                            required property var modelData
                            property var rowKeys: modelData
                            property real totalWeight: rowKeys.reduce(function(sum, item) { return sum + root.keySpec(item).weight }, 0)
                            width: parent.width
                            height: (card.height - Style.spacing.md * 2 - card.headerHeight - Style.spacing.sm * 5) / 4
                            Row {
                                anchors.centerIn: parent
                                spacing: Style.spacing.sm
                                Repeater {
                                    model: parent.parent.rowKeys
                                    delegate: Rectangle {
                                        required property var modelData
                                        property var key: root.keySpec(modelData)
                                        width: (parent.parent.width - parent.spacing * (parent.parent.rowKeys.length - 1)) * key.weight / parent.parent.totalWeight
                                        height: parent.parent.height
                                        radius: Style.cornerRadius
                                        color: key.action === "shift" && root.shift ? Color.accent : (tap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha))
                                        border.color: Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                        border.width: Style.normalBorderWidth
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.key.label
                                            color: Color.foreground
                                            font.family: Style.font.family
                                            font.pixelSize: parent.key.action === "space" ? Style.font.title : Style.font.heading
                                        }
                                        MouseArea {
                                            id: tap
                                            anchors.fill: parent
                                            onClicked: root.press(parent.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Kept outside the repeated rows so the essential space,
                // enter, punctuation, and layout-switch controls cannot be
                // clipped by a compact display.
            Item {
                // An absolute overlay avoids Column/Repeater implicit-size
                // bugs and guarantees these essential controls are reachable.
                x: 0
                y: 0
                width: card.width
                height: card.height
                z: 10
                Row {
                    id: essentialKeys
                    x: Style.spacing.md
                    y: parent.height - height - Style.spacing.md
                    width: parent.width - Style.spacing.md * 2
                    height: (card.height - Style.spacing.md * 2 - card.headerHeight - Style.spacing.sm * 5) / 4
                    spacing: Style.spacing.sm
                        Rectangle {
                            width: (essentialKeys.width - essentialKeys.spacing * 4) * 0.14; height: essentialKeys.height; radius: Style.cornerRadius
                            color: firstTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                            Text { anchors.centerIn: parent; text: root.page === "abc" ? "123" : "ABC"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
                            MouseArea { id: firstTap; anchors.fill: parent; onClicked: { root.page = root.page === "abc" ? "123" : "abc"; root.shift = false } }
                        }
                        Rectangle {
                            width: (essentialKeys.width - essentialKeys.spacing * 4) * 0.09; height: essentialKeys.height; radius: Style.cornerRadius
                            color: commaTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                            Text { anchors.centerIn: parent; text: ","; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
                            MouseArea { id: commaTap; anchors.fill: parent; onClicked: root.press({ label: ",", value: "," }) }
                        }
                        Rectangle {
                            width: (essentialKeys.width - essentialKeys.spacing * 4) * 0.44; height: essentialKeys.height; radius: Style.cornerRadius
                            color: spaceTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                            Text { anchors.centerIn: parent; text: root.page === "numpad" ? "0" : "space"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
                            MouseArea { id: spaceTap; anchors.fill: parent; onClicked: root.press(root.page === "numpad" ? { label: "0", value: "0" } : { action: "space" }) }
                        }
                        Rectangle {
                            width: (essentialKeys.width - essentialKeys.spacing * 4) * 0.09; height: essentialKeys.height; radius: Style.cornerRadius
                            color: periodTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                            Text { anchors.centerIn: parent; text: "."; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
                            MouseArea { id: periodTap; anchors.fill: parent; onClicked: root.press({ label: ".", value: "." }) }
                        }
                        Rectangle {
                            width: (essentialKeys.width - essentialKeys.spacing * 4) * 0.24; height: essentialKeys.height; radius: Style.cornerRadius
                            color: enterTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                            Text { anchors.centerIn: parent; text: "↵"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
                            MouseArea { id: enterTap; anchors.fill: parent; onClicked: root.press({ action: "enter" }) }
                        }
                    }
                    Row {
                        visible: false
                        anchors.centerIn: parent
                        spacing: Style.spacing.sm
                        Repeater {
                            model: parent.parent.rowKeys
                            delegate: Rectangle {
                                required property var modelData
                                property var key: root.keySpec(modelData)
                                width: (parent.parent.width - parent.spacing * (parent.parent.rowKeys.length - 1)) * key.weight / parent.parent.totalWeight
                                height: parent.parent.height
                                radius: Style.cornerRadius
                                color: tap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                                border.color: Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                border.width: Style.normalBorderWidth
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.key.label
                                    color: Color.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: parent.key.action === "space" ? Style.font.bodySmall : Style.font.body
                                }
                                TapHandler {
                                    id: tap
                                    acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse
                                    onTapped: root.press(parent.modelData)
                                }
                            }
                        }
                    }
                }
        }
    }

}
