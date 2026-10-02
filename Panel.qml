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
    property bool shiftLocked: false
    property bool ctrl: false
    property bool ctrlLocked: false
    property bool alt: false
    property bool altLocked: false
    property bool superKey: false
    property bool superLocked: false
    property bool fnActive: false
    property bool fnLocked: false
    property bool isDocked: true
    property var queue: []
    property var lastTapTimes: ({})

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
        [{ label: "123", action: "numbers", weight: 1.5 }, "`", ",", "?", "!", "'", { label: "⌫", action: "backspace", weight: 1.5 }]
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
        { label: "Del", action: "key", key: "Delete" },
        { label: "←", action: "key", key: "Left" },
        { label: "↑", action: "key", key: "Up" },
        { label: "↓", action: "key", key: "Down" },
        { label: "→", action: "key", key: "Right" },
        { label: "Home", action: "key", key: "Home" },
        { label: "End", action: "key", key: "End" },
        { label: "Pg↑", action: "key", key: "Page_Up" },
        { label: "Pg↓", action: "key", key: "Page_Down" }
    ]
    readonly property var functionKeys: [
        { label: "F1", action: "key", key: "F1" },
        { label: "F2", action: "key", key: "F2" },
        { label: "F3", action: "key", key: "F3" },
        { label: "F4", action: "key", key: "F4" },
        { label: "F5", action: "key", key: "F5" },
        { label: "F6", action: "key", key: "F6" },
        { label: "F7", action: "key", key: "F7" },
        { label: "F8", action: "key", key: "F8" },
        { label: "F9", action: "key", key: "F9" },
        { label: "F10", action: "key", key: "F10" },
        { label: "F11", action: "key", key: "F11" },
        { label: "F12", action: "key", key: "F12" },
        { label: "PrtSc", action: "key", key: "Print" },
        { label: "Ins", action: "key", key: "Insert" },
        { label: "Del", action: "key", key: "Delete" }
    ]

    readonly property var shiftSymbolMap: ({
        "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
        "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
        "-": "_", "=": "+", "[": "{", "]": "}", ";": ":",
        "'": "\"", ",": "<", ".": ">", "/": "?", "\\": "|", "`": "~"
    })

    function rows() {
        return page === "abc" ? alphaRows : (page === "123" ? numberRows : (page === "numpad" ? numpadRows : symbolRows))
    }

    function getBottomRowModel() {
        return [
            { label: "Ctrl", action: "ctrl", weight: 1.05, isModifier: true, active: root.ctrl, locked: root.ctrlLocked },
            { label: "Fn", action: "fn", weight: 0.9, isModifier: true, active: root.fnActive, locked: root.fnLocked },
            { label: "Super", sublabel: "Cmd", action: "super", weight: 1.15, isModifier: true, active: root.superKey, locked: root.superLocked },
            { label: "Alt", action: "alt", weight: 1.0, isModifier: true, active: root.alt, locked: root.altLocked },
            { label: root.page === "abc" ? "123" : "ABC", action: root.page === "abc" ? "numbers" : "letters", weight: 1.15 },
            { label: root.page === "numpad" ? "0" : "space", action: root.page === "numpad" ? "char" : "space", value: "0", weight: 3.8 },
            { label: ",", value: ",", action: "char", weight: 0.8 },
            { label: ".", value: ".", action: "char", weight: 0.8 },
            { label: "↵", action: "enter", weight: 1.35 }
        ]
    }

    function keySpec(key) {
        return typeof key === "string" ? { label: key, value: key, weight: 1 } : key
    }

    function toggleModifier(name) {
        let now = Date.now()
        let last = lastTapTimes[name] || 0
        let isDouble = (now - last) < 400
        lastTapTimes[name] = now

        if (name === "ctrl") {
            if (isDouble) {
                ctrlLocked = !ctrlLocked
                ctrl = ctrlLocked
            } else {
                if (ctrlLocked) {
                    ctrlLocked = false
                    ctrl = false
                } else {
                    ctrl = !ctrl
                }
            }
        } else if (name === "alt") {
            if (isDouble) {
                altLocked = !altLocked
                alt = altLocked
            } else {
                if (altLocked) {
                    altLocked = false
                    alt = false
                } else {
                    alt = !alt
                }
            }
        } else if (name === "super") {
            if (isDouble) {
                superLocked = !superLocked
                superKey = superLocked
            } else {
                if (superLocked) {
                    superLocked = false
                    superKey = false
                } else {
                    superKey = !superKey
                }
            }
        } else if (name === "shift") {
            if (isDouble) {
                shiftLocked = !shiftLocked
                shift = shiftLocked
            } else {
                if (shiftLocked) {
                    shiftLocked = false
                    shift = false
                } else {
                    shift = !shift
                }
            }
        } else if (name === "fn") {
            if (isDouble) {
                fnLocked = !fnLocked
                fnActive = fnLocked
            } else {
                if (fnLocked) {
                    fnLocked = false
                    fnActive = false
                } else {
                    fnActive = !fnActive
                }
            }
        }
    }

    function activeModifiers() {
        let mods = []
        if (ctrl) mods.push("ctrl")
        if (alt) mods.push("alt")
        if (superKey) mods.push("logo")
        if (shift) mods.push("shift")
        return mods
    }

    function clearSingleModifiers() {
        if (ctrl && !ctrlLocked) ctrl = false
        if (alt && !altLocked) alt = false
        if (superKey && !superLocked) superKey = false
        if (shift && !shiftLocked) shift = false
        if (fnActive && !fnLocked) fnActive = false
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
        case "shift":
            toggleModifier("shift")
            return
        case "ctrl":
            toggleModifier("ctrl")
            return
        case "alt":
            toggleModifier("alt")
            return
        case "super":
            toggleModifier("super")
            return
        case "fn":
            toggleModifier("fn")
            return
        case "letters":
            page = "abc"
            if (!shiftLocked) shift = false
            return
        case "numbers":
            page = "123"
            if (!shiftLocked) shift = false
            return
        case "symbols":
            page = "sym"
            if (!shiftLocked) shift = false
            return
        case "numpad":
            page = "numpad"
            if (!shiftLocked) shift = false
            return
        case "backspace":
            dispatchKey("BackSpace")
            return
        case "enter":
            dispatchKey("Return")
            return
        case "space":
            if (ctrl || alt || superKey) {
                dispatchKey("space")
            } else {
                enqueue(["wtype", "--", " "])
                clearSingleModifiers()
            }
            return
        case "key":
            dispatchKey(key.key)
            return
        }

        let value = key.value === undefined ? key.label : key.value

        // When Fn is active, numeric keys dispatch F1-F10
        if (fnActive && /^[0-9]$/.test(value)) {
            let fNum = value === "0" ? "F10" : ("F" + value)
            dispatchKey(fNum)
            return
        }

        dispatchChar(value)
    }

    function dispatchKey(keysym) {
        let mods = activeModifiers()
        let cmd = ["wtype"]
        for (let i = 0; i < mods.length; i++) {
            cmd.push("-M", mods[i])
        }
        cmd.push("-k", keysym)
        for (let i = mods.length - 1; i >= 0; i--) {
            cmd.push("-m", mods[i])
        }
        enqueue(cmd)
        clearSingleModifiers()
    }

    function dispatchChar(character) {
        let hasNonShiftMods = ctrl || alt || superKey
        if (hasNonShiftMods) {
            let mods = activeModifiers()
            let code = character.toLowerCase()
            let cmd = ["wtype"]
            for (let i = 0; i < mods.length; i++) {
                cmd.push("-M", mods[i])
            }
            cmd.push("-k", code)
            for (let i = mods.length - 1; i >= 0; i--) {
                cmd.push("-m", mods[i])
            }
            enqueue(cmd)
        } else {
            let charToType = character
            if (shift) {
                if (/^[a-z]$/.test(charToType)) {
                    charToType = charToType.toUpperCase()
                } else if (shiftSymbolMap[charToType]) {
                    charToType = shiftSymbolMap[charToType]
                }
            }
            enqueue(["wtype", "--", charToType])
        }
        clearSingleModifiers()
    }

    function open(payloadJson) {
        opened = true
        if (root.isDocked) {
            dock()
        } else {
            clampPosition()
        }
    }

    function close() {
        opened = false
    }

    function toggle() {
        if (opened) close()
        else open()
    }

    function dock() {
        root.isDocked = true
        card.x = Math.round((panel.width - card.width) / 2)
        card.y = Style.spacing.lg
    }

    function undock() {
        if (!root.isDocked) return
        root.isDocked = false
        let screenH = panel.screen ? panel.screen.height : panel.height
        let screenW = panel.screen ? panel.screen.width : panel.width
        card.x = Math.round((screenW - card.width) / 2)
        card.y = Math.max(0, screenH - card.height - Style.spacing.lg)
    }

    function checkSnapToDock() {
        if (root.isDocked) return
        let screenH = panel.screen ? panel.screen.height : panel.height
        let screenW = panel.screen ? panel.screen.width : panel.width
        let dockY = screenH - card.height - Style.spacing.lg
        let centerX = (screenW - card.width) / 2
        // Snap back into dock if released within 50px of bottom and within 100px of center
        if (card.y >= dockY - 50 && Math.abs(card.x - centerX) < 100) {
            dock()
        }
    }

    function clampPosition() {
        if (!panel.screen || panel.width <= 0 || panel.height <= 0) return
        let screenW = panel.screen ? panel.screen.width : panel.width
        let screenH = panel.screen ? panel.screen.height : panel.height
        card.x = Math.max(0, Math.min(card.x, screenW - card.width))
        card.y = Math.max(0, Math.min(card.y, screenH - card.height))
    }

    Process {
        id: typeProcess
        onExited: root.drain()
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors {
            top: !root.isDocked
            bottom: true
            left: true
            right: true
        }
        implicitHeight: root.isDocked ? (card.height + Style.spacing.lg) : (panel.screen ? panel.screen.height : 1080)
        color: "transparent"
        mask: Region { item: card }
        WlrLayershell.namespace: "io.github.frostmute.tablet-keyboard"
        WlrLayershell.layer: root.isDocked ? WlrLayer.Top : WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: root.isDocked ? ExclusionMode.Auto : ExclusionMode.Ignore

        onWidthChanged: {
            if (root.isDocked) {
                card.x = Math.round((panel.width - card.width) / 2)
            } else {
                root.clampPosition()
            }
        }
        onHeightChanged: {
            if (root.isDocked) {
                card.y = Style.spacing.lg
            } else {
                root.clampPosition()
            }
        }

        BorderSurface {
            id: card
            readonly property bool portrait: panel.screen && panel.screen.height > panel.screen.width
            readonly property int dragBarHeight: Style.space(24)
            readonly property int headerHeight: Style.space(42)
            readonly property int rowSpacing: Style.spacing.sm
            readonly property int cardMargin: Style.spacing.md
            readonly property real availableKeyHeight: height - cardMargin * 2 - dragBarHeight - headerHeight - rowSpacing * 5
            readonly property real rowHeight: Math.floor(availableKeyHeight / 4)

            width: Math.min(panel.width - Style.spacing.popupPadding * 2, portrait ? Style.space(560) : Style.space(960))
            height: portrait ? Style.space(520) : Style.space(460)

            x: Math.round((panel.width - width) / 2)
            y: Style.spacing.lg
            radius: Style.cornerRadius
            color: Color.popups.background
            borderSpec: Border.hyprlandActiveSpec(Color.accent, 2)

            Column {
                anchors.fill: parent
                anchors.margins: card.cardMargin
                spacing: card.rowSpacing

                // Drag bar across top of keyboard for touch and mouse repositioning
                Item {
                    id: dragBar
                    width: parent.width
                    height: card.dragBarHeight

                    DragHandler {
                        id: dragHandler
                        target: null
                        property real startCardX: 0
                        property real startCardY: 0

                        onActiveChanged: {
                            if (active) {
                                if (root.isDocked) root.undock()
                                startCardX = card.x
                                startCardY = card.y
                            } else {
                                root.checkSnapToDock()
                            }
                        }

                        onTranslationChanged: {
                            if (!active) return
                            let screenW = panel.screen ? panel.screen.width : panel.width
                            let screenH = panel.screen ? panel.screen.height : panel.height
                            let targetX = startCardX + translation.x
                            let targetY = startCardY + translation.y
                            card.x = Math.max(0, Math.min(targetX, screenW - card.width))
                            card.y = Math.max(0, Math.min(targetY, screenH - card.height))
                        }
                    }

                    TapHandler {
                        onDoubleTapped: {
                            if (root.isDocked) root.undock()
                            else root.dock()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onDoubleClicked: {
                            if (root.isDocked) root.undock()
                            else root.dock()
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.spacing.xs

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(52)
                            height: Style.space(4)
                            radius: Style.space(2)
                            color: dragHandler.active
                                ? Color.accent
                                : Util.alpha(Color.foreground, Style.pressedFillAlpha)
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: Style.spacing.xs
                            verticalCenter: parent.verticalCenter
                        }
                        text: root.isDocked
                            ? "󰌌 Drag to undock & move"
                            : "󰌌 Drag to move · Double-tap to dock"
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                // Header row: Navigation / Function keys on left, Tool launchers on right
                Row {
                    id: headerRow
                    width: parent.width
                    height: card.headerHeight
                    spacing: card.rowSpacing

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
                            spacing: card.rowSpacing

                            Repeater {
                                model: root.fnActive ? root.functionKeys : root.navigationKeys
                                delegate: Rectangle {
                                    id: navRect
                                    required property var modelData
                                    width: Math.max(Style.space(52), navLabel.implicitWidth + Style.spacing.md * 2)
                                    height: parent.height
                                    radius: Style.cornerRadius
                                    color: navTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                                    border.color: Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                    border.width: Style.normalBorderWidth

                                    Text {
                                        id: navLabel
                                        anchors.centerIn: parent
                                        text: navRect.modelData ? navRect.modelData.label : ""
                                        color: Color.foreground
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                    }

                                    MouseArea {
                                        id: navTap
                                        anchors.fill: parent
                                        onClicked: if (navRect.modelData) root.press(navRect.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: tools
                        height: parent.height
                        spacing: card.rowSpacing

                        Repeater {
                            model: [
                                { label: root.page === "numpad" ? "QWERTY" : "Numpad", action: root.page === "numpad" ? "letters" : "numpad" },
                                { label: "Clipboard", action: "clipboard" },
                                { label: "Trackpad", action: "trackpad" },
                                { label: root.isDocked ? "Float" : "Dock", action: root.isDocked ? "undock" : "dock" },
                                { label: "✕", action: "close" }
                            ]
                            delegate: Rectangle {
                                id: toolRect
                                required property var modelData
                                width: toolLabel.implicitWidth + Style.spacing.md * 2
                                height: parent.height
                                radius: Style.cornerRadius
                                color: toolRect.modelData && toolRect.modelData.action === "close" && toolTap.pressed
                                    ? Color.urgent
                                    : (toolTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha))
                                border.color: Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                border.width: Style.normalBorderWidth

                                Text {
                                    id: toolLabel
                                    anchors.centerIn: parent
                                    text: toolRect.modelData ? toolRect.modelData.label : ""
                                    color: Color.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                }

                                MouseArea {
                                    id: toolTap
                                    anchors.fill: parent
                                    onClicked: {
                                        if (!toolRect.modelData) return
                                        if (toolRect.modelData.action === "close") root.close()
                                        else if (toolRect.modelData.action === "dock") root.dock()
                                        else if (toolRect.modelData.action === "undock") root.undock()
                                        else if (toolRect.modelData.action === "numpad") { root.page = "numpad"; if (!root.shiftLocked) root.shift = false }
                                        else if (toolRect.modelData.action === "letters") { root.page = "abc"; if (!root.shiftLocked) root.shift = false }
                                        else if (toolRect.modelData.action === "clipboard") root.enqueue(["omarchy-shell", "shell", "toggle", "omarchy.clipboard"])
                                        else root.enqueue(["omarchy-shell", "shell", "toggle", "io.github.frostmute.onscreen-trackpad"])
                                    }
                                }
                            }
                        }
                    }
                }

                // 3 Repeated Key Rows (letters, numbers, symbols, or numpad rows)
                Column {
                    id: keyRowsColumn
                    width: parent.width
                    height: card.rowHeight * 3 + card.rowSpacing * 2
                    spacing: card.rowSpacing

                    Repeater {
                        model: root.rows()
                        delegate: Item {
                            id: rowContainer
                            required property var modelData
                            property var rowKeys: modelData
                            property real totalWeight: rowKeys ? rowKeys.reduce(function(sum, item) { return sum + root.keySpec(item).weight }, 0) : 1
                            width: parent.width
                            height: card.rowHeight

                            Row {
                                id: innerRow
                                anchors.centerIn: parent
                                spacing: card.rowSpacing

                                Repeater {
                                    model: rowContainer.rowKeys
                                    delegate: Rectangle {
                                        id: keyRect
                                        required property var modelData
                                        property var key: root.keySpec(modelData)
                                        property bool isShiftKey: key && key.action === "shift"
                                        property bool shiftActive: isShiftKey && (root.shift || root.shiftLocked)

                                        width: (rowContainer.width - card.rowSpacing * (rowContainer.rowKeys.length - 1)) * (key ? key.weight : 1) / rowContainer.totalWeight
                                        height: rowContainer.height
                                        radius: Style.cornerRadius
                                        color: shiftActive ? Color.accent : (tap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha))
                                        border.color: shiftActive ? Color.accent : Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                        border.width: shiftActive ? 2 : Style.normalBorderWidth

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: {
                                                    if (!keyRect.key) return ""
                                                    let lbl = keyRect.key.label
                                                    if (keyRect.isShiftKey && root.shiftLocked) return "⇪"
                                                    if (root.shift && /^[a-z]$/.test(lbl)) return lbl.toUpperCase()
                                                    if (root.shift && root.shiftSymbolMap[lbl]) return root.shiftSymbolMap[lbl]
                                                    return lbl
                                                }
                                                color: Color.foreground
                                                font.family: Style.font.family
                                                font.pixelSize: keyRect.key && keyRect.key.action === "space" ? Style.font.title : Style.font.heading
                                                font.bold: keyRect.shiftActive
                                            }

                                            Text {
                                                visible: keyRect.isShiftKey && root.shiftLocked
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "CAPS"
                                                color: Color.foreground
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            id: tap
                                            anchors.fill: parent
                                            onClicked: if (keyRect.modelData) root.press(keyRect.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Row: Modifiers (Ctrl, Fn, Super/Cmd, Alt), Page switch, Space, Punctuation, Enter
                Row {
                    id: bottomRow
                    width: parent.width
                    height: card.rowHeight
                    spacing: card.rowSpacing
                    property var bottomModel: root.getBottomRowModel()
                    property real totalWeight: bottomModel.reduce(function(sum, item) { return sum + item.weight }, 0)

                    Repeater {
                        model: bottomRow.bottomModel
                        delegate: Rectangle {
                            id: bottomKeyRect
                            required property var modelData
                            property var key: modelData
                            property bool isHighlighted: key && (!!key.locked || !!key.active)

                            width: (bottomRow.width - bottomRow.spacing * (bottomRow.bottomModel.length - 1)) * (key ? key.weight : 1) / bottomRow.totalWeight
                            height: bottomRow.height
                            radius: Style.cornerRadius
                            color: isHighlighted ? Color.accent : (bottomTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha))
                            border.color: isHighlighted ? Color.accent : Util.alpha(Color.foreground, Style.pressedFillAlpha)
                            border.width: isHighlighted ? 2 : Style.normalBorderWidth

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bottomKeyRect.key ? bottomKeyRect.key.label : ""
                                    color: Color.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: bottomKeyRect.key && (bottomKeyRect.key.action === "space" || bottomKeyRect.key.action === "enter") ? Style.font.title : Style.font.body
                                    font.bold: bottomKeyRect.isHighlighted
                                }

                                Text {
                                    visible: bottomKeyRect.key && (!!bottomKeyRect.key.locked || (!!bottomKeyRect.key.sublabel && !bottomKeyRect.key.locked))
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bottomKeyRect.key ? (bottomKeyRect.key.locked ? "LOCK" : (bottomKeyRect.key.sublabel || "")) : ""
                                    color: bottomKeyRect.key && bottomKeyRect.key.locked ? Color.foreground : Color.muted
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: bottomKeyRect.key && !!bottomKeyRect.key.locked
                                }
                            }

                            MouseArea {
                                id: bottomTap
                                anchors.fill: parent
                                onClicked: if (bottomKeyRect.modelData) root.press(bottomKeyRect.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
