# portal-app

**A mini Plex that operates within your local network or tailnet, no subscription fees, no data collected by third-parties.**

Portal is the Android companion app for the [portal](https://github.com/rarmknecht/portal) media server. It discovers your portal agent on the local network, lets you browse your media libraries, and streams video, audio, and photos directly to your phone.

---

## Features

- **Auto-discovery** — finds the portal agent on your network via mDNS, no IP address needed
- **Manual connect** — enter host, port, and optional token for Tailscale or non-local setups
- **Saved connections** — every server you have connected to becomes a tile; tap to reconnect
- **Browse** — navigate your media libraries as folder trees, sort by name, date, or size, as a list or a thumbnail grid
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

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.47 or newer (Dart 3.12+).

```bash
git clone https://github.com/rarmknecht/portal-app
cd portal-app
flutter pub get
flutter run          # connected device or emulator
flutter build apk    # release APK → build/app/outputs/flutter-apk/
```

### Release builds

Release APKs are signed with a keystore kept **outside** the repository. Create
one and point `android/key.properties` (gitignored) at it:

```bash
keytool -genkeypair -keystore ~/.config/portal-app/release-keystore.jks \
  -storetype PKCS12 -alias portal-release -keyalg RSA -keysize 4096 -validity 10000
```

```properties
storeFile=/home/you/.config/portal-app/release-keystore.jks
storePassword=...
keyPassword=...
keyAlias=portal-release
```

Without `key.properties`, `flutter build apk` falls back to the debug key and
prints a warning. Back the keystore up: Android will not install an update
signed with a different key over an existing install.

---

## Connecting to your agent

### Auto-discovery (LAN)

Launch the app. If the portal agent is on the same network, it will appear in the **Found on network** list automatically. Tap it, enter your token if the agent has one set, and connect.

### Manual connect (Tailscale or static IP)

Tap **Connect manually**, enter the host or IP address and port (default `7842`), and optionally a token. The app remembers the connection for next time.

The host field also accepts a full URL such as `https://portal.example.ts.net`
or `http://10.0.0.5:7842`. Use an `https://` URL when a TLS-terminating proxy
(for example Tailscale Serve) fronts the agent; the token then travels only
inside the encrypted tunnel.

### Token

If you configured an `api_token` in the portal agent, enter it in the Token field when connecting. Leave it blank if the agent has no token set.

The token is sent as an `Authorization: Bearer` header on every request,
including video, audio, and thumbnail streams, so it never appears in a URL.
On the device it is stored in Android Keystore-backed secure storage, and the
app opts out of Android cloud backup and device-to-device transfer.

---

## Saved connections

Once a connection succeeds it appears under **Saved connections** on the start screen. Tap the tile to reconnect without retyping anything. The tile's menu offers **Edit token**, which pre-fills the manual form so you can enter a new token for the same server, and **Forget**, which removes the connection and its token from the phone.

At launch the app tries the most recently used connection automatically and goes straight to your libraries if the agent answers.

## Disconnect / switch server

Tap the **→|** icon in the top-right corner of the Libraries screen to disconnect. The connection stays saved as a tile; the app just stops auto-connecting to it and returns to the start screen.

## List and grid view

The grid icon in the folder view switches between the detailed list and a grid of thumbnails. Folders and files without a thumbnail show an icon and name in the grid. The choice is remembered.

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
