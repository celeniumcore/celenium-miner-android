import 'package:celenium_miner/models/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('on-chain receipts validate and retain the accepted payment', () {
    // Sample API receipt; this is not a live-chain transaction.
    final receipt = <String, Object?>{
      'ok': true,
      'claimPayoutMode': 'on-chain',
      'payoutStatus': 'submitted',
      'txid': 'a' * 64,
      'paidPradha': 350000,
      'feePradha': 275,
      'balancePradha': 0,
      'rewardPradha': 350000,
      'dailyRewardPradha': 350000,
      'claimedTodayPradha': 350000,
      'minRewardPradha': 100000,
      'maxRewardPradha': 500000,
      'rewardModel': 'daily-pool-halving',
      'minWithdrawPradha': 1,
    };
    for (final field in ['txid', 'paidPradha', 'feePradha', 'payoutStatus']) {
      expect(
        FaucetClaimResult.tryParse({...receipt}..remove(field)),
        isNull,
        reason: 'Missing $field must not become a legacy credit',
      );
    }
    for (final value in ['', 'g' * 64, 'a' * 63, 7]) {
      expect(FaucetClaimResult.tryParse({...receipt, 'txid': value}), isNull);
    }
    for (final value in [0, -1, 0.5, '350300']) {
      expect(
        FaucetClaimResult.tryParse({...receipt, 'paidPradha': value}),
        isNull,
      );
    }
    for (final status in ['pending', 'confirmed', 'failed']) {
      expect(
        FaucetClaimResult.tryParse({...receipt, 'payoutStatus': status}),
        isNull,
      );
    }
    final dynamic result = FaucetClaimResult.tryParse(receipt);
    expect(result.ok, isTrue);
    expect(result.claimPayoutMode, 'on-chain');
    expect(result.payoutStatus, 'submitted');
    expect(result.txid, 'a' * 64);
    expect(result.paidPradha, 350000);
    expect(result.feePradha, 275);
    expect(result.balancePradha, 0);
    expect(result.rewardPradha, 350000);
  });

  test('daily pool bounds and withdrawal minimum come from the bridge', () {
    final balance = FaucetBalance.tryParse({
      'balancePradha': 500000,
      'totalClaimedPradha': 500000,
      'canClaimToday': true,
      'rewardModel': 'daily-pool-halving',
      'rewardPradha': 175000,
      'dailyRewardPradha': 175000,
      'minRewardPradha': 50000,
      'maxRewardPradha': 250000,
      'minWithdrawPradha': 4000000,
      'dripDurationSecs': 0,
    })!;
    expect(balance.rewardModel, 'daily-pool-halving');
    expect(balance.dailyRewardPradha, 175000);
    expect(balance.rewardPradha, 175000);
    expect(balance.minRewardPradha, 50000);
    expect(balance.maxRewardPradha, 250000);
    expect(balance.minWithdrawPradha, 4000000);
    expect(balance.dripDurationSecs, 0);
  });

  test(
    'malformed pool limits invalidate the balance instead of falling back',
    () {
      for (final key in [
        'minWithdrawPradha',
        'minRewardPradha',
        'maxRewardPradha',
      ]) {
        for (final value in [
          -1,
          0.5,
          double.nan,
          double.infinity,
          '2500000',
          true,
        ]) {
          expect(
            FaucetBalance.tryParse({
              'balancePradha': 500000,
              'totalClaimedPradha': 500000,
              'canClaimToday': true,
              key: value,
            }),
            isNull,
            reason: '$key: $value',
          );
        }
      }
    },
  );

  test('quota-one activation and previous-day pending stay explicit', () {
    final balance = FaucetBalance.tryParse({
      'balancePradha': 0,
      'totalClaimedPradha': 0,
      'canClaimToday': false,
      'rewardPradha': 0,
      'dailyRewardPradha': 1,
      'canStartDrip': true,
      'pendingPreviousPradha': 0,
    })!;
    expect(balance.canStartDrip, isTrue);
    expect(balance.pendingPreviousPradha, 0);
    expect(balance.canClaimToday, isFalse);
    final result = FaucetClaimResult.tryParse({
      'ok': true,
      'balancePradha': 0,
      'rewardPradha': 0,
      'dailyRewardPradha': 1,
      'claimedTodayPradha': 0,
      'startedDrip': true,
    })!;
    expect(result.ok, isTrue);
    expect(result.startedDrip, isTrue);
    expect(result.rewardPradha, 0);
    expect(
      FaucetClaimResult.tryParse({
        'ok': true,
        'balancePradha': 20,
        'rewardPradha': 20,
      })!.startedDrip,
      isNull,
    );
  });

  test('drip balance keeps the claimable delta separate from the quota', () {
    final balance = FaucetBalance.tryParse({
      'balancePradha': 300,
      'totalClaimedPradha': 1300,
      'canClaimToday': true,
      'rewardPradha': 20,
      'dailyRewardPradha': 1000,
      'claimedTodayPradha': 0,
      'accruedTodayPradha': 20,
      'serverTimeSecs': 1800,
      'dripDurationSecs': 86400,
    })!;
    expect(balance.rewardPradha, 20);
    expect(balance.dailyRewardPradha, 1000);
    expect(balance.claimedTodayPradha, 0);
    expect(balance.accruedTodayPradha, 20);
    expect(balance.serverTimeSecs, 1800);
    expect(balance.dripDurationSecs, 86400);
    expect(balance.balancePradha, 300);
  });

  test('legacy constructor remains usable without drip metadata', () {
    const balance = FaucetBalance(
      balancePradha: 1,
      totalClaimedPradha: 1,
      canClaimToday: true,
    );
    expect(balance.rewardPradha, isNull);
    expect(balance.dailyRewardPradha, isNull);
    expect(balance.minWithdrawPradha, isNull);
    expect(balance.minRewardPradha, isNull);
    expect(balance.maxRewardPradha, isNull);
  });

  test('claim parses its delta and the dynamic quota', () {
    final result = FaucetClaimResult.tryParse({
      'ok': true,
      'balancePradha': 320,
      'rewardPradha': 20,
      'dailyRewardPradha': 700,
      'claimedTodayPradha': 20,
    })!;
    expect(result.ok, isTrue);
    expect(result.balancePradha, 320);
    expect(result.rewardPradha, 20);
    expect(result.dailyRewardPradha, 700);
    expect(result.claimedTodayPradha, 20);
    expect(result.errorCode, isNull);
  });

  test('claim preserves machine-readable and legacy errors', () {
    final result = FaucetClaimResult.tryParse({
      'error': 'nothing accrued yet',
      'errorCode': 'NothingAccrued',
    })!;
    expect(result.ok, isFalse);
    expect(result.error, 'nothing accrued yet');
    expect(result.errorCode, 'NothingAccrued');
    expect(
      FaucetClaimResult.tryParse({'error': 'already claimed today'})!.errorCode,
      isNull,
    );
    expect(
      FaucetClaimResult.tryParse({
        'ok': true,
        'balancePradha': 1000,
        'rewardPradha': 1000,
      })!.dailyRewardPradha,
      isNull,
    );
  });

  test('malformed amounts cannot turn into spendable or claimable values', () {
    for (final bad in <Object?>[-1, 0.5, double.nan, double.infinity, '20']) {
      expect(
        FaucetBalance.tryParse({
          'balancePradha': 0,
          'totalClaimedPradha': 0,
          'canClaimToday': true,
          'rewardPradha': bad,
        }),
        isNull,
      );
      expect(
        FaucetClaimResult.tryParse({
          'ok': true,
          'balancePradha': 10,
          'rewardPradha': bad,
        }),
        isNull,
      );
    }
    expect(FaucetBalance.tryParse({'error': 'invalid address'}), isNull);
    expect(FaucetBalance.tryParse([]), isNull);
    expect(FaucetClaimResult.tryParse({'ok': false}), isNull);
  });

  test('legacy balance keeps an absent accrual amount unknown', () {
    final balance = FaucetBalance.tryParse({
      'balancePradha': 300,
      'totalClaimedPradha': 1300,
      'canClaimToday': true,
    });
    expect(balance, isNotNull);
    expect(balance!.balancePradha, 300);
    expect(balance.rewardPradha, isNull);
    expect(balance.claimedTodayPradha, isNull);
  });
}
