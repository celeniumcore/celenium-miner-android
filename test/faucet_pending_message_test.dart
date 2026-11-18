import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/widgets/faucet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/faucet_fixtures.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final scenario in [
    (
      locale: 'en',
      withdraw: 'Withdraw to wallet',
      confirm: 'Confirm withdrawal',
      message: 'The withdrawal status is uncertain. Do not withdraw again. Contact the operator with this TXID and check your wallet.',
      accepted: 'The node accepted a transaction',
    ),
    (
      locale: 'id',
      withdraw: 'Tarik ke wallet',
      confirm: 'Konfirmasi penarikan',
      message: 'Status penarikan belum pasti. Jangan tarik lagi. Hubungi operator dengan TXID ini dan periksa wallet.',
      accepted: 'Node menerima transaksi',
    ),
  ]) {
    testWidgets('pending withdrawal stays uncertain in ${scenario.locale}', (
      tester,
    ) async {
      final pendingTxid = 'a' * 64;
      final api = BridgeApi(
        baseUrl: 'https://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return jsonResponse({
              'error': 'withdrawal submission status is uncertain',
              'errorCode': 'TransferPending',
              'pendingTxid': pendingTxid,
            }, 503);
          }
          return jsonResponse(balanceFixture(balance: 1000));
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          locale: Locale(scenario.locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FaucetCard(address: 'fixture:wallet', api: api),
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text(scenario.withdraw));
      await settle(tester);
      await tester.tap(find.text(scenario.confirm));
      await settle(tester);
      final resultDialog = find.byType(AlertDialog).last;
      expect(
        find.descendant(of: resultDialog, matching: find.text(scenario.message)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resultDialog,
          matching: find.textContaining(scenario.accepted),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: resultDialog, matching: find.text(pendingTxid)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
