import 'dart:convert';

import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/faucet_fixtures.dart';

void main() {
  test(
    'withdraw sends whole balance or an explicit amount without a wallet key',
    () async {
      for (final amount in <int?>[null, 1000]) {
        final api = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/faucet/withdraw');
            expect(jsonDecode(request.body), {
              'address': 'fixture:wallet',
              'amountPradha': ?amount,
            });
            return jsonResponse({
              'ok': true,
              'txid': 'fixture-transaction',
              'amountPradha': 1000,
              'feePradha': 25,
              'balancePradha': 0,
            });
          }),
        );
        final result = await api.withdrawFaucet(
          'fixture:wallet',
          amountPradha: amount,
        );
        expect(result.ok, isTrue);
        expect(result.txid, 'fixture-transaction');
        expect(result.amountPradha, 1000);
        expect(result.feePradha, 25);
        expect(result.balancePradha, 0);
      }
    },
  );

  test('withdraw with a txid and storage error is never success', () {
    final result = FaucetWithdrawResult.tryParse({
      'error': 'transaction accepted but ledger storage needs recovery',
      'errorCode': 'StorageUnavailable',
      'txid': 'fixture-transaction',
      'balancePradha': 0,
    })!;
    expect(result.ok, isFalse);
    expect(result.txid, 'fixture-transaction');
    expect(result.errorCode, 'StorageUnavailable');
    expect(FaucetWithdrawResult.tryParse({'ok': true, 'txid': ''}), isNull);
    expect(
      FaucetWithdrawResult.tryParse({
        'ok': true,
        'txid': 'x',
        'amountPradha': -1,
        'feePradha': 0,
        'balancePradha': 0,
      }),
      isNull,
    );
  });

  test('withdraw preserves server limits and legacy errors', () async {
    final api = BridgeApi(
      baseUrl: 'http://fixture.invalid',
      client: MockClient(
        (_) async => jsonResponse({
          'error': 'please wait 3600 seconds before withdrawing again',
          'errorCode': 'Cooldown',
          'remainingSecs': 3600,
          'minAmountPradha': 1000,
        }, 429),
      ),
    );
    final result = await api.withdrawFaucet('fixture:wallet');
    expect(result.ok, isFalse);
    expect(result.remainingSecs, 3600);
    expect(result.minAmountPradha, 1000);
  });
}
