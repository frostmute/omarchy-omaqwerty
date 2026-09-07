# Omaqwerty for Omarchy

![Omaqwerty preview](preview.png)

**Omaqwerty** is a docked, touch-first keyboard for Omarchy tablets. It reserves screen space while open, so tiled windows are not obscured. It is part of the optional **Omablet** suite but installs independently.

Features include a large QWERTY layout, numbers and symbols, a touch numpad, navigation keys, clipboard and Omaglide launchers, and mouse-click fallback.

## Omablet suite

Omaqwerty also works independently. Pair it with [Omablet](https://github.com/frostmute/omarchy-omablet) for tablet-mode controls and [Omaglide](https://github.com/frostmute/omarchy-omaglide) for a touch trackpad.

## Install

```sh
omarchy plugin add https://github.com/frostmute/omarchy-omaqwerty.git --enable
```

Requires `wtype` for keyboard injection:

```sh
omarchy pkg add wtype
```

## Remove

```sh
omarchy plugin remove io.github.frostmute.tablet-keyboard
```

## License

MIT
