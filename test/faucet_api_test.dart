import 'dart:convert';

import 'package:celenium_miner/services/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'faucet balance encodes its address and parses a local fixture',
    () async {
      const address = 'fixture:wallet&other=value';
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/faucet/balance');
          expect(request.url.queryParameters, {'address': address});
          return http.Response(
            jsonEncode({
              'balancePradha': 300,
              'totalClaimedPradha': 300,
              'canClaimToday': true,
              'rewardPradha': 20,
              'dailyRewardPradha': 1000,
            }),
            200,
          );
        }),
      );
      final balance = await api.fetchFaucetBalance(address);
      expect(balance!.rewardPradha, 20);
      expect(balance.dailyRewardPradha, 1000);
    },
  );

  for (final status in [200, 400, 409, 429, 503]) {
    test('claim keeps structured errorCode at HTTP $status', () async {
      final api = BridgeApi(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/faucet/claim');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'address': 'fixture:wallet',
            'deviceId': 'fixture-device',
          });
          return http.Response(
            jsonEncode({
              'error': 'nothing accrued yet',
              'errorCode': 'NothingAccrued',
            }),
            status,
          );
        }),
      );
      final result = await api.claimFaucet('fixture:wallet', 'fixture-device');
      expect(result.ok, isFalse);
      expect(result.errorCode, 'NothingAccrued');
    });
  }

  test(
    'claim rejects malformed and unsuccessful HTTP success bodies',
    () async {
      for (final response in [
        http.Response('not JSON', 200),
        http.Response('{}', 200),
        http.Response('{"ok":true,"rewardPradha":20,"balancePradha":20}', 503),
        http.Response('unavailable', 503),
      ]) {
        final api = BridgeApi(
          baseUrl: 'http://fixture.invalid',
          client: MockClient((_) async => response),
        );
        await expectLater(
          api.claimFaucet('fixture:wallet', ''),
          throwsException,
        );
      }
    },
  );
}
