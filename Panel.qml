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

    property string sizePreset: "M" // "S", "M", "L", "Full", or "custom"
    property real customWidthLandscape: -1
    property real customHeightLandscape: -1
    property real customWidthPortrait: -1
    property real customHeightPortrait: -1
    property bool sizePopupOpen: false
    property real floatingX: -1
    property real floatingY: -1

    readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/omaqwerty.json"

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadSettings(text())
        onLoadFailed: root.loadSettings("")
    }

    Timer {
        id: saveTimer
        interval: 300
        repeat: false
        onTriggered: root.flushSettings()
    }

    function scheduleSave() {
        saveTimer.restart()
    }

    function loadSettings(raw) {
        if (!raw || raw.trim().length === 0) return
        try {
            let cfg = JSON.parse(raw)
            if (cfg.sizePreset) root.sizePreset = cfg.sizePreset
            if (cfg.customWidthLandscape !== undefined && cfg.customWidthLandscape > 0) root.customWidthLandscape = cfg.customWidthLandscape
            if (cfg.customHeightLandscape !== undefined && cfg.customHeightLandscape > 0) root.customHeightLandscape = cfg.customHeightLandscape
            if (cfg.customWidthPortrait !== undefined && cfg.customWidthPortrait > 0) root.customWidthPortrait = cfg.customWidthPortrait
            if (cfg.customHeightPortrait !== undefined && cfg.customHeightPortrait > 0) root.customHeightPortrait = cfg.customHeightPortrait
            if (cfg.isDocked !== undefined) root.isDocked = cfg.isDocked
            if (cfg.floatingX !== undefined && cfg.floatingX >= 0) root.floatingX = cfg.floatingX
            if (cfg.floatingY !== undefined && cfg.floatingY >= 0) root.floatingY = cfg.floatingY
        } catch (e) {
            console.warn("omaqwerty: error parsing settings:", e)
        }
    }

    function flushSettings() {
        let cfg = {
            version: 1,
            sizePreset: root.sizePreset,
            customWidthLandscape: root.customWidthLandscape,
            customHeightLandscape: root.customHeightLandscape,
            customWidthPortrait: root.customWidthPortrait,
            customHeightPortrait: root.customHeightPortrait,
            isDocked: root.isDocked,
            floatingX: root.floatingX,
            floatingY: root.floatingY
        }
        settingsFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    }

    function setPreset(name) {
        sizePreset = name
        if (card.portrait) {
            customWidthPortrait = -1
            customHeightPortrait = -1
        } else {
            customWidthLandscape = -1
            customHeightLandscape = -1
        }
        scheduleSave()
    }

    function cyclePreset() {
        let list = ["S", "M", "L", "Full"]
        let idx = list.indexOf(sizePreset)
        let next = (idx === -1 || idx === list.length - 1) ? list[0] : list[idx + 1]
        setPreset(next)
    }

    function sizeLabel() {
        let tag = sizePreset === "custom" ? "Cust" : sizePreset
        let isNarrow = (typeof card !== "undefined" && card) ? card.width < Style.space(680) : false
        return isNarrow ? ("󰹍 " + tag) : ("Size: " + tag)
    }

    function applyCustomSize(w, h) {
        let isPortrait = (typeof card !== "undefined" && card) ? card.portrait : (panel.screen ? panel.screen.height > panel.screen.width : false)
        let minW = (typeof card !== "undefined" && card) ? card.minWidth : (isPortrait ? Style.space(460) : Style.space(520))
        let maxW = (typeof card !== "undefined" && card) ? card.maxWidth : Math.max(minW, (panel.screen ? panel.screen.width : panel.width) - Style.spacing.popupPadding * 2)
        let minH = (typeof card !== "undefined" && card) ? card.minHeight : Style.space(280)
        let maxH = (typeof card !== "undefined" && card) ? card.maxHeight : Math.max(minH, Math.round((panel.screen ? panel.screen.height : panel.height) * 0.65))

        if (isPortrait) {
            customWidthPortrait = Math.max(minW, Math.min(maxW, Math.round(w)))
            customHeightPortrait = Math.max(minH, Math.min(maxH, Math.round(h)))
        } else {
            customWidthLandscape = Math.max(minW, Math.min(maxW, Math.round(w)))
            customHeightLandscape = Math.max(minH, Math.min(maxH, Math.round(h)))
        }
        sizePreset = "custom"
        scheduleSave()
    }

    function targetWidth() {
        let isPortrait = (typeof card !== "undefined" && card) ? card.portrait : (panel.screen ? panel.screen.height > panel.screen.width : false)
        let minW = (typeof card !== "undefined" && card) ? card.minWidth : (isPortrait ? Style.space(460) : Style.space(520))
        let maxW = (typeof card !== "undefined" && card) ? card.maxWidth : Math.max(minW, (panel.screen ? panel.screen.width : panel.width) - Style.spacing.popupPadding * 2)

        if (isPortrait) {
            if (sizePreset === "custom" && customWidthPortrait > 0) {
                return Math.max(minW, Math.min(maxW, customWidthPortrait))
            }
            switch (sizePreset) {
            case "S":
                return Math.min(maxW, Style.space(480))
            case "L":
                return Math.min(maxW, Style.space(780))
            case "Full":
                return maxW
            case "M":
            default:
                return Math.min(maxW, Style.space(620))
            }
        } else {
            if (sizePreset === "custom" && customWidthLandscape > 0) {
                return Math.max(minW, Math.min(maxW, customWidthLandscape))
            }
            switch (sizePreset) {
            case "S":
                return Math.min(maxW, Style.space(640))
            case "L":
                return Math.min(maxW, Style.space(1240))
            case "Full":
                return maxW
            case "M":
            default:
                return Math.min(maxW, Style.space(960))
            }
        }
    }

    function targetHeight() {
        let isPortrait = (typeof card !== "undefined" && card) ? card.portrait : (panel.screen ? panel.screen.height > panel.screen.width : false)
        let minH = (typeof card !== "undefined" && card) ? card.minHeight : Style.space(280)
        let maxH = (typeof card !== "undefined" && card) ? card.maxHeight : Math.max(minH, Math.round((panel.screen ? panel.screen.height : panel.height) * 0.65))

        if (isPortrait) {
            if (sizePreset === "custom" && customHeightPortrait > 0) {
                return Math.max(minH, Math.min(maxH, customHeightPortrait))
            }
            switch (sizePreset) {
            case "S":
                return Math.min(maxH, Style.space(380))
            case "L":
                return Math.min(maxH, Style.space(600))
            case "Full":
                return Math.min(maxH, Style.space(520))
            case "M":
            default:
                return Math.min(maxH, Style.space(500))
            }
        } else {
            if (sizePreset === "custom" && customHeightLandscape > 0) {
                return Math.max(minH, Math.min(maxH, customHeightLandscape))
            }
            switch (sizePreset) {
            case "S":
                return Math.min(maxH, Style.space(340))
            case "L":
                return Math.min(maxH, Style.space(540))
            case "Full":
                return Math.min(maxH, Style.space(480))
            case "M":
            default:
                return Math.min(maxH, Style.space(460))
            }
        }
    }

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
    readonly property var evdevKeyCodes: ({
        "Escape": 1,
        "1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9, "9": 10, "0": 11,
        "-": 12, "=": 13, "BackSpace": 14, "Tab": 15,
        "q": 16, "w": 17, "e": 18, "r": 19, "t": 20, "y": 21, "u": 22, "i": 23, "o": 24, "p": 25,
        "[": 26, "]": 27, "Return": 28,
        "a": 30, "s": 31, "d": 32, "f": 33, "g": 34, "h": 35, "j": 36, "k": 37, "l": 38,
        ";": 39, "'": 40, "`": 41, "\\": 43,
        "z": 44, "x": 45, "c": 46, "v": 47, "b": 48, "n": 49, "m": 50,
        ",": 51, ".": 52, "/": 53, "space": 57,
        "F1": 59, "F2": 60, "F3": 61, "F4": 62, "F5": 63, "F6": 64,
        "F7": 65, "F8": 66, "F9": 67, "F10": 68, "F11": 87, "F12": 88,
        "Print": 99, "Home": 102, "Up": 103, "Page_Up": 104, "Left": 105,
        "Right": 106, "End": 107, "Down": 108, "Page_Down": 109, "Insert": 110, "Delete": 111
    })
    readonly property var shiftedEvdevKeyCodes: ({
        "!": 2, "@": 3, "#": 4, "$": 5, "%": 6, "^": 7, "&": 8, "*": 9, "(": 10, ")": 11,
        "_": 12, "+": 13, "{": 26, "}": 27, ":": 39, "\"": 40,
        "~": 41, "|": 43, "<": 51, ">": 52, "?": 53
    })

    function dispatchSuperKey(keysym) {
        let code = evdevKeyCodes[keysym]
        let impliedShift = false
        if (code === undefined) {
            code = shiftedEvdevKeyCodes[keysym]
            impliedShift = code !== undefined
        }
        if (code === undefined) {
            console.warn("omaqwerty: no evdev mapping for Super chord:", keysym)
            return
        }

        let modifiers = []
        if (ctrl) modifiers.push(29)
        if (alt) modifiers.push(56)
        modifiers.push(125)
        if (shift || impliedShift) modifiers.push(42)

        let cmd = ["ydotool", "key"]
        for (let i = 0; i < modifiers.length; i++) cmd.push(modifiers[i] + ":1")
        cmd.push(code + ":1", code + ":0")
        for (let i = modifiers.length - 1; i >= 0; i--) cmd.push(modifiers[i] + ":0")
        enqueue(cmd)
    }


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
        if (root.sizePopupOpen) root.sizePopupOpen = false
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
        if (superKey) {
            dispatchSuperKey(keysym)
        } else {
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
        }
        clearSingleModifiers()
    }

    function dispatchChar(character) {
        if (ctrl || alt || superKey) {
            dispatchKey(character.toLowerCase())
            return
        }

        let charToType = character
        if (shift) {
            if (/^[a-z]$/.test(charToType)) {
                charToType = charToType.toUpperCase()
            } else if (shiftSymbolMap[charToType]) {
                charToType = shiftSymbolMap[charToType]
            }
        }
        enqueue(["wtype", "--", charToType])
        clearSingleModifiers()
    }

    function open(payloadJson) {
        opened = true
        sizePopupOpen = false
        if (root.isDocked) {
            dock()
        } else {
            if (root.floatingX >= 0 && root.floatingY >= 0) {
                card.x = root.floatingX
                card.y = root.floatingY
                clampPosition()
            } else {
                clampPosition()
            }
        }
    }

    function close() {
        sizePopupOpen = false
        opened = false
    }

    function toggle() {
        if (opened) close()
        else open()
    }

    function dock() {
        root.isDocked = true
        root.sizePopupOpen = false
        card.x = Math.round((panel.width - card.width) / 2)
        card.y = Style.spacing.lg
        scheduleSave()
    }

    function undock() {
        if (!root.isDocked) return
        root.isDocked = false
        root.sizePopupOpen = false
        let screenH = panel.screen ? panel.screen.height : panel.height
        let screenW = panel.screen ? panel.screen.width : panel.width
        if (root.floatingX >= 0 && root.floatingY >= 0) {
            card.x = root.floatingX
            card.y = root.floatingY
            clampPosition()
        } else {
            card.x = Math.round((screenW - card.width) / 2)
            card.y = Math.max(0, screenH - card.height - Style.spacing.lg)
        }
        scheduleSave()
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
        } else {
            root.floatingX = card.x
            root.floatingY = card.y
            scheduleSave()
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
            readonly property real minWidth: portrait ? Style.space(460) : Style.space(520)
            readonly property real maxWidth: Math.max(minWidth, (panel.screen ? panel.screen.width : panel.width) - Style.spacing.popupPadding * 2)
            readonly property real minHeight: Style.space(280)
            readonly property real maxHeight: Math.max(minHeight, Math.round((panel.screen ? panel.screen.height : panel.height) * 0.65))

            readonly property int dragBarHeight: Math.max(Style.space(20), Math.min(Style.space(26), Math.round(height * 0.055)))
            readonly property int headerHeight: Math.max(Style.space(34), Math.min(Style.space(42), Math.round(height * 0.09)))
            readonly property int rowSpacing: Math.max(Style.spacing.xxs, Math.min(Style.spacing.sm, Math.round(height * 0.01)))
            readonly property int cardMargin: Math.max(Style.spacing.xs, Math.min(Style.spacing.md, Math.round(height * 0.025)))
            readonly property real availableKeyHeight: height - cardMargin * 2 - dragBarHeight - headerHeight - rowSpacing * 5
            readonly property real rowHeight: Math.max(Style.space(38), Math.floor(availableKeyHeight / 4))

            readonly property int keyFontSize: Math.max(12, Math.min(22, Math.round(rowHeight * 0.32)))
            readonly property int keySubFontSize: Math.max(9, Math.min(12, Math.round(rowHeight * 0.18)))
            readonly property int navFontSize: Math.max(11, Math.min(14, Math.round(headerHeight * 0.33)))
            readonly property int navKeyMinWidth: Math.max(Style.space(44), Math.min(Style.space(56), Math.round(width * 0.055)))

            width: root.targetWidth()
            height: root.targetHeight()

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


                        onTranslationChanged: {
                            if (!active) return
                            let screenW = panel.screen ? panel.screen.width : panel.width
                            let screenH = panel.screen ? panel.screen.height : panel.height
                            let targetX = startCardX + translation.x
                            let targetY = startCardY + translation.y
                            card.x = Math.max(0, Math.min(targetX, screenW - card.width))
                            card.y = Math.max(0, Math.min(targetY, screenH - card.height))
                        }

                        onActiveChanged: {
                            if (active) {
                                root.sizePopupOpen = false
                                if (root.isDocked) root.undock()
                                startCardX = card.x
                                startCardY = card.y
                            } else {
                                root.checkSnapToDock()
                            }
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
                        text: {
                            if (card.width < Style.space(620)) {
                                return root.isDocked ? "󰌌 Drag to undock" : "󰌌 Drag to move"
                            }
                            return root.isDocked
                                ? "󰌌 Drag bar to move · Drag borders to resize"
                                : "󰌌 Drag bar to move · 2x-tap to dock · Drag borders to resize"
                        }
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: Style.spacing.xs
                            verticalCenter: parent.verticalCenter
                        }
                        visible: card.width >= Style.space(640)
                        text: Math.round(card.width) + "×" + Math.round(card.height)
                        color: Util.alpha(Color.muted, 0.6)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }

                // Header row: Navigation / Function keys on left, Tool launchers on right
                Item {
                    id: headerRow
                    width: parent.width
                    height: card.headerHeight

                    Row {
                        id: tools
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: card.rowSpacing

                        Repeater {
                            model: [
                                { label: root.page === "numpad" ? (card.width < Style.space(640) ? "ABC" : "QWERTY") : (card.width < Style.space(640) ? "Num" : "Numpad"), action: root.page === "numpad" ? "letters" : "numpad" },
                                { label: card.width < Style.space(640) ? "Clip" : "Clipboard", action: "clipboard" },
                                { label: card.width < Style.space(640) ? "Pad" : "Trackpad", action: "trackpad" },
                                { label: root.sizeLabel(), action: "size", isSize: true },
                                { label: root.isDocked ? "Float" : "Dock", action: root.isDocked ? "undock" : "dock" },
                                { label: "✕", action: "close" }
                            ]
                            delegate: Rectangle {
                                id: toolRect
                                required property var modelData
                                property bool isSizeActive: toolRect.modelData && !!toolRect.modelData.isSize && root.sizePopupOpen
                                implicitWidth: toolLabel.implicitWidth + Style.spacing.md * 2
                                width: implicitWidth
                                implicitHeight: parent ? parent.height : 0
                                height: parent ? parent.height : 0
                                radius: Style.cornerRadius
                                color: {
                                    if (toolRect.modelData && toolRect.modelData.action === "close" && toolTap.pressed) return Color.urgent
                                    if (isSizeActive || toolTap.pressed) return Color.accent
                                    return Util.alpha(Color.foreground, Style.normalFillAlpha)
                                }
                                border.color: isSizeActive ? Color.accent : Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                border.width: isSizeActive ? 2 : Style.normalBorderWidth

                                Text {
                                    id: toolLabel
                                    anchors.centerIn: parent
                                    text: toolRect.modelData ? toolRect.modelData.label : ""
                                    color: Color.foreground
                                    font.family: Style.font.family
                                    font.pixelSize: card.navFontSize
                                    font.bold: toolRect.isSizeActive
                                }

                                MouseArea {
                                    id: toolTap
                                    anchors.fill: parent
                                    onClicked: {
                                        if (!toolRect.modelData) return
                                        if (toolRect.modelData.action === "size") {
                                            root.sizePopupOpen = !root.sizePopupOpen
                                        } else {
                                            root.sizePopupOpen = false
                                            if (toolRect.modelData.action === "close") root.close()
                                            else if (toolRect.modelData.action === "dock") root.dock()
                                            else if (toolRect.modelData.action === "undock") root.undock()
                                            else if (toolRect.modelData.action === "numpad") { root.page = "numpad"; if (!root.shiftLocked) root.shift = false }
                                            else if (toolRect.modelData.action === "letters") { root.page = "abc"; if (!root.shiftLocked) root.shift = false }
                                            else if (toolRect.modelData.action === "clipboard") root.enqueue(["omarchy-shell", "shell", "toggle", "omarchy.clipboard"])
                                            else root.enqueue(["omarchy-shell", "shell", "toggle", "io.github.frostmute.onscreen-trackpad"])
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (toolRect.modelData && toolRect.modelData.action === "size") {
                                            root.cyclePreset()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        id: navigation
                        anchors.left: parent.left
                        anchors.right: tools.left
                        anchors.rightMargin: card.rowSpacing
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
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
                                    implicitWidth: Math.max(card.navKeyMinWidth, navLabel.implicitWidth + Style.spacing.md * 2)
                                    width: implicitWidth
                                    implicitHeight: parent ? parent.height : 0
                                    height: parent ? parent.height : 0
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
                                        font.pixelSize: card.navFontSize
                                    }

                                    MouseArea {
                                        id: navTap
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.sizePopupOpen) root.sizePopupOpen = false
                                            if (navRect.modelData) root.press(navRect.modelData)
                                        }
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
                                                font.pixelSize: keyRect.key && keyRect.key.action === "space" ? Math.round(card.keyFontSize * 0.9) : card.keyFontSize
                                                font.bold: keyRect.shiftActive
                                            }

                                            Text {
                                                visible: keyRect.isShiftKey && root.shiftLocked
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "CAPS"
                                                color: Color.foreground
                                                font.family: Style.font.family
                                                font.pixelSize: card.keySubFontSize
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            id: tap
                                            anchors.fill: parent
                                            onClicked: {
                                                if (root.sizePopupOpen) root.sizePopupOpen = false
                                                if (keyRect.modelData) root.press(keyRect.modelData)
                                            }
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
                                    font.pixelSize: bottomKeyRect.key && (bottomKeyRect.key.action === "space" || bottomKeyRect.key.action === "enter") ? Math.round(card.keyFontSize * 1.1) : (card.keySubFontSize + 3)
                                    font.bold: bottomKeyRect.isHighlighted
                                }

                                Text {
                                    visible: bottomKeyRect.key && (!!bottomKeyRect.key.locked || (!!bottomKeyRect.key.sublabel && !bottomKeyRect.key.locked))
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bottomKeyRect.key ? (bottomKeyRect.key.locked ? "LOCK" : (bottomKeyRect.key.sublabel || "")) : ""
                                    color: bottomKeyRect.key && bottomKeyRect.key.locked ? Color.foreground : Color.muted
                                    font.family: Style.font.family
                                    font.pixelSize: card.keySubFontSize
                                    font.bold: bottomKeyRect.key && !!bottomKeyRect.key.locked
                                }
                            }

                            MouseArea {
                                id: bottomTap
                                anchors.fill: parent
                                onClicked: {
                                    if (root.sizePopupOpen) root.sizePopupOpen = false
                                    if (bottomKeyRect.modelData) root.press(bottomKeyRect.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Dismiss area when size popup is open
            MouseArea {
                anchors.fill: parent
                visible: root.sizePopupOpen
                z: 90
                onClicked: root.sizePopupOpen = false
            }

            // Size Selection Popover Menu
            BorderSurface {
                id: sizePopup
                visible: root.sizePopupOpen
                anchors {
                    top: parent.top
                    topMargin: card.cardMargin + card.dragBarHeight + card.headerHeight + card.rowSpacing
                    right: parent.right
                    rightMargin: card.cardMargin
                }
                width: Math.min(parent.width - card.cardMargin * 2, Style.space(340))
                height: sizePopupCol.implicitHeight + Style.spacing.md * 2
                z: 100
                radius: Style.cornerRadius
                color: Color.popups.background
                borderSpec: Border.hyprlandActiveSpec(Color.accent, 2)

                Column {
                    id: sizePopupCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Style.spacing.md
                    }
                    spacing: Style.spacing.sm

                    // Header row with dimensions and close button
                    Item {
                        width: parent.width
                        height: Style.space(24)

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Keyboard Size"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }

                        Rectangle {
                            anchors.right: closePopupBtn.left
                            anchors.rightMargin: Style.spacing.xs
                            anchors.verticalCenter: parent.verticalCenter
                            height: Style.space(20)
                            width: sizeDimLabel.implicitWidth + Style.spacing.sm * 2
                            radius: Style.space(4)
                            color: Util.alpha(Color.foreground, Style.normalFillAlpha)

                            Text {
                                id: sizeDimLabel
                                anchors.centerIn: parent
                                text: Math.round(card.width) + " × " + Math.round(card.height)
                                color: Color.muted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Rectangle {
                            id: closePopupBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(22)
                            height: Style.space(22)
                            radius: Style.cornerRadius
                            color: closePopupArea.pressed ? Color.urgent : Util.alpha(Color.foreground, Style.normalFillAlpha)

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            MouseArea {
                                id: closePopupArea
                                anchors.fill: parent
                                onClicked: root.sizePopupOpen = false
                            }
                        }
                    }

                    // Presets: S, M, L, Full
                    Row {
                        width: parent.width
                        height: Style.space(42)
                        spacing: Style.spacing.xs

                        Repeater {
                            model: [
                                { id: "S", name: "S", desc: "Compact" },
                                { id: "M", name: "M", desc: "Standard" },
                                { id: "L", name: "L", desc: "Large" },
                                { id: "Full", name: "Full", desc: "Max" }
                            ]
                            delegate: Rectangle {
                                id: pBtn
                                required property var modelData
                                property bool isSelected: root.sizePreset === pBtn.modelData.id
                                width: Math.floor((parent.width - Style.spacing.xs * 3) / 4)
                                height: parent.height
                                radius: Style.cornerRadius
                                color: isSelected ? Color.accent : (pTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha))
                                border.color: isSelected ? Color.accent : Util.alpha(Color.foreground, Style.pressedFillAlpha)
                                border.width: isSelected ? 2 : Style.normalBorderWidth

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: pBtn.modelData.name
                                        color: Color.foreground
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: pBtn.modelData.desc
                                        color: pBtn.isSelected ? Color.foreground : Color.muted
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                    }
                                }

                                MouseArea {
                                    id: pTap
                                    anchors.fill: parent
                                    onClicked: {
                                        root.setPreset(pBtn.modelData.id)
                                        root.sizePopupOpen = false
                                    }
                                }
                            }
                        }
                    }

                    // Reset button when custom resized
                    Rectangle {
                        visible: root.sizePreset === "custom"
                        width: parent.width
                        height: Style.space(30)
                        radius: Style.cornerRadius
                        color: resetBtnTap.pressed ? Color.accent : Util.alpha(Color.foreground, Style.normalFillAlpha)
                        border.color: Util.alpha(Color.foreground, Style.pressedFillAlpha)
                        border.width: Style.normalBorderWidth

                        Text {
                            anchors.centerIn: parent
                            text: "↺ Reset to Standard (M)"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }

                        MouseArea {
                            id: resetBtnTap
                            anchors.fill: parent
                            onClicked: {
                                root.setPreset("M")
                                root.sizePopupOpen = false
                            }
                        }
                    }

                    // Helper tip
                    Text {
                        width: parent.width
                        text: "󰩨 Drag borders or corners to freely resize"
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // --- Interactive Drag Resize Handles ---
            // Top Edge Resize
            Item {
                id: topResize
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(28)
                anchors.rightMargin: Style.space(28)
                height: Style.space(8)
                z: 20

                DragHandler {
                    id: topDrag
                    target: null
                    property real startH: 0
                    property real startY: 0
                    onActiveChanged: {
                        if (active) {
                            startH = card.height
                            startY = card.y
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let newH = Math.max(card.minHeight, Math.min(card.maxHeight, startH - translation.y))
                        if (root.isDocked) {
                            root.applyCustomSize(card.width, newH)
                        } else {
                            let actualDeltaH = newH - startH
                            let newY = Math.max(0, startY - actualDeltaH)
                            root.applyCustomSize(card.width, newH)
                            card.y = newY
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Bottom Edge Resize (active when floating)
            Item {
                id: bottomResize
                visible: !root.isDocked
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(28)
                anchors.rightMargin: Style.space(28)
                height: Style.space(8)
                z: 20

                DragHandler {
                    id: bottomDrag
                    target: null
                    property real startH: 0
                    onActiveChanged: {
                        if (active) {
                            startH = card.height
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let screenH = panel.screen ? panel.screen.height : panel.height
                        let maxH = Math.min(card.maxHeight, screenH - card.y)
                        let newH = Math.max(card.minHeight, Math.min(maxH, startH + translation.y))
                        root.applyCustomSize(card.width, newH)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Right Edge Resize
            Item {
                id: rightResize
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.topMargin: Style.space(28)
                anchors.bottomMargin: Style.space(28)
                width: Style.space(8)
                z: 20

                DragHandler {
                    id: rightDrag
                    target: null
                    property real startW: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let screenW = panel.screen ? panel.screen.width : panel.width
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, screenW - card.x)
                        let newW = Math.max(card.minWidth, Math.min(maxW, startW + translation.x))
                        root.applyCustomSize(newW, card.height)
                        if (root.isDocked) card.x = Math.round((panel.width - card.width) / 2)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Left Edge Resize
            Item {
                id: leftResize
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.topMargin: Style.space(28)
                anchors.bottomMargin: Style.space(28)
                width: Style.space(8)
                z: 20

                DragHandler {
                    id: leftDrag
                    target: null
                    property real startW: 0
                    property real startX: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                            startX = card.x
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, startX + startW)
                        let desiredW = startW - translation.x
                        let newW = Math.max(card.minWidth, Math.min(maxW, desiredW))
                        let actualDeltaW = newW - startW
                        root.applyCustomSize(newW, card.height)
                        if (root.isDocked) {
                            card.x = Math.round((panel.width - card.width) / 2)
                        } else {
                            card.x = Math.max(0, startX - actualDeltaW)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Bottom-Right Corner Resize & Visual Grip
            Item {
                id: brCorner
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Style.space(28)
                height: Style.space(28)
                z: 25

                DragHandler {
                    id: brDrag
                    target: null
                    property real startW: 0
                    property real startH: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                            startH = card.height
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let screenW = panel.screen ? panel.screen.width : panel.width
                        let screenH = panel.screen ? panel.screen.height : panel.height
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, screenW - card.x)
                        let maxH = root.isDocked ? card.maxHeight : Math.min(card.maxHeight, screenH - card.y)
                        let newW = Math.max(card.minWidth, Math.min(maxW, startW + translation.x))
                        let newH = Math.max(card.minHeight, Math.min(maxH, startH + translation.y))
                        root.applyCustomSize(newW, newH)
                        if (root.isDocked) card.x = Math.round((panel.width - card.width) / 2)
                    }
                }

                MouseArea {
                    id: brHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeFDiagCursor
                    acceptedButtons: Qt.NoButton
                }

                // Subtle diagonal dot grip
                Item {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.space(5)
                    width: Style.space(12)
                    height: Style.space(12)
                    opacity: brDrag.active ? 1.0 : (brHover.containsMouse ? 0.9 : 0.4)
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Row {
                            anchors.right: parent.right
                            spacing: 2
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 2
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 2
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                            Rectangle { width: 2; height: 2; radius: 1; color: brDrag.active ? Color.accent : Color.foreground }
                        }
                    }
                }
            }

            // Bottom-Left Corner Resize
            Item {
                id: blCorner
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Style.space(28)
                height: Style.space(28)
                z: 25

                DragHandler {
                    id: blDrag
                    target: null
                    property real startW: 0
                    property real startH: 0
                    property real startX: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                            startH = card.height
                            startX = card.x
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let screenH = panel.screen ? panel.screen.height : panel.height
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, startX + startW)
                        let maxH = root.isDocked ? card.maxHeight : Math.min(card.maxHeight, screenH - card.y)
                        let desiredW = startW - translation.x
                        let newW = Math.max(card.minWidth, Math.min(maxW, desiredW))
                        let actualDeltaW = newW - startW
                        let newH = Math.max(card.minHeight, Math.min(maxH, startH + translation.y))
                        root.applyCustomSize(newW, newH)
                        if (root.isDocked) {
                            card.x = Math.round((panel.width - card.width) / 2)
                        } else {
                            card.x = Math.max(0, startX - actualDeltaW)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeBDiagCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Top-Right Corner Resize
            Item {
                id: trCorner
                anchors.right: parent.right
                anchors.top: parent.top
                width: Style.space(28)
                height: Style.space(28)
                z: 25

                DragHandler {
                    id: trDrag
                    target: null
                    property real startW: 0
                    property real startH: 0
                    property real startY: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                            startH = card.height
                            startY = card.y
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let screenW = panel.screen ? panel.screen.width : panel.width
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, screenW - card.x)
                        let newW = Math.max(card.minWidth, Math.min(maxW, startW + translation.x))
                        let desiredH = startH - translation.y
                        let newH = Math.max(card.minHeight, Math.min(card.maxHeight, desiredH))
                        let actualDeltaH = newH - startH
                        root.applyCustomSize(newW, newH)
                        if (root.isDocked) {
                            card.x = Math.round((panel.width - card.width) / 2)
                        } else {
                            card.y = Math.max(0, startY - actualDeltaH)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeBDiagCursor
                    acceptedButtons: Qt.NoButton
                }
            }

            // Top-Left Corner Resize
            Item {
                id: tlCorner
                anchors.left: parent.left
                anchors.top: parent.top
                width: Style.space(28)
                height: Style.space(28)
                z: 25

                DragHandler {
                    id: tlDrag
                    target: null
                    property real startW: 0
                    property real startH: 0
                    property real startX: 0
                    property real startY: 0
                    onActiveChanged: {
                        if (active) {
                            startW = card.width
                            startH = card.height
                            startX = card.x
                            startY = card.y
                        } else {
                            root.scheduleSave()
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        let maxW = root.isDocked ? card.maxWidth : Math.min(card.maxWidth, startX + startW)
                        let desiredW = startW - translation.x
                        let newW = Math.max(card.minWidth, Math.min(maxW, desiredW))
                        let actualDeltaW = newW - startW
                        let desiredH = startH - translation.y
                        let newH = Math.max(card.minHeight, Math.min(card.maxHeight, desiredH))
                        let actualDeltaH = newH - startH
                        root.applyCustomSize(newW, newH)
                        if (root.isDocked) {
                            card.x = Math.round((panel.width - card.width) / 2)
                        } else {
                            card.x = Math.max(0, startX - actualDeltaW)
                            card.y = Math.max(0, startY - actualDeltaH)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeFDiagCursor
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
