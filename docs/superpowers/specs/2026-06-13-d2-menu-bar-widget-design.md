# Design: macOS menu bar widget for managing DHIS2 Docker instances

**Date:** 2026-06-13
**Status:** Approved (design phase)

## Purpose

A native macOS menu bar ("status bar") app that lets the user manage local
DHIS2 Docker instances through the `d2-broker` HTTP API documented in
[`docs/broker-api.md`](../../broker-api.md). It is a personal, single-user
tool that runs on the same machine as the broker (loopback only).

It covers the full instance lifecycle: list, start, stop, reset, delete, and
create — driven by the broker's asynchronous job model with live progress.

## Constraints (from the broker API)

- **Loopback only.** Base URL `http://localhost:9300` (configurable via the
  app's settings). No CORS, no remote use.
- **Bearer auth.** Every request except `GET /health` needs
  `Authorization: Bearer <token>`. A user-facing UI uses the **admin** token.
- **Asynchronous job model.** Create/reset/start/stop/delete return `202` with
  a `job`. The client polls `GET /jobs/<id>` every 1–2s until a terminal
  status (`succeeded` / `failed` / `interrupted`).
- **Global serialization.** The broker runs one job at a time. A POST to an
  instance that already has an active job returns `409`. So the UI only ever
  shows a single "active operation."
- **No streaming.** `log_tail` (last 20 lines) is the live view; full output is
  fetched on demand from `GET /jobs/<id>/log`.
- **Error model.** Errors return `{ "error": "message" }`. These messages are
  already user-facing and should be shown verbatim.

## Technology & build

- **Language/UI:** Swift, SwiftUI `MenuBarExtra` with
  `.menuBarExtraStyle(.window)` for a rich popover (macOS 13+).
- **Build:** Swift Package Manager **executable** target. Build and run from
  the terminal with `swift build` / `swift run`. No Xcode project required.
- **No Dock icon:** call `NSApp.setActivationPolicy(.accessory)` at launch.
- **Optional packaging:** a `make-app.sh` script can assemble a `.app` bundle
  (with `Info.plist`, `LSUIElement = YES`) for keeping in `/Applications` or
  launching at login. Not required for day-to-day use.
- **Rationale:** SwiftPM is the easiest to build/run/test from the terminal for
  a personal tool, and avoids the Xcode-project ceremony. The tradeoff — no
  Keychain entitlement out of the box — is acceptable because settings are
  stored in `UserDefaults` (a loopback admin token on the user's own machine).

## Architecture

Layered, with small single-purpose units:

### 1. Models (`Codable`)

Decoded directly from the shapes in the API doc:

- `Instance` — `name`, `status` (`InstanceStatus`), `httpPort?`, `pgPort?`,
  `localhostURL?`, `devnetURL?`, `devnetDB?`, `agentManaged`,
  `dhis2MajorVersion?` (only present with `full=1`).
- `InstanceStatus` enum — `running` / `partial` / `stopped`.
- `Seed` — `path`, `source` (`seeds` / `backups`), `sizeBytes`, `modified`.
- `Job` — `id`, `op` (`create`/`reset`/`start`/`stop`/`delete`), `instance`,
  `status` (`JobStatus`), timestamps, `exitCode?`, `error?`, `result?`,
  `logTail?`.
- `JobStatus` enum — `queued` / `running` / `succeeded` / `failed` /
  `interrupted`; with an `isTerminal` helper.
- `BrokerError` — typed error: validation (`400`), unauthorized (`401`),
  forbidden (`403`), notFound (`404`), conflict (`409`), payloadTooLarge
  (`413`), server (`500`), transport (connection refused, etc.), decoding. Each
  carries the broker's verbatim `error` message when present.

### 2. `BrokerClient`

An `async`/`await` HTTP client. One typed method per endpoint:

- `health() -> Bool`
- `instances(full: Bool) -> [Instance]`
- `seeds() -> [Seed]`
- `jobs() -> [Job]`
- `job(id: String) -> Job`
- `jobLog(id: String) -> String`
- `create(_ request: CreateInstanceRequest) -> Job`
- `reset(name: String, seed: String) -> Job`
- `start(name: String) -> Job`
- `stop(name: String) -> Job`
- `delete(name: String) -> Job`

Responsibilities: build the request, attach the bearer header, decode the
response, map non-2xx responses to `BrokerError` (decoding the `{error}` body),
and map `URLError` (e.g. `.cannotConnectToHost`) to `BrokerError.transport`.
The base URL and token are injected (from `Settings`), so the client itself is
stateless and testable. Tested against a mock `URLProtocol` using the sample
JSON from the API doc.

### 3. `JobPoller`

Given a `job.id`, polls `GET /jobs/<id>` every ~1.5s, publishing the latest
`Job` (status + `log_tail`), and stops once the status is terminal. Surfaces
the final job so callers can refresh from `job.result` or fetch the full log on
failure. Pure state-machine logic, tested with an injected fake client (no real
timers in tests — the poll interval and a clock/sleep are injectable).

### 4. `AppModel` (observable, single source of truth)

Holds: `instances`, the current `activeJob?`, `recentJobs`, `settings`, and
transient UI error state. Responsibilities:

- Refresh the instance list when the popover opens and on a light timer
  (~5s) while it is open.
- Drive mutations: call the relevant `BrokerClient` method → receive a `Job`
  → hand it to `JobPoller` → reflect progress in `activeJob` → on terminal,
  patch the affected instance from `job.result` (same shape as a `GET
  /instances` element) or re-list, and move the job into `recentJobs`.
- Expose computed availability for actions (e.g. disable buttons while a job is
  active, since the broker would `409`).

### 5. `Settings` + `TokenResolver`

- `Settings`: `baseURL` (default `http://localhost:9300`),
  `dhis2BasePath` (for locating `tokens.json`), and an optional manual
  `tokenOverride`. Persisted in `UserDefaults`.
- `TokenResolver`: resolve the admin token by reading
  `$DHIS2_BASE/_broker/tokens.json` (using `dhis2BasePath`, or the
  `DHIS2_BASE` environment variable as a fallback). If the manual override is
  set, it wins. If neither resolves, surface a clear "set your token in
  Settings" state.

## UI

`MenuBarExtra(.window)` popover:

- **Menu bar label:** a small icon; shows a spinner/badge when a job is
  running.
- **Active operation banner** (top): shown only when `activeJob` is non-nil.
  Friendly op text ("Creating `agent-test1`…"), a spinner, and the live
  `log_tail`. On failure, a "View log" affordance opens the full log.
- **Instance list:** one row per instance:
  - Name + colored status pill (running = green, partial = amber, stopped =
    grey).
  - "agent" badge when `agent_managed`.
  - "Open in browser" using `localhost_url` (disabled if `null`).
  - Actions: **Start** (if stopped), **Stop** (if running), **Reset**
    (always — opens seed picker), **Delete** (always — confirm dialog).
  - Optional small print: `devnet_url` / DB connection hint. A
    `?full=1`/per-instance refresh fetches `dhis2_major_version` to show a
    "DHIS2 vX" badge when a row is expanded/opened.
- **Footer:** **New instance…**, **Recent activity** (recent jobs; failures
  link to full log), **Settings**, **Refresh**, **Quit**.

### Dialogs / sheets

- **Create instance:** form with `name` (validated against
  `^[a-z][a-z0-9_-]{1,29}$`), `version` (free-text with recent-version
  suggestions, since major-only resolves at job-run time), seed picker from
  `GET /seeds` including a "No seed (empty database)" option, `tomcat` (9/10,
  default 10), and an "Advanced" disclosure for `war_url` / `war_file`.
- **Reset:** seed picker from `GET /seeds`.
- **Delete:** confirmation dialog (irreversible).
- **Full log viewer:** scrollable `text/plain` from `GET /jobs/<id>/log`.
- **Settings:** base URL, `DHIS2_BASE` path, manual token override; a "Test
  connection" button hitting `GET /health` + an authenticated `GET /instances`.

## Error handling

- Show broker `{error}` messages **verbatim**.
- Connection refused / unreachable → "Is d2-broker running at `<baseURL>`?"
- `401` → "Token missing or invalid — check Settings."
- `409` on a mutation → "That instance already has an operation in progress."
- `403` → show the broker message (admin token should not normally hit this).

## Testing strategy

Test-driven (per the project's Superpowers workflow):

- **Model decoding:** decode every model from the sample JSON in the API doc;
  assert field mapping and optional/`null` handling.
- **`BrokerClient`:** mock `URLProtocol` returning canned responses; verify
  request shape (method, path, bearer header, body), 2xx decoding, and each
  error-code → `BrokerError` mapping, including the transport error.
- **`JobPoller`:** injected fake client returning a scripted sequence
  (`queued` → `running` → `succeeded`); assert it polls until terminal and
  stops; assert it surfaces `failed`/`interrupted`. Injectable interval/clock so
  tests don't sleep.
- **`AppModel`:** with a fake client, assert a mutation produces an active job,
  reflects poller updates, and patches/refreshes instances on completion;
  assert action-availability rules.

SwiftUI views themselves are kept thin (they read `AppModel` and call its
methods), so logic lives in the tested layers.

## Out of scope for v1

- Bulk operations (the API has none; the broker serializes anyway).
- Streaming/log following beyond polling `log_tail`.
- Keychain storage (UserDefaults is sufficient for a loopback token; can be
  hardened later).
- Code signing / notarization (personal use).
- Multi-broker / remote-host support.

## File layout (proposed)

```
Package.swift
Sources/D2Manager/
  App.swift                 // @main, MenuBarExtra, .accessory policy
  Models/
    Instance.swift
    Seed.swift
    Job.swift
    BrokerError.swift
    CreateInstanceRequest.swift
  Networking/
    BrokerClient.swift
  Services/
    JobPoller.swift
    TokenResolver.swift
  State/
    AppModel.swift
    Settings.swift
  Views/
    MenuContentView.swift
    InstanceRowView.swift
    ActiveOperationView.swift
    CreateInstanceView.swift
    ResetView.swift
    JobLogView.swift
    SettingsView.swift
Tests/D2ManagerTests/
  ...mirrors the above
make-app.sh                 // optional .app bundling
```
