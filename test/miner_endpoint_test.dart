import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/services/mining_engine.dart';
import 'package:celenium_miner/services/settings_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh installs use the public bridge URL', () async {
    expect(
      SettingsStore.defaultBaseUrl,
      'https://celenium.web.id/bridge',
    );
    expect(await SettingsStore().baseUrl(), SettingsStore.defaultBaseUrl);
  });

  test('bridge requests retain the public reverse-proxy prefix', () async {
    final api = BridgeApi(
      baseUrl: SettingsStore.defaultBaseUrl,
      client: MockClient((request) async {
        expect(request.url.path, '/bridge/api/fee');
        return http.Response('{"feePradha":509}', 200);
      }),
    );

    expect(await api.fetchFee(), 509);
  });

  test('migrates the previous bridge default', () async {
    SharedPreferences.setMockInitialValues({
      'bridge_base_url': 'http://5.178.98.100:3031',
    });

    expect(await SettingsStore().baseUrl(), SettingsStore.defaultBaseUrl);
  });

  test('migrates the previous bridge default with a trailing slash', () async {
    SharedPreferences.setMockInitialValues({
      'bridge_base_url': 'http://5.178.98.100:3031/',
    });

    expect(await SettingsStore().baseUrl(), SettingsStore.defaultBaseUrl);
  });

  test('keeps a custom bridge URL unchanged', () async {
    const custom = 'https://bridge.example.test:3031/';
    SharedPreferences.setMockInitialValues({'bridge_base_url': custom});

    expect(await SettingsStore().baseUrl(), custom);
  });

  test('mining uses the stable public pool hostname', () {
    expect(MiningEngine.host, 'celenium.web.id');
    expect(MiningEngine.port, 5556);
  });
}
