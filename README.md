# Celenium Miner

A Flutter companion application for the Celenium (CEN) network. It brings wallet access, participation claims, bridge status, and an Android mining worker into one application, with English and Indonesian interfaces.

Celenium uses a separate chain and address namespace. Its network software is a fork of [Kaspa's rusty-kaspa](https://github.com/kaspanet/rusty-kaspa). This application connects to Celenium; it is not an official Kaspa wallet or miner.

## What the application does

- **Wallet:** Creates or imports a recovery phrase and uses the same derived address for the wallet and mining payout destination.
- **Participation claims:** Reads the bridge's payout mode, submits eligible daily claims, and displays transaction receipts. An older bridge can still expose the separate off-chain claim and withdrawal flow.
- **Android mining:** Connects to the Stratum pool and uses the bundled native kHeavyHash library. Sessions stop at the configured 12-hour limit and require a new start.
- **Bridge status:** Displays the worker, share, and balance responses returned by the configured bridge.
- **Language:** Supports English, Indonesian, and a system-language option.

The Flutter shell also has desktop targets. Native mining availability depends on the libraries packaged for the target platform; an Android mining feature must not be assumed to work in a desktop build.

## Shares, claims, and wallet balance

These values describe different stages:

- **Accepted shares:** Pool submissions accepted during a mining session. They do not establish a confirmed coin payment.
- **Participation balance:** The bridge's accounting for rewards awaiting payment. It is not the wallet's on-chain balance.
- **Submitted transaction:** A payment receipt with a TXID. Submission is distinct from blockchain confirmation.
- **Wallet balance:** The balance returned by the node-backed API for the wallet address.

Direct claims require verified faucet funding and a transaction that passes the node's validation rules. An empty pool, uncertain submission, or failed API call must not be presented as a successful payment. General worker PPLNS settlement is separate from the direct-claim feature.

Mining on a phone consumes power and can generate heat. This application makes no profitability or guaranteed-reward promise.

## Connections

The default HTTP API is `https://celenium.web.id/bridge`. The Android mining worker connects separately to `celenium.web.id:5556`.

A custom bridge URL can be configured in the application. API availability, a funded faucet, and a synced node are operational conditions, not properties guaranteed by installing the APK.

```text
Flutter application
  -> HTTPS bridge API -> node-backed wallet and claim responses
  -> Stratum TCP pool -> mining jobs and share submissions
```

## Wallet data and trust

The recovery phrase is generated on first use or imported by the user, then stored through `flutter_secure_storage`. The mining worker resolves its wallet from that same phrase; the older Android-ID-derived wallet helper is not the current wallet creation path.

Back up the recovery phrase before changing devices or reinstalling. Preserve the established signing certificate for Android updates. If Android rejects an update as a version downgrade, compare the installed and downloaded manifest version codes and use the matching ABI variant; do not uninstall a real wallet app as the first fix.

The current send API supplies `privateKeyHex` to the configured bridge for signing. Use only a bridge operator you trust and review [the API implementation](lib/services/bridge_api.dart) before using this wallet for funds. Do not describe this path as signing exclusively on the device.

Never commit recovery phrases, wallet keys, access tokens, signing keystores, or environment secrets.

## Build and verify

Install the Flutter SDK and Android tooling required by [pubspec.yaml](pubspec.yaml) and the Android project configuration. The current application version is `1.0.10+9010`.

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter analyze
flutter build apk --release
flutter build apk --release --split-per-abi
```

Build outputs are written under `build/app/outputs/flutter-apk/`. Preserve the existing signing setup when producing an update for an installed wallet.

The project includes an APK content checker:

```bash
python3 tool/verify_apk.py build/app/outputs/flutter-apk/app-release.apk
python3 tool/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

That checker currently reads the ARM64 AOT library. For an ARMv7 or x86_64 split, inspect the actual `lib/<abi>/libapp.so` and apply the same manifest, locale, and packaged-content checks. A successful build or content check does not replace an installation and interaction test.

## Source map

- [Mining engine](lib/services/mining_engine.dart): Pool endpoint, session limit, and wallet resolution.
- [Native miner bindings](lib/services/miner_native.dart): FFI interface to the bundled hashing library.
- [Bridge client](lib/services/bridge_api.dart): HTTP requests and transaction API calls.
- [Response models](lib/models/bridge.dart): Validation of balances and claim receipts.
- [Participation card](lib/widgets/faucet_card.dart): Claim states, error feedback, and receipts.
- [Wallet derivation](lib/services/cen_wallet.dart) and [secure storage](lib/services/keystore.dart).
- [Android manifest](android/app/src/main/AndroidManifest.xml): Permissions, service declarations, and application metadata.

## Localization

Text lives in `lib/l10n/app_en.arb` and `lib/l10n/app_id.arb`. Regenerate `app_localizations*.dart` with `flutter gen-l10n`; do not edit generated localization files by hand.

Application language is selected under Profile / Language or the corresponding Android application-language setting where supported. The Android locale configuration is declared in `android/app/src/main/res/xml/locales_config.xml`.

## Attribution and contributions

Celenium development is maintained by [Dimas A. Pradana (`dimas405`)](https://github.com/dimas405). The repository retains the real author history of its changes.

The Celenium network builds on [kaspanet/rusty-kaspa](https://github.com/kaspanet/rusty-kaspa). Credit for that upstream code belongs to the [Kaspa developers and contributors](https://github.com/kaspanet/rusty-kaspa/graphs/contributors). This attribution does not imply that they maintain or endorse Celenium or this Flutter application.

Contributions should include a reproducible issue or a scoped change with test evidence. Keep attribution tied to actual work.
