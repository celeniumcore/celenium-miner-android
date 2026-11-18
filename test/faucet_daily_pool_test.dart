import 'dart:async';
import 'dart:convert';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/widgets/faucet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/faucet_fixtures.dart';

Widget host(BridgeApi api, {String locale = 'en'}) => MaterialApp(
  theme: buildCenTheme(),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: FaucetCard(address: 'fixture:wallet', api: api),
    ),
  ),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('celenium/device'),
          (_) async => 'fixture-device',
        );
  });

  for (final scenario in [
    (locale: 'en', quota: 350000, min: 100000, max: 500000),
    (locale: 'id', quota: 125000, min: 50000, max: 250000),
  ]) {
    testWidgets('daily pool claim uses server quota in ${scenario.locale}', (
      tester,
    ) async {
      var posts = 0;
      final pendingRead = Completer<http.Response>();
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/faucet/claim');
            posts++;
            return jsonResponse({
              'ok': true,
              'balancePradha': scenario.quota,
              'rewardPradha': scenario.quota,
              'dailyRewardPradha': scenario.quota,
              'claimedTodayPradha': scenario.quota,
              'rewardModel': 'daily-pool-halving',
              'startedDrip': false,
            });
          }
          return posts == 0
              ? jsonResponse(
                  dailyPoolBalanceFixture(
                    quota: scenario.quota,
                    minReward: scenario.min,
                    maxReward: scenario.max,
                  ),
                )
              : pendingRead.future;
        }),
      );
      await tester.pumpWidget(host(api, locale: scenario.locale));
      await settle(tester);
      final id = scenario.locale == 'id';
      final quotaText =
          '${scenario.quota} pradha per ${id ? 'hari UTC' : 'UTC day'}';
      final boundsText = id
          ? 'Batas reward periode ini: ${scenario.min} sampai ${scenario.max} pradha, sesuai dana tersedia.'
          : 'Current reward bounds: ${scenario.min} to ${scenario.max} pradha, subject to available funds.';
      expect(find.text(quotaText), findsOneWidget);
      expect(find.text(boundsText), findsOneWidget);
      expect(
        find.textContaining(id ? '48 bulan konsensus' : '48 consensus months'),
        findsOneWidget,
      );
      expect(
        find.textContaining(id ? 'pengklaim kemarin' : "yesterday's claimants"),
        findsOneWidget,
      );
      final claim = find.widgetWithText(
        FilledButton,
        id ? 'Klaim reward harian' : 'Claim daily reward',
      );
      expect(claim, findsOneWidget);
      await tester.tap(claim);
      await settle(tester);
      expect(posts, 1);
      expect(find.text(quotaText), findsOneWidget);
      expect(find.text(boundsText), findsOneWidget);
      expect(find.textContaining('2500000 pradha'), findsOneWidget);
      expect(
        find.text(id ? 'Siap diklaim: 0 pradha' : 'Ready to claim: 0 pradha'),
        findsOneWidget,
      );
      expect(
        find.text(
          id
              ? 'Saldo off-chain: ${scenario.quota} pradha'
              : 'Off-chain balance: ${scenario.quota} pradha',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(id ? '24 jam' : '24 hours'), findsNothing);
      pendingRead.complete(
        jsonResponse(
          dailyPoolBalanceFixture(
            balance: scenario.quota,
            quota: scenario.quota,
            claimed: scenario.quota,
            minReward: scenario.min,
            maxReward: scenario.max,
          ),
        ),
      );
      await settle(tester);
      expect(
        find.textContaining(
          id
              ? 'Reward hari ini sudah diklaim'
              : "Today's reward is already claimed",
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(tester.widget<FilledButton>(claim).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('direct claim shows submitted receipt and skips withdraw', (tester) async {
    final txid = 'a1' * 32;
    var posts = 0;
    var submitted = false;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          expect(request.url.path, '/api/faucet/claim');
          submitted = true;
          return jsonResponse({
            'ok': true,
            'claimPayoutMode': 'on-chain',
            'payoutStatus': 'submitted',
            'txid': txid,
            'paidPradha': 350000,
            'feePradha': 509,
            'balancePradha': 0,
            'rewardPradha': 350000,
            'dailyRewardPradha': 350000,
            'claimedTodayPradha': 350000,
            'minRewardPradha': 100000,
            'maxRewardPradha': 500000,
            'rewardModel': 'daily-pool-halving',
            'minWithdrawPradha': 1,
          });
        }
        return jsonResponse({
          ...dailyPoolBalanceFixture(
            claimed: submitted ? 350000 : 0,
          ),
          'claimPayoutMode': 'on-chain',
          'lastPayoutTxid': submitted ? txid : null,
          'lastPayoutStatus': submitted ? 'submitted' : null,
        });
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(find.text('Claim to wallet'), findsOneWidget);
    expect(find.text('Off-chain balance: 0 pradha'), findsNothing);
    expect(find.text('Reward lama menunggu pembayaran: 0 pradha'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Claim to wallet'));
    await settle(tester);
    expect(posts, 1);
    expect(find.text('350000 pradha submitted to your wallet. Fee: 509 pradha, paid by the faucet. Await blockchain confirmation.'), findsOneWidget);
    expect(find.text(txid), findsWidgets);
    expect(find.text('Transaction submitted. Await blockchain confirmation.'), findsOneWidget);
    expect(find.text('Off-chain balance: 0 pradha'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.text('Close'));
    await settle(tester);
    await tester.tap(find.byTooltip('Refresh faucet'));
    await settle(tester);
    expect(posts, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('withdraw requires the current server minimum', (tester) async {
    var balance = 2499999;
    var minimum = 2500000;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return jsonResponse(
          dailyPoolBalanceFixture(balance: balance, minWithdraw: minimum),
        );
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    final withdraw = find.byType(OutlinedButton);
    expect(tester.widget<OutlinedButton>(withdraw).onPressed, isNull);
    expect(find.textContaining('2500000 pradha'), findsOneWidget);

    balance = 2500000;
    await tester.tap(find.byTooltip('Refresh faucet'));
    await settle(tester);
    expect(tester.widget<OutlinedButton>(withdraw).onPressed, isNotNull);

    minimum = 4000000;
    await tester.tap(find.byTooltip('Refresh faucet'));
    await settle(tester);
    expect(tester.widget<OutlinedButton>(withdraw).onPressed, isNull);
    expect(find.textContaining('4000000 pradha'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('withdraw preserves the server limits when refresh fails', (
    tester,
  ) async {
    var posts = 0;
    final pendingRead = Completer<http.Response>();
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          expect(request.url.path, '/api/faucet/withdraw');
          expect(jsonDecode(request.body), {
            'address': 'fixture:wallet',
            'amountPradha': 2500000,
          });
          return jsonResponse({
            'ok': true,
            'txid': 'fixture-transaction',
            'amountPradha': 2500000,
            'feePradha': 2000,
            'balancePradha': 0,
          });
        }
        return posts == 0
            ? jsonResponse(dailyPoolBalanceFixture(balance: 2500000))
            : pendingRead.future;
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.tap(find.text('Withdraw to wallet'));
    await settle(tester);
    expect(posts, 0);
    await tester.tap(find.text('Confirm withdrawal'));
    await settle(tester);
    expect(posts, 1);
    expect(find.text('Off-chain balance: 0 pradha'), findsOneWidget);
    expect(find.textContaining('2500000 pradha'), findsOneWidget);
    expect(find.textContaining('100000 to 500000'), findsOneWidget);
    pendingRead.complete(http.Response('unavailable', 503));
    await settle(tester);
    await tester.tap(find.text('Close'));
    await settle(tester);
    expect(find.textContaining('2500000 pradha'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zero daily quota never offers drip activation', (tester) async {
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (_) async => jsonResponse({
          ...dailyPoolBalanceFixture(quota: 0),
          'canStartDrip': true,
        }),
      ),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(find.text('Claim daily reward'), findsOneWidget);
    expect(find.text('0 pradha per UTC day'), findsOneWidget);
    expect(
      find.text('No claim available. The balance refreshes automatically.'),
      findsOneWidget,
    );
    expect(find.textContaining('Activate'), findsNothing);
    expect(find.textContaining('24 hours'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'empty daily pool does not describe a drip after claim rejection',
    (tester) async {
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient(
          (request) async => request.method == 'POST'
              ? jsonResponse({
                  'error': 'nothing accrued yet',
                  'errorCode': 'NothingAccrued',
                }, 409)
              : jsonResponse(dailyPoolBalanceFixture(quota: 0)),
        ),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      await tester.tap(find.text('Claim daily reward'));
      await settle(tester);
      expect(find.textContaining('24 hours'), findsNothing);
      expect(
        find.text('No claim available. The balance refreshes automatically.'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('old API without a minimum keeps the 1000 fallback', (
    tester,
  ) async {
    var balance = 999;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (_) async => jsonResponse(dailyBalanceFixture(balance: balance)),
      ),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('at least 1000 pradha'), findsOneWidget);
    balance = 1000;
    await tester.tap(find.byTooltip('Refresh faucet'));
    await settle(tester);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    expect(find.text('1000 pradha per UTC day'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late old API response cannot replace current pool limits', (
    tester,
  ) async {
    final staleRead = Completer<http.Response>();
    final oldApi = BridgeApi(
      baseUrl: 'http://old.invalid',
      client: MockClient((_) => staleRead.future),
    );
    final newApi = BridgeApi(
      baseUrl: 'http://new.invalid',
      client: MockClient(
        (_) async => jsonResponse(dailyPoolBalanceFixture(balance: 500000)),
      ),
    );
    await tester.pumpWidget(host(oldApi));
    await settle(tester);
    await tester.pumpWidget(host(newApi));
    await settle(tester);
    staleRead.complete(jsonResponse(dailyBalanceFixture(balance: 1000)));
    await settle(tester);
    expect(find.text('Off-chain balance: 500000 pradha'), findsOneWidget);
    expect(find.text('350000 pradha per UTC day'), findsOneWidget);
    expect(find.textContaining('2500000 pradha'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
