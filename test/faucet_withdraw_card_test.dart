import 'dart:async';
import 'dart:convert';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/widgets/faucet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/faucet_fixtures.dart';

Widget host(
  BridgeApi api, {
  VoidCallback? onWithdrawn,
  String address = 'fixture:wallet',
}) => MaterialApp(
  theme: buildCenTheme(),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: FaucetCard(address: address, api: api, onWithdrawn: onWithdrawn),
    ),
  ),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'withdraw confirms amount and address then refreshes the wallet',
    (tester) async {
      var withdrawn = false;
      var refreshed = 0;
      var posts = 0;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/faucet/withdraw');
            expect(jsonDecode(request.body), {
              'address': 'fixture:wallet',
              'amountPradha': 1000,
            });
            posts++;
            withdrawn = true;
            return jsonResponse({
              'ok': true,
              'txid': 'fixture-transaction',
              'amountPradha': 1000,
              'feePradha': 25,
              'balancePradha': 0,
            });
          }
          return jsonResponse(
            balanceFixture(balance: withdrawn ? 0 : 1000, reward: 0),
          );
        }),
      );
      await tester.pumpWidget(host(api, onWithdrawn: () => refreshed++));
      await settle(tester);
      await tester.tap(find.text('Withdraw to wallet'));
      await settle(tester);
      expect(find.text('fixture:wallet'), findsOneWidget);
      expect(find.textContaining('1000 pradha'), findsWidgets);
      expect(posts, 0);
      await tester.tap(find.text('Confirm withdrawal'));
      await settle(tester);
      expect(posts, 1);
      expect(find.text('Withdrawal submitted'), findsOneWidget);
      expect(find.text('fixture-transaction'), findsOneWidget);
      expect(find.textContaining('25 pradha'), findsOneWidget);
      expect(find.text('Off-chain balance: 0 pradha'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(refreshed, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('withdraw below minimum is disabled', (tester) async {
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (_) async => jsonResponse(balanceFixture(balance: 999)),
      ),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Withdraw to wallet'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final failure in [
    (
      body: {'error': 'faucet has no on-chain funds yet'},
      text: 'The faucet has no on-chain funds yet. Your reward balance is unchanged. Contact the operator.',
    ),
    (
      body: {'error': 'please wait 3600 seconds before withdrawing again'},
      text: 'Wait 3600 seconds before withdrawing again.',
    ),
    (
      body: {
        'error': 'amount is below the minimum withdrawal of 1000 pradha',
        'minAmountPradha': 1000,
      },
      text: 'Withdrawals require at least 1000 pradha.',
    ),
    (
      body: {'error': 'faucet withdrawals are not configured'},
      text: 'Withdrawals are not configured. Contact the operator.',
    ),
    (
      body: {
        'error': 'storage recovery',
        'errorCode': 'StorageUnavailable',
        'txid': 'fixture-uncertain-tx',
      },
      text: 'Withdrawal needs review',
    ),
  ]) {
    testWidgets('withdraw explains ${failure.body['error']}', (tester) async {
      var refreshed = 0;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient(
          (request) async => request.method == 'POST'
              ? jsonResponse(failure.body)
              : jsonResponse(balanceFixture(balance: 1000)),
        ),
      );
      await tester.pumpWidget(host(api, onWithdrawn: () => refreshed++));
      await settle(tester);
      await tester.tap(find.text('Withdraw to wallet'));
      await settle(tester);
      await tester.tap(find.text('Confirm withdrawal'));
      await settle(tester);
      expect(find.text(failure.text), findsOneWidget);
      expect(find.text('Withdrawal submitted'), findsNothing);
      if (failure.body.containsKey('txid')) {
        expect(find.text('fixture-uncertain-tx'), findsOneWidget);
      }
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(refreshed, failure.body.containsKey('txid') ? 1 : 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('dismissed confirmation never submits a withdrawal', (
    tester,
  ) async {
    var posts = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') posts++;
        return jsonResponse(balanceFixture(balance: 1000));
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.tap(find.text('Withdraw to wallet'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(posts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('withdraw completion after disposal cannot notify parent', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var refreshed = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (request) => request.method == 'POST'
            ? pending.future
            : Future.value(jsonResponse(balanceFixture(balance: 1000))),
      ),
    );
    await tester.pumpWidget(host(api, onWithdrawn: () => refreshed++));
    await settle(tester);
    await tester.tap(find.text('Withdraw to wallet'));
    await settle(tester);
    await tester.tap(find.text('Confirm withdrawal'));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(
      jsonResponse({
        'ok': true,
        'txid': 'fixture-transaction',
        'amountPradha': 1000,
        'feePradha': 25,
        'balancePradha': 0,
      }),
    );
    await settle(tester);
    expect(refreshed, 0);
    expect(tester.takeException(), isNull);
  });
}
