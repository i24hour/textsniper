# TextSnipper

A free, open-source menu-bar app for Mac. Select any text on your screen — a video, PDF, image, slide, or webpage — and it is copied to the clipboard.

Text recognition uses Apple’s on-device Vision framework. Captures stay on your Mac.

This project is not affiliated with the commercial TextSniper app.

## Install

You need a Mac on macOS 14 or newer, plus the Xcode Command Line Tools.

```bash
xcode-select --install
git clone https://github.com/i24hour/textsniper.git
cd textsniper
chmod +x build.sh
./build.sh
```

`./build.sh` compiles the app, installs it to `~/Applications/TextSnipper.app`, and opens it. A text-viewfinder icon appears in the menu bar.

## Use

1. Press **⌘⇧2**.
2. Drag a box around the text.
3. Paste with **⌘V**.

The first capture asks for Screen Recording permission. Allow **TextSnipper**, then press **⌘⇧2** again.

Press **Esc** to cancel. A click that is too small to be a selection also cancels.

From the menu-bar icon:

- **Keep Line Breaks** — on copies the original lines; off joins them into one paragraph
- **Change Shortcut…** — pick another global shortcut (it must include ⌘, ⌥, or ⌃)
- **Quit TextSnipper**

To have it ready after a restart, add `~/Applications/TextSnipper.app` in System Settings → General → Login Items.

## Rebuild

From this folder:

```bash
./build.sh
```

## License

[MIT](LICENSE)
