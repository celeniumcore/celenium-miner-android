import 'dart:convert';

import 'package:http/http.dart' as http;

Map<String, Object> balanceFixture({
  int balance = 300,
  int reward = 20,
  int claimed = 0,
  int quota = 1000,
  bool? canClaim,
}) => {
  'balancePradha': balance,
  'totalClaimedPradha': balance,
  'canClaimToday': canClaim ?? reward > 0,
  'rewardPradha': reward,
  'dailyRewardPradha': quota,
  'claimedTodayPradha': claimed,
  'accruedTodayPradha': claimed + reward,
  'serverTimeSecs': 1800,
  'dripDurationSecs': 86400,
};

Map<String, Object> dailyBalanceFixture({
  int balance = 0,
  int reward = 1000,
  int claimed = 0,
  int pendingPrevious = 0,
}) => {
  'balancePradha': balance,
  'totalClaimedPradha': balance,
  'canClaimToday': reward > 0,
  'rewardPradha': reward,
  'dailyRewardPradha': 1000,
  'claimedTodayPradha': claimed,
  'pendingPreviousPradha': pendingPrevious,
  'rewardModel': 'daily-fixed',
  'dripModel': 'daily-fixed',
  'dripDurationSecs': 0,
  'claimPeriodSecs': 86400,
  'canStartDrip': false,
};

Map<String, Object> dailyPoolBalanceFixture({
  int balance = 0,
  int quota = 350000,
  int claimed = 0,
  int minWithdraw = 2500000,
  int minReward = 100000,
  int maxReward = 500000,
}) => {
  ...dailyBalanceFixture(balance: balance, reward: claimed > 0 ? 0 : quota),
  'rewardModel': 'daily-pool-halving',
  'dripModel': 'daily-pool-halving',
  'dailyRewardPradha': quota,
  'claimedTodayPradha': claimed,
  'minWithdrawPradha': minWithdraw,
  'minRewardPradha': minReward,
  'maxRewardPradha': maxReward,
};

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
