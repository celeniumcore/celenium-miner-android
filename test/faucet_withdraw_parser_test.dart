import 'package:celenium_miner/models/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'TransferPending exposes pendingTxid without accepting the withdrawal',
    () {
      final pendingTxid = 'a' * 64;
      final result = FaucetWithdrawResult.tryParse({
        'ok': true,
        'error': 'withdrawal submission status is uncertain',
        'errorCode': 'TransferPending',
        'pendingTxid': pendingTxid,
        'amountPradha': 1000,
        'feePradha': 25,
        'balancePradha': 0,
      })!;

      expect(result.ok, isFalse);
      expect(result.txid, pendingTxid);
      expect(result.error, 'withdrawal submission status is uncertain');
      expect(result.errorCode, 'TransferPending');
      expect(result.balancePradha, 0);
      expect(result.amountPradha, isNull);
      expect(result.feePradha, isNull);
    },
  );

  test('TransferPending ignores pendingTxid values outside exact 64-hex', () {
    final validTxid = 'a' * 64;
    for (final pendingTxid in <Object?>[
      null,
      '',
      42,
      true,
      <String>[],
      <String, dynamic>{},
      'a' * 63,
      'a' * 65,
      'g' * 64,
      '${'a' * 63}\n',
      '${'a' * 62}\r\n',
      ' $validTxid',
      '$validTxid ',
      '$validTxid\n',
      '0x$validTxid',
    ]) {
      final result = FaucetWithdrawResult.tryParse({
        'error': 'withdrawal submission status is uncertain',
        'errorCode': 'TransferPending',
        'pendingTxid': pendingTxid,
      })!;

      expect(result.ok, isFalse, reason: 'pendingTxid: $pendingTxid');
      expect(result.txid, isNull, reason: 'pendingTxid: $pendingTxid');
      expect(result.errorCode, 'TransferPending');
    }
  });

  test('TransferPending rejects a success body without error text', () {
    for (final error in <Object?>[null, 42, false, <String>[]]) {
      expect(
        FaucetWithdrawResult.tryParse({
          'ok': true,
          'error': error,
          'errorCode': 'TransferPending',
          'txid': 'a' * 64,
          'pendingTxid': 'a' * 64,
          'amountPradha': 1000,
          'feePradha': 25,
          'balancePradha': 0,
        }),
        isNull,
      );
    }
  });

  test(
    'TransferPending preserves pendingTxid hex case and legacy empty ids',
    () {
      final pendingTxid = 'aBcD0123' * 8;
      for (final txid in <Object?>[null, '', 42]) {
        final result = FaucetWithdrawResult.tryParse({
          'error': 'withdrawal submission status is uncertain',
          'errorCode': 'TransferPending',
          'txid': txid,
          'pendingTxid': pendingTxid,
        })!;

        expect(result.ok, isFalse);
        expect(result.txid, pendingTxid);
      }
    },
  );

  test('TransferPending accepts matching transaction ids as uncertain', () {
    final txid = 'b' * 64;
    final result = FaucetWithdrawResult.tryParse({
      'error': 'withdrawal submission status is uncertain',
      'errorCode': 'TransferPending',
      'txid': txid,
      'pendingTxid': txid,
    })!;

    expect(result.ok, isFalse);
    expect(result.txid, txid);
  });

  test(
    'TransferPending preserves legacy txid without a usable pendingTxid',
    () {
      for (final pendingTxid in <Object?>[null, '', 42, 'malformed']) {
        final result = FaucetWithdrawResult.tryParse({
          'error': 'withdrawal submission status is uncertain',
          'errorCode': 'TransferPending',
          'txid': 'fixture-transaction',
          'pendingTxid': pendingTxid,
          'remainingSecs': 3600,
          'minAmountPradha': 1000,
        })!;

        expect(result.ok, isFalse);
        expect(result.txid, 'fixture-transaction');
        expect(result.errorCode, 'TransferPending');
        expect(result.remainingSecs, 3600);
        expect(result.minAmountPradha, 1000);
      }
    },
  );

  test('pendingTxid is ignored for other errors and legacy error bodies', () {
    for (final errorCode in <Object?>[
      null,
      'StorageUnavailable',
      'transferPending',
      42,
    ]) {
      final result = FaucetWithdrawResult.tryParse({
        'error': 'withdrawal failed',
        'errorCode': errorCode,
        'pendingTxid': 'a' * 64,
      })!;

      expect(result.ok, isFalse);
      expect(result.txid, isNull);
    }
  });

  test('pendingTxid cannot replace txid in a successful withdrawal body', () {
    expect(
      FaucetWithdrawResult.tryParse({
        'ok': true,
        'pendingTxid': 'a' * 64,
        'amountPradha': 1000,
        'feePradha': 25,
        'balancePradha': 0,
      }),
      isNull,
    );
  });

  test('legacy success still uses txid and ignores pendingTxid', () {
    final result = FaucetWithdrawResult.tryParse({
      'ok': true,
      'txid': 'fixture-transaction',
      'pendingTxid': 'a' * 64,
      'amountPradha': 1000,
      'feePradha': 25,
      'balancePradha': 0,
    })!;

    expect(result.ok, isTrue);
    expect(result.txid, 'fixture-transaction');
    expect(result.amountPradha, 1000);
    expect(result.feePradha, 25);
    expect(result.balancePradha, 0);
    expect(result.error, isNull);
    expect(result.errorCode, isNull);
  });

  test('TransferPending rejects conflicting transaction ids', () {
    expect(
      FaucetWithdrawResult.tryParse({
        'error': 'withdrawal submission status is uncertain',
        'errorCode': 'TransferPending',
        'txid': 'a' * 64,
        'pendingTxid': 'b' * 64,
      }),
      isNull,
    );
  });
}
