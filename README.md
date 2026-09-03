# D2Manager

A macOS menu bar app for managing local DHIS2 Docker instances through
[`d2-broker`](docs/broker-api.md).

`d2-broker` is a small HTTP service that wraps the `d2-*` shell scripts used to
run DHIS2 in Docker on a developer machine. It does the work; D2Manager is a
front end for it, so that creating a 2.42 instance from a seed database, or
resetting one that you have broken, is a couple of clicks rather than a
remembered command line.

The app is not part of DHIS2 itself and is not a supported DHIS2 product. It is
a local development utility.

## What it does

The menu bar icon opens a list of your instances with their state, port, and
DHIS2 major version. From there you can:

- create an instance (version, seed database, Tomcat and analytics options,
  heap size, explicit ports, or a custom WAR)
- start, stop, and delete instances
- reset an instance back to a seed
- back up an instance to a new seed, and restore from one
- upgrade an instance to another DHIS2 version
- change the Tomcat heap of an existing instance
- watch the running job, and read the log of a job that failed

Long operations run as broker jobs. The app polls them and shows progress in
the menu, so the popover can be closed while an upgrade runs.

## Requirements

- macOS 26 or later. The UI uses the Liquid Glass APIs introduced in macOS 26,
  so it will not build against an older SDK.
- Swift 6.0 toolchain (Xcode 26).
- A running `d2-broker`, reachable on `http://localhost:9300` by default.
  D2Manager talks to nothing else — no network access beyond that host.

## Build and install

1. Build the app bundle:

   ```
   ./make-app.sh
   ```

   The script builds a release binary and assembles `D2Manager.app`. The bundle
   is marked `LSUIElement`, so the app has no Dock icon and no main window.

2. Move `D2Manager.app` to `/Applications`.

3. Add it to Login Items if you want it to start with the machine.

For development, `swift run` starts the app directly and `swift test` runs the
test suite.

## Configuration

Open **Settings** from the menu. Three fields:

- **Broker base URL** — defaults to `http://localhost:9300`.
- **DHIS2_BASE path** — the directory holding `_broker/tokens.json`. If it is
  blank, the app falls back to the `DHIS2_BASE` environment variable.
- **Admin token override** — paste a token directly instead of reading the
  file.

Settings apply after a relaunch.

The app authenticates to the broker with the **admin** token. It reads the
token from `tokens.json` on disk by default; nothing is stored in the app in
that case. If you use the override field instead, the token is written to the
app's `UserDefaults` in plain text (`~/Library/Preferences/`), not to the
Keychain. On a single-user development machine that is the same exposure as
the `tokens.json` file itself, but prefer the file path if you care about the
difference.

## Layout

```
Sources/D2Manager/
  Models/       Codable types for the broker's JSON
  Networking/   BrokerClient and its protocol
  Services/     Job polling, admin token resolution
  State/        AppModel (all app state), persisted settings
  Views/        SwiftUI menu bar UI
Tests/          Unit tests over a fake broker and a mocked URLProtocol
docs/           Broker API reference and design notes
```

`docs/broker-api.md` documents the broker endpoints this client is built
against. `docs/proposed-broker-endpoints.md` records endpoints proposed to the
broker while this app was written; parts of it are now implemented.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
