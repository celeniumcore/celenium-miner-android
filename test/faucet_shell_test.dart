import 'dart:convert';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/main.dart';
import 'package:celenium_miner/screens/wallet_screen.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/faucet_fixtures.dart';
import 'support/fonts.dart';

Future<void> settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadCenFonts);
  testWidgets(
    'real shell opens wallet and reads on-chain balance after withdrawal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Public BIP39 test vector, used only by the in-memory keystore and HTTP fake.
      FlutterSecureStorage.setMockInitialValues({
        'cen_recovery_phrase': 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      });
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var withdrawn = false;
      var walletReads = 0;
      String? address;
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/bridge/api/faucet/balance':
            address = request.url.queryParameters['address'];
            return jsonResponse(
              balanceFixture(balance: withdrawn ? 0 : 1000, reward: 0),
            );
          case '/bridge/api/faucet/withdraw':
            expect(jsonDecode(request.body), {
              'address': address,
              'amountPradha': 1000,
            });
            withdrawn = true;
            return jsonResponse({
              'ok': true,
              'txid': 'fixture-transaction',
              'amountPradha': 1000,
              'feePradha': 25,
              'balancePradha': 0,
            });
          case '/bridge/api/balance':
            walletReads++;
            expect(request.url.queryParameters['address'], address);
            return jsonResponse({'address': address, 'balancePradha': 1000});
          default:
            return jsonResponse({'error': 'fixture has no mining node'});
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinerHome(client: client),
        ),
      );
      await settle(tester, 40);
      await tester.tap(find.text('ENTER'));
      await settle(tester);
      await tester.ensureVisible(find.text('Withdraw to wallet'));
      await tester.pump();
      await tester.tap(find.text('Withdraw to wallet'));
      await settle(tester);
      await tester.tap(find.text('Confirm withdrawal'));
      await settle(tester);
      expect(withdrawn, isTrue);
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(walletReads, greaterThan(0));
      expect(find.text('1,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
