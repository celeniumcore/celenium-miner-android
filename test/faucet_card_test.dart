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

Widget host(
  BridgeApi? api, {
  String address = 'fixture:wallet',
  String locale = 'en',
}) => MaterialApp(
  theme: buildCenTheme(),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: FaucetCard(address: address, api: api),
    ),
  ),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final scenario in [
    (balance: 0, reward: 1000, claimed: 0, pending: 0, locale: 'en'),
    (balance: 250, reward: 750, claimed: 250, pending: 0, locale: 'id'),
    (balance: 0, reward: 1600, claimed: 0, pending: 600, locale: 'en'),
  ]) {
    testWidgets(
      'daily-fixed ${scenario.reward} credit stays server authoritative',
      (tester) async {
        var posts = 0;
        var balance = scenario.balance;
        var reward = scenario.reward;
        var claimed = scenario.claimed;
        final api = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient((request) async {
            if (request.method == 'POST') {
              posts++;
              if (posts > 1) {
                return jsonResponse({
                  'error': 'already claimed today',
                  'errorCode': 'AlreadyClaimed',
                }, 409);
              }
              balance += reward;
              claimed = 1000;
              final result = jsonResponse({
                'ok': true,
                'balancePradha': balance,
                'rewardPradha': reward,
                'dailyRewardPradha': 1000,
                'claimedTodayPradha': claimed,
                'rewardModel': 'daily-fixed',
              });
              reward = 0;
              return result;
            }
            return jsonResponse(
              dailyBalanceFixture(
                balance: balance,
                reward: reward,
                claimed: claimed,
                pendingPrevious: posts == 0 ? scenario.pending : 0,
              ),
            );
          }),
        );
        await tester.pumpWidget(host(api, locale: scenario.locale));
        await settle(tester);
        final indonesian = scenario.locale == 'id';
        expect(
          find.text(
            indonesian ? '1000 pradha per hari UTC' : '1000 pradha per UTC day',
          ),
          findsOneWidget,
        );
        final button = find.byType(FilledButton);
        expect(
          find.widgetWithText(
            FilledButton,
            indonesian ? 'Klaim reward harian' : 'Claim daily reward',
          ),
          findsOneWidget,
        );
        await tester.tap(button);
        await settle(tester);
        expect(posts, 1);
        expect(
          find.text(
            indonesian
                ? '+${scenario.reward} pradha diklaim'
                : 'Claimed +${scenario.reward} pradha',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            indonesian
                ? 'Saldo off-chain: $balance pradha'
                : 'Off-chain balance: $balance pradha',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await settle(tester);
        expect(posts, 2);
        expect(
          find.text(
            indonesian
                ? 'Reward hari ini sudah diklaim. Klaim berikutnya tersedia setelah 00:00 UTC besok.'
                : 'Today\'s reward is already claimed. Claim again after 00:00 UTC tomorrow.',
          ),
          findsWidgets,
        );
        expect(
          find.text(
            indonesian
                ? 'Saldo off-chain: $balance pradha'
                : 'Off-chain balance: $balance pradha',
          ),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('server eligibility never disables a claim attempt', (
    tester,
  ) async {
    var posts = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          return jsonResponse({
            'error': 'already claimed today',
            'errorCode': 'AlreadyClaimed',
          }, 409);
        }
        return jsonResponse(
          balanceFixture(
            balance: 1000,
            reward: 0,
            claimed: 1000,
            canClaim: false,
          ),
        );
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(FilledButton));
    await settle(tester);
    expect(posts, 1);
    expect(find.text('Off-chain balance: 1000 pradha'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('claim and refresh work through keyboard focus', (tester) async {
    var posts = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          return jsonResponse({
            'ok': true,
            'balancePradha': 320,
            'rewardPradha': 20,
          });
        }
        return jsonResponse(balanceFixture(reward: posts == 0 ? 20 : 0));
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      Focus.of(tester.element(find.byIcon(Icons.refresh_rounded))).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      Focus.of(tester.element(find.text('Claim accrued'))).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(posts, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'confirmed claim updates balance even if the follow-up read fails',
    (tester) async {
      final pendingRead = Completer<http.Response>();
      var posts = 0;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            return jsonResponse({
              'ok': true,
              'balancePradha': 320,
              'rewardPradha': 20,
            });
          }
          return posts == 0
              ? jsonResponse(balanceFixture())
              : pendingRead.future;
        }),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      await tester.tap(find.text('Claim accrued'));
      await settle(tester);
      expect(find.text('Off-chain balance: 320 pradha'), findsOneWidget);
      expect(find.text('Ready to claim: 0 pradha'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pendingRead.complete(http.Response('unavailable', 503));
      await settle(tester);
      expect(find.text('Off-chain balance: 320 pradha'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(posts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final missingWallet in [false, true]) {
    testWidgets(
      'claim explains missing ${missingWallet ? 'wallet' : 'bridge'}',
      (tester) async {
        var requests = 0;
        final api = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient((_) async {
            requests++;
            return jsonResponse(balanceFixture());
          }),
        );
        await tester.pumpWidget(
          host(
            missingWallet ? api : null,
            address: missingWallet ? '' : 'fixture:wallet',
          ),
        );
        await settle(tester);
        await tester.tap(find.byType(FilledButton));
        await settle(tester);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(
              missingWallet
                  ? 'Create or import a wallet before claiming rewards.'
                  : 'Connect a bridge to load participation rewards.',
            ),
          ),
          findsOneWidget,
        );
        expect(requests, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('balance timeout becomes a retryable error', (tester) async {
    final pendingRead = Completer<http.Response>();
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((_) => pendingRead.future),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(
      find.text('Could not refresh the faucet balance. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    pendingRead.complete(jsonResponse(balanceFixture()));
    await settle(tester);
  });

  testWidgets(
    'claim after a failed first balance read uses the server result',
    (tester) async {
      var posts = 0;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            return jsonResponse({
              'ok': true,
              'balancePradha': 1000,
              'rewardPradha': 1000,
              'rewardModel': 'daily-fixed',
            });
          }
          return http.Response('unavailable', 503);
        }),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      expect(
        find.text('Could not refresh the faucet balance. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(posts, 1);
      expect(find.text('Claimed +1000 pradha'), findsOneWidget);
      expect(find.text('Off-chain balance: 1000 pradha'), findsOneWidget);
      expect(find.text('1000 pradha per UTC day'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('network claim failures recover without an unhandled exception', (
    tester,
  ) async {
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') throw http.ClientException('offline');
        return jsonResponse(balanceFixture());
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.tap(find.text('Claim accrued'));
    await settle(tester);
    expect(
      find.text('Claim failed. Refresh the balance before trying again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Refresh faucet'));
    await settle(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final error in {
    'NothingAccrued': 'Nothing accrued yet. Rewards build up over 24 hours.',
    'DailyCapReached': 'Daily limit reached. Check again after 00:00 UTC.',
    'ReservoirFull': 'Faucet balance is full. Withdraw before claiming again.',
    'InvalidAddress': 'The bridge rejected this wallet address.',
    'StorageUnavailable': 'Faucet is temporarily unavailable. Refresh the balance; contact the operator if this continues.',
  }.entries) {
    testWidgets('claim explains ${error.key}', (tester) async {
      var denied = false;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            denied = true;
            return jsonResponse({
              'error': 'server message',
              'errorCode': error.key,
            }, error.key == 'StorageUnavailable' ? 503 : 409);
          }
          return jsonResponse(balanceFixture(reward: denied ? 0 : 20));
        }),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      await tester.tap(find.text('Claim accrued'));
      await settle(tester);
      expect(find.text(error.value), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final staleFirst in [false, true]) {
    testWidgets('claim supersedes pending refresh, stale first: $staleFirst', (
      tester,
    ) async {
      final stale = Completer<http.Response>();
      final claim = Completer<http.Response>();
      final fresh = Completer<http.Response>();
      var reads = 0;
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) {
          if (request.method == 'POST') return claim.future;
          reads++;
          return switch (reads) {
            1 => Future.value(jsonResponse(balanceFixture())),
            2 => stale.future,
            _ => fresh.future,
          };
        }),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      await tester.tap(find.byTooltip('Refresh faucet'));
      await settle(tester);
      await tester.tap(find.byType(FilledButton));
      await settle(tester);
      if (staleFirst) {
        stale.complete(jsonResponse(balanceFixture(balance: 11)));
        await settle(tester);
      }
      claim.complete(
        jsonResponse({'ok': true, 'balancePradha': 1000, 'rewardPradha': 700}),
      );
      await settle(tester);
      expect(reads, 3);
      expect(find.text('Off-chain balance: 1000 pradha'), findsOneWidget);
      if (!staleFirst) {
        stale.complete(jsonResponse(balanceFixture(balance: 11)));
        await settle(tester);
      }
      expect(find.text('Off-chain balance: 11 pradha'), findsNothing);
      fresh.complete(jsonResponse(balanceFixture(balance: 1000, reward: 0)));
      await settle(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('late balance for an old address cannot overwrite the new one', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (request) async =>
            request.url.queryParameters['address'] == 'fixture:old'
            ? old.future
            : jsonResponse(balanceFixture(balance: 777)),
      ),
    );
    await tester.pumpWidget(host(api, address: 'fixture:old'));
    await settle(tester);
    expect(find.text('Loading faucet balance…'), findsOneWidget);
    await tester.pumpWidget(host(api, address: 'fixture:new'));
    await settle(tester);
    old.complete(jsonResponse(balanceFixture(balance: 11)));
    await settle(tester);
    expect(find.text('Off-chain balance: 777 pradha'), findsOneWidget);
    expect(find.text('Off-chain balance: 11 pradha'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('address change while reading device ID cancels the old claim', (
    tester,
  ) async {
    final device = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('celenium/device'),
          (_) => device.future,
        );
    var posts = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') posts++;
        return jsonResponse(balanceFixture());
      }),
    );
    await tester.pumpWidget(host(api, address: 'fixture:old'));
    await settle(tester);
    await tester.tap(find.text('Claim accrued'));
    await tester.pump();
    await tester.pumpWidget(host(api, address: 'fixture:new'));
    device.complete('fixture-device');
    await settle(tester);
    expect(posts, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dispose in [false, true]) {
    testWidgets(
      'pending claim ignores ${dispose ? 'disposal' : 'API replacement'}',
      (tester) async {
        final pending = Completer<http.Response>();
        final oldApi = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient(
            (request) async => request.method == 'POST'
                ? pending.future
                : jsonResponse(balanceFixture()),
          ),
        );
        final nextApi = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient(
            (_) async => jsonResponse(balanceFixture(balance: 555)),
          ),
        );
        await tester.pumpWidget(host(oldApi));
        await settle(tester);
        await tester.tap(find.text('Claim accrued'));
        await settle(tester);
        await tester.pumpWidget(dispose ? const SizedBox() : host(nextApi));
        pending.complete(
          jsonResponse({'ok': true, 'rewardPradha': 20, 'balancePradha': 320}),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Claimed +20 pradha'), findsNothing);
        if (!dispose) {
          expect(find.text('Off-chain balance: 555 pradha'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('disposing a pending balance cancels polling safely', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var reads = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((_) {
        reads++;
        return pending.future;
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(jsonResponse(balanceFixture()));
    await settle(tester);
    await tester.pump(const Duration(minutes: 2));
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap sends one claim and resume refreshes eligibility', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var posts = 0;
    var reads = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) {
        if (request.method == 'POST') {
          posts++;
          return pending.future;
        }
        reads++;
        return Future.value(jsonResponse(balanceFixture()));
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    await tester.tap(find.text('Claim accrued'));
    await tester.tap(find.text('Claim accrued'));
    await settle(tester);
    expect(posts, 1);
    pending.complete(
      jsonResponse({'ok': true, 'balancePradha': 320, 'rewardPradha': 20}),
    );
    await settle(tester);
    final before = reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 46));
    expect(reads, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(reads, before + 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('legacy bridge and missing bridge have honest states', (
    tester,
  ) async {
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (_) async => jsonResponse({
          'balancePradha': 9,
          'totalClaimedPradha': 9,
          'canClaimToday': true,
        }),
      ),
    );
    await tester.pumpWidget(host(null));
    await settle(tester);
    expect(
      find.text('Connect a bridge to load participation rewards.'),
      findsOneWidget,
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(find.text('Off-chain balance: 9 pradha'), findsOneWidget);
    expect(find.textContaining('Ready to claim:'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'previous-day pending is displayed without inventing claimable value',
    (tester) async {
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient(
          (_) async => jsonResponse({
            ...balanceFixture(balance: 0, reward: 1, quota: 1),
            'pendingPreviousPradha': 1,
          }),
        ),
      );
      await tester.pumpWidget(host(api));
      await settle(tester);
      expect(find.text('From previous days: 1 pradha'), findsOneWidget);
      expect(find.text('Ready to claim: 1 pradha'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('quota one activates without claiming a zero credit', (
    tester,
  ) async {
    var started = false;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          started = true;
          return jsonResponse({
            'ok': true,
            'balancePradha': 0,
            'rewardPradha': 0,
            'dailyRewardPradha': 1,
            'claimedTodayPradha': 0,
            'startedDrip': true,
          });
        }
        return jsonResponse({
          ...balanceFixture(balance: 0, reward: 0, quota: 1),
          'canStartDrip': !started,
          'pendingPreviousPradha': 0,
        });
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(find.text('Activate rewards'), findsOneWidget);
    await tester.tap(find.text('Activate rewards'));
    await settle(tester);
    expect(started, isTrue);
    expect(
      find.text('Rewards activated. They will accrue over time.'),
      findsOneWidget,
    );
    expect(find.text('Claimed +0 pradha'), findsNothing);
    expect(find.text('Off-chain balance: 0 pradha'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('celenium/device'),
          (_) async => 'fixture-device',
        );
  });

  testWidgets('legacy claims retry without duplicate credit and keep polling', (
    tester,
  ) async {
    var reward = 20;
    var balance = 300;
    var claimed = 0;
    var posts = 0;
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/faucet/claim');
          expect(jsonDecode(request.body), {
            'address': 'fixture:wallet',
            'deviceId': 'fixture-device',
          });
          posts++;
          if (reward == 0) {
            return jsonResponse({
              'error': 'nothing accrued yet',
              'errorCode': 'NothingAccrued',
            }, 409);
          }
          balance += reward;
          claimed += reward;
          final result = jsonResponse({
            'ok': true,
            'balancePradha': balance,
            'rewardPradha': reward,
            'dailyRewardPradha': 1000,
            'claimedTodayPradha': claimed,
          });
          reward = 0;
          return result;
        }
        expect(request.url.path, '/api/faucet/balance');
        return jsonResponse(
          balanceFixture(balance: balance, reward: reward, claimed: claimed),
        );
      }),
    );
    await tester.pumpWidget(host(api));
    await settle(tester);
    expect(find.text('Ready to claim: 20 pradha'), findsOneWidget);
    expect(find.text('Daily quota: 1000 pradha'), findsOneWidget);
    expect(find.text('Off-chain balance: 300 pradha'), findsOneWidget);
    await tester.tap(find.text('Claim accrued'));
    await settle(tester);
    expect(posts, 1);
    expect(find.text('Claimed +20 pradha'), findsOneWidget);
    expect(find.text('Off-chain balance: 320 pradha'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Claim accrued'));
    await settle(tester);
    expect(posts, 2);
    expect(find.text('Off-chain balance: 320 pradha'), findsOneWidget);
    reward = 1;
    await tester.pump(const Duration(seconds: 46));
    await settle(tester);
    expect(find.text('Ready to claim: 1 pradha'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
