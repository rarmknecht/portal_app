# portal-app

**A mini Plex that operates within your local network or tailnet, no subscription fees, no data collected by third-parties.**

Portal is the Android companion app for the [portal](https://github.com/rarmknecht/portal) media server. It discovers your portal agent on the local network, lets you browse your media libraries, and streams video, audio, and photos directly to your phone.

---

## Features

- **Auto-discovery** — finds the portal agent on your network via mDNS, no IP address needed
- **Manual connect** — enter host, port, and optional token for Tailscale or non-local setups
- **Browse** — navigate your media libraries as folder trees, sort by name, date, or size
- **Video** — hardware-accelerated streaming via ExoPlayer
- **Audio** — background playback with lock-screen controls
- **Photos** — pinch-zoom viewer with swipe navigation through the folder
- **Search** — filename search within any library

---

## Requirements

- Android 6.0 (API 23) or newer
- A running [portal](https://github.com/rarmknecht/portal) agent on your network or tailnet

---

## Building from source

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.11+).

```bash
git clone https://github.com/rarmknecht/portal-app
cd portal-app
flutter pub get
flutter run          # connected device or emulator
flutter build apk    # release APK → build/app/outputs/flutter-apk/
```

---

## Connecting to your agent

### Auto-discovery (LAN)

Launch the app. If the portal agent is on the same network, it will appear in the **Found on network** list automatically. Tap it, enter your token if the agent has one set, and connect.

### Manual connect (Tailscale or static IP)

Tap **Connect manually**, enter the host or IP address and port (default `7842`), and optionally a token. The app remembers the connection for next time.

### Token

If you configured an `api_token` in the portal agent, enter it in the Token field when connecting. Leave it blank if the agent has no token set.

---

## Disconnect / switch server

Tap the **→|** icon in the top-right corner of the Libraries screen to disconnect. The app clears the saved connection and returns to the discovery screen.

---

## Supported formats

Playback depends on what Android supports natively via ExoPlayer.

| Type   | Works reliably                  |
|--------|---------------------------------|
| Video  | H.264, H.265 in MP4 / MOV      |
| Audio  | AAC, MP3, FLAC                  |
| Photos | JPEG, PNG                       |

---

## License

[MIT](LICENSE)
