# Mote v1 identity specification

## Goal

Ship the first Developer ID release under one durable identity: **Mote**,
version `1.0.0`, bundle identifier `dev.brice.mote`.

## Product identity

- The public app, executable, Swift package, primary targets/modules, current
  source types, test targets, bundle, archive, active docs, and current error
  domains use `Mote`.
- The release app is `Mote.app`; its executable is `Mote`.
- The cleanup module is `MoteCleanup`.
- The auxiliary app-package executables are `mote-cleanup-acceptance` and
  `mote-streaming-benchmark`.
- The bundle version is `1`; the user-visible version is `1.0.0`.
- The Developer ID certificate remains
  `Developer ID Application: Brice Neal (KPM2M597LZ)`. Certificates identify
  the developer and are not renamed for each app.

## Migration contract

Changing the bundle identifier changes the standard UserDefaults domain.
On first launch, Mote copies known preference values from the legacy
`dev.brice.localflow` domain and `grotdown.*` keys into `mote.*` keys in the
new domain. Existing Mote values win. A migration marker prevents deleted Mote
values from being resurrected from the legacy domain on later launches.

History and snippets move from `Application Support/Grotdown` to
`Application Support/Mote`. Migration copies a legacy JSON file only when the
corresponding Mote file does not exist. The legacy file remains as rollback
evidence. Existing Mote data always wins. Migrated directories and files retain
the existing owner-only permissions and backup exclusion.

## Release contract

The build fails closed without a non-empty `mlx.metallib`. The real release
uses the Developer ID Application certificate, hardened runtime, secure
timestamp, and strict signature verification. The signed zip is submitted with
an `xcrun notarytool` Keychain profile named `Mote-notary`; credentials never
enter the repository or chat. The accepted ticket is stapled and validated,
and Gatekeeper assessment must pass.

## Compatibility and exclusions

- macOS will treat `dev.brice.mote` as a new app and request Microphone and
  Accessibility permission again.
- The GitHub repository is `deresolution20/mote`; existing local checkout paths
  may remain named `local-flow` without affecting the product identity.
- Historical specifications, plans, decision entries, and benchmark run
  artifacts retain the names that were accurate when recorded. Current docs
  may identify Grotdown as the former name.
- Third-party dependency names and the MLX metallib filename are unchanged.
