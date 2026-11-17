import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/screens/mining_screen.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/services/mining_readout.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/theme/typography.dart';
import 'package:celenium_miner/widgets/faucet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/faucet_fixtures.dart';
import 'support/fonts.dart';

void main() {
  setUpAll(loadCenFonts);

  for (final scenario in [
    (
      name: 'faucet_withdraw_ready_id',
      locale: 'id',
      width: 390.0,
      scale: 1.0,
      body: dailyBalanceFixture(balance: 1000, reward: 0, claimed: 1000),
      failed: false,
    ),
    (
      name: 'faucet_ready_id',
      locale: 'id',
      width: 390.0,
      scale: 1.0,
      body: dailyBalanceFixture(),
      failed: false,
    ),
    (
      name: 'faucet_waiting_en',
      locale: 'en',
      width: 390.0,
      scale: 1.0,
      body: dailyBalanceFixture(balance: 1000, reward: 0, claimed: 1000),
      failed: false,
    ),
    (
      name: 'faucet_activate_id',
      locale: 'id',
      width: 390.0,
      scale: 1.0,
      body: {
        ...balanceFixture(balance: 0, reward: 0, quota: 1),
        'canStartDrip': true,
      },
      failed: false,
    ),
    (
      name: 'faucet_error_id',
      locale: 'id',
      width: 320.0,
      scale: 1.0,
      body: <String, Object>{},
      failed: true,
    ),
    (
      name: 'faucet_large_text_id',
      locale: 'id',
      width: 320.0,
      scale: 2.0,
      body: dailyBalanceFixture(),
      failed: false,
    ),
  ]) {
    testWidgets(scenario.name, (tester) async {
      tester.view.physicalSize = Size(scenario.width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/faucet/balance');
          return jsonResponse(scenario.body, scenario.failed ? 503 : 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          debugShowCheckedModeBanner: false,
          locale: Locale(scenario.locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'LOCAL TEST FIXTURE',
                      style: TextStyle(
                        fontFamily: TypeScale.bodyFamily,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FaucetCard(address: 'fixture:wallet', api: api),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(FaucetCard));
      for (final text
          in find
              .descendant(
                of: find.byType(FaucetCard),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final rect = tester.getRect(find.byWidget(text.widget));
        expect(rect.left, greaterThanOrEqualTo(card.left));
        expect(rect.right, lessThanOrEqualTo(card.right));
      }
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byType(IconButton)).shortestSide,
        greaterThanOrEqualTo(44),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/${scenario.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final layout in [
    (name: 'phone', width: 390.0),
    (name: 'tablet', width: 800.0),
    (name: 'desktop', width: 1200.0),
  ]) {
    testWidgets('faucet is mounted in the real ${layout.name} mining layout', (
      tester,
    ) async {
      tester.view.physicalSize = Size(layout.width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((_) async => jsonResponse(dailyBalanceFixture())),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          debugShowCheckedModeBanner: false,
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('Mining · local test fixture')),
            body: MiningScreen(
              readout: MiningReadout.from(
                const MinerSnapshot(status: null, stats: null),
              ),
              nodeAddress: null,
              onOpenActivity: () {},
              faucetAddress: 'fixture:wallet',
              faucetApi: api,
            ),
          ),
        ),
      );
      await precacheMarkImages(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.byType(FaucetCard));
      await tester.pump();
      expect(find.byType(FaucetCard), findsOneWidget);
      expect(find.text('1000 pradha per hari UTC'), findsOneWidget);
      expect(find.text('Siap diklaim: 1000 pradha'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/faucet_mining_${layout.name}_id.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
