/// Models for the Celenium stratum bridge HTTP API.
///
/// These mirror the JSON the bridge serves on its web dashboard port:
/// `GET /api/status` and `GET /api/stats`. Field names match the server's
/// serde output, which is why several are camelCase.
library;

/// `GET /api/status`
class BridgeStatus {
  final String celeniumdAddress;
  final String celeniumdVersion;
  final int instances;
  final String webBind;

  const BridgeStatus({
    required this.celeniumdAddress,
    required this.celeniumdVersion,
    required this.instances,
    required this.webBind,
  });

  static BridgeStatus? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BridgeStatus(
      celeniumdAddress: json['celeniumd_address'] as String? ?? '',
      celeniumdVersion: json['celeniumd_version'] as String? ?? '',
      instances: (json['instances'] as num?)?.toInt() ?? 0,
      webBind: json['web_bind'] as String? ?? '',
    );
  }
}

/// `internalCpu` inside `GET /api/stats`. Null when no internal miner runs.
class InternalCpuStats {
  final double hashrateGhs;
  final int hashesTried;
  final int blocksSubmitted;
  final int blocksAccepted;
  final int shares;
  final int stale;
  final int invalid;
  final String wallet;

  const InternalCpuStats({
    required this.hashrateGhs,
    required this.hashesTried,
    required this.blocksSubmitted,
    required this.blocksAccepted,
    required this.shares,
    required this.stale,
    required this.invalid,
    required this.wallet,
  });

  static InternalCpuStats? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return InternalCpuStats(
      hashrateGhs: (json['hashrateGhs'] as num?)?.toDouble() ?? 0,
      hashesTried: (json['hashesTried'] as num?)?.toInt() ?? 0,
      blocksSubmitted: (json['blocksSubmitted'] as num?)?.toInt() ?? 0,
      blocksAccepted: (json['blocksAccepted'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as num?)?.toInt() ?? 0,
      invalid: (json['invalid'] as num?)?.toInt() ?? 0,
      wallet: json['wallet'] as String? ?? '',
    );
  }
}

class WorkerInfo {
  final String instance;
  final String worker;
  final String wallet;
  final double hashrate;
  final int shares;
  final int stale;
  final int invalid;
  final int blocks;
  final int? lastSeen;
  final String? status;
  final double? currentDifficulty;
  final int? sessionUptime;

  const WorkerInfo({
    required this.instance,
    required this.worker,
    required this.wallet,
    required this.hashrate,
    required this.shares,
    required this.stale,
    required this.invalid,
    required this.blocks,
    this.lastSeen,
    this.status,
    this.currentDifficulty,
    this.sessionUptime,
  });

  static WorkerInfo? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return WorkerInfo(
      instance: json['instance'] as String? ?? '',
      worker: json['worker'] as String? ?? '',
      wallet: json['wallet'] as String? ?? '',
      hashrate: (json['hashrate'] as num?)?.toDouble() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as num?)?.toInt() ?? 0,
      invalid: (json['invalid'] as num?)?.toInt() ?? 0,
      blocks: (json['blocks'] as num?)?.toInt() ?? 0,
      lastSeen: (json['lastSeen'] as num?)?.toInt(),
      status: json['status'] as String?,
      currentDifficulty: (json['currentDifficulty'] as num?)?.toDouble(),
      sessionUptime: (json['sessionUptime'] as num?)?.toInt(),
    );
  }
}

class BlockInfo {
  final String instance;
  final String worker;
  final String wallet;
  final String timestamp;
  final String hash;

  const BlockInfo({
    required this.instance,
    required this.worker,
    required this.wallet,
    required this.timestamp,
    required this.hash,
  });

  static BlockInfo? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BlockInfo(
      instance: json['instance'] as String? ?? '',
      worker: json['worker'] as String? ?? '',
      wallet: json['wallet'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
    );
  }
}

/// `GET /api/stats`
class BridgeStats {
  final int totalBlocks;
  final int totalShares;
  final int networkHashrate;
  final double networkDifficulty;
  final int networkBlockCount;
  final int activeWorkers;
  final InternalCpuStats? internalCpu;
  final bool miningEnabled;
  final List<BlockInfo> blocks;
  final List<WorkerInfo> workers;
  final int? bridgeUptime;

  const BridgeStats({
    required this.totalBlocks,
    required this.totalShares,
    required this.networkHashrate,
    required this.networkDifficulty,
    required this.networkBlockCount,
    required this.activeWorkers,
    required this.internalCpu,
    this.miningEnabled = false,
    required this.blocks,
    required this.workers,
    this.bridgeUptime,
  });

  static BridgeStats? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rawBlocks = json['blocks'];
    final rawWorkers = json['workers'];
    // A non-list where a list belongs means the API shape changed. Treat the
    // whole body as unusable rather than reporting a false zero, which would
    // read as "no blocks found" and hide a broken bridge.
    if (rawBlocks != null && rawBlocks is! List) return null;
    if (rawWorkers != null && rawWorkers is! List) return null;
    final blocks =
        (rawBlocks as List?)
            ?.whereType<Object?>()
            .map(BlockInfo.tryParse)
            .whereType<BlockInfo>()
            .toList() ??
        const <BlockInfo>[];
    final workers =
        (rawWorkers as List?)
            ?.whereType<Object?>()
            .map(WorkerInfo.tryParse)
            .whereType<WorkerInfo>()
            .toList() ??
        const <WorkerInfo>[];
    return BridgeStats(
      totalBlocks: (json['totalBlocks'] as num?)?.toInt() ?? 0,
      totalShares: (json['totalShares'] as num?)?.toInt() ?? 0,
      networkHashrate: (json['networkHashrate'] as num?)?.toInt() ?? 0,
      networkDifficulty: (json['networkDifficulty'] as num?)?.toDouble() ?? 0,
      networkBlockCount: (json['networkBlockCount'] as num?)?.toInt() ?? 0,
      activeWorkers: (json['activeWorkers'] as num?)?.toInt() ?? 0,
      internalCpu: InternalCpuStats.tryParse(json['internalCpu']),
      miningEnabled: (json['miningEnabled'] as bool?) ?? false,
      blocks: blocks,
      workers: workers,
      bridgeUptime: (json['bridgeUptime'] as num?)?.toInt(),
    );
  }

  /// A copy with [miningEnabled] overridden, used to reflect a confirmed
  /// start/stop without waiting for the next poll.
  BridgeStats withMiningEnabled(bool enabled) => BridgeStats(
    totalBlocks: totalBlocks,
    totalShares: totalShares,
    networkHashrate: networkHashrate,
    networkDifficulty: networkDifficulty,
    networkBlockCount: networkBlockCount,
    activeWorkers: activeWorkers,
    internalCpu: internalCpu,
    miningEnabled: enabled,
    blocks: blocks,
    workers: workers,
    bridgeUptime: bridgeUptime,
  );
}

/// A snapshot of everything the app shows, fetched together.
class MinerSnapshot {
  final BridgeStatus? status;
  final BridgeStats? stats;

  const MinerSnapshot({this.status, this.stats});

  /// True when the bridge has an internal CPU miner it can start and stop.
  /// External ASICs (the usual wireless-pool setup) never report one, so the
  /// start/stop control stays hidden for them.
  bool get miningAvailable => stats?.internalCpu != null;

  /// Whether mining is switched on right now: a miner exists and its runtime
  /// toggle is not paused.
  bool get miningEnabled => stats?.miningEnabled ?? false;

  /// True when a miner is present AND switched on.
  bool get isMining => miningAvailable && miningEnabled;

  /// Local hashrate in GH/s, or 0 when not mining.
  double get hashrateGhs => stats?.internalCpu?.hashrateGhs ?? 0;

  int get blocksAccepted => stats?.internalCpu?.blocksAccepted ?? 0;
  int get blocksSubmitted => stats?.internalCpu?.blocksSubmitted ?? 0;
  int get shares => stats?.internalCpu?.shares ?? 0;
  int get stale => stats?.internalCpu?.stale ?? 0;
  int get invalid => stats?.internalCpu?.invalid ?? 0;

  /// A copy with only the mining switch state changed, so a confirmed start or
  /// stop can update the UI without discarding the rest of the snapshot.
  MinerSnapshot withMiningEnabled(bool enabled) =>
      MinerSnapshot(status: status, stats: stats?.withMiningEnabled(enabled));
}

/// `GET /api/mining` and `POST /api/mining` — the bridge's runtime mining
/// switch. [enabled] is the switch state, [available] whether a startable
/// internal CPU miner exists at all.
class MiningControl {
  final bool enabled;
  final bool available;

  const MiningControl({required this.enabled, required this.available});

  static MiningControl? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return MiningControl(
      enabled: (json['enabled'] as bool?) ?? false,
      available: (json['available'] as bool?) ?? false,
    );
  }
}

/// `GET /api/balance` — an account balance in pradha.
/// 1 CEN = 1e8 pradha (the smallest unit). The bridge returns only the integer
/// pradha count, so the CEN value is derived here rather than trusted from JSON.
class AccountBalance {
  final String address;
  final int pradha;

  const AccountBalance({required this.address, required this.pradha});

  static const int _pradhaPerCen = 100000000;

  /// `pradha` rendered as CEN with up to 8 fractional digits and no trailing
  /// zeros. Computed from the integer so large balances stay exact — a `double`
  /// would silently round once pradha passes 2^53.
  String get formattedCen {
    final whole = pradha ~/ _pradhaPerCen;
    final frac = pradha % _pradhaPerCen;
    var text = '$whole.${frac.toString().padLeft(8, '0')}';
    text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return text;
  }

  /// `null` when the bridge answered an error body (node not ready / unknown
  /// address) — "no balance" must not be mistaken for "zero balance".
  static AccountBalance? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    if (json.containsKey('error')) return null;
    final pradha = (json['balancePradha'] as num?)?.toInt();
    if (pradha == null) return null;
    return AccountBalance(
      address: json['address'] as String? ?? '',
      pradha: pradha,
    );
  }
}

/// `POST /api/send` — a submitted transfer's transaction id, or the bridge's
/// error text when the node rejected it.
class SendResult {
  final String? txid;
  final String? error;

  const SendResult({this.txid, this.error});

  /// True when the bridge returned a transaction id, i.e. the transfer was
  /// accepted into the mempool.
  bool get ok => txid != null;

  /// `null` when the body carried neither a txid nor an error.
  static SendResult? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final txid = json['txid'] as String?;
    final error = json['error'] as String?;
    if (txid == null && error == null) return null;
    return SendResult(txid: txid, error: error);
  }
}

/// Off-chain participation balance, separate from the wallet's on-chain funds.
class FaucetBalance {
  final int balancePradha;
  final int totalClaimedPradha;
  final bool canClaimToday;

  /// Server-authoritative claimable delta; null on older bridges.
  final int? rewardPradha;
  final int? dailyRewardPradha;
  final int? claimedTodayPradha;
  final int? accruedTodayPradha;
  final int? serverTimeSecs;
  final int? dripDurationSecs;
  final bool? canStartDrip;
  final int? pendingPreviousPradha;
  final String? rewardModel;

  const FaucetBalance({
    required this.balancePradha,
    required this.totalClaimedPradha,
    required this.canClaimToday,
    this.rewardPradha,
    this.dailyRewardPradha,
    this.claimedTodayPradha,
    this.accruedTodayPradha,
    this.serverTimeSecs,
    this.dripDurationSecs,
    this.canStartDrip,
    this.pendingPreviousPradha,
    this.rewardModel,
  });

  static FaucetBalance? tryParse(Object? json) {
    if (json is! Map<String, dynamic> || json.containsKey('error')) return null;
    final balance = _faucetInt(json['balancePradha']);
    final total = _faucetInt(json['totalClaimedPradha']);
    final can = json['canClaimToday'];
    if (balance == null || total == null || can is! bool) return null;
    if (json['canStartDrip'] != null && json['canStartDrip'] is! bool) {
      return null;
    }
    if (!_validOptionalFaucetInts(json, const [
      'rewardPradha',
      'dailyRewardPradha',
      'claimedTodayPradha',
      'accruedTodayPradha',
      'serverTimeSecs',
      'dripDurationSecs',
      'pendingPreviousPradha',
    ])) {
      return null;
    }
    return FaucetBalance(
      balancePradha: balance,
      totalClaimedPradha: total,
      canClaimToday: can,
      rewardPradha: _faucetInt(json['rewardPradha']),
      dailyRewardPradha: _faucetInt(json['dailyRewardPradha']),
      claimedTodayPradha: _faucetInt(json['claimedTodayPradha']),
      accruedTodayPradha: _faucetInt(json['accruedTodayPradha']),
      serverTimeSecs: _faucetInt(json['serverTimeSecs']),
      dripDurationSecs: _faucetInt(json['dripDurationSecs']),
      canStartDrip: json['canStartDrip'] as bool?,
      pendingPreviousPradha: _faucetInt(json['pendingPreviousPradha']),
      rewardModel: json['rewardModel'] is String
          ? json['rewardModel'] as String
          : null,
    );
  }
}

/// A credited claim delta or a bridge error, including its optional stable code.
class FaucetClaimResult {
  final int balancePradha;
  final int rewardPradha;
  final int? dailyRewardPradha;
  final int? claimedTodayPradha;
  final String? error;
  final String? errorCode;
  final bool? startedDrip;
  final String? rewardModel;

  const FaucetClaimResult.success({
    required this.balancePradha,
    required this.rewardPradha,
    this.dailyRewardPradha,
    this.claimedTodayPradha,
    this.startedDrip,
    this.rewardModel,
  }) : error = null,
       errorCode = null;

  const FaucetClaimResult.failure({required String this.error, this.errorCode})
    : balancePradha = 0,
      rewardPradha = 0,
      dailyRewardPradha = null,
      claimedTodayPradha = null,
      startedDrip = null,
      rewardModel = null;

  bool get ok => error == null;

  static FaucetClaimResult? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final error = json['error'];
    if (error is String) {
      return FaucetClaimResult.failure(
        error: error,
        errorCode: json['errorCode'] is String
            ? json['errorCode'] as String
            : null,
      );
    }
    final balance = _faucetInt(json['balancePradha']);
    final reward = _faucetInt(json['rewardPradha']);
    if (json['ok'] != true || balance == null || reward == null) return null;
    if (json['startedDrip'] != null && json['startedDrip'] is! bool) {
      return null;
    }
    if (!_validOptionalFaucetInts(json, const [
      'dailyRewardPradha',
      'claimedTodayPradha',
    ])) {
      return null;
    }
    return FaucetClaimResult.success(
      balancePradha: balance,
      rewardPradha: reward,
      dailyRewardPradha: _faucetInt(json['dailyRewardPradha']),
      claimedTodayPradha: _faucetInt(json['claimedTodayPradha']),
      startedDrip: json['startedDrip'] as bool?,
      rewardModel: json['rewardModel'] is String
          ? json['rewardModel'] as String
          : null,
    );
  }
}

/// Withdrawal acceptance is distinct from confirmation on the blockchain.
class FaucetWithdrawResult {
  final bool ok;
  final String? txid;
  final int? amountPradha;
  final int? feePradha;
  final int? balancePradha;
  final String? error;
  final String? errorCode;
  final int? remainingSecs;
  final int? minAmountPradha;

  const FaucetWithdrawResult._({
    required this.ok,
    this.txid,
    this.amountPradha,
    this.feePradha,
    this.balancePradha,
    this.error,
    this.errorCode,
    this.remainingSecs,
    this.minAmountPradha,
  });

  static FaucetWithdrawResult? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    var txid = json['txid'] is String && (json['txid'] as String).isNotEmpty
        ? json['txid'] as String
        : null;
    final error = json['error'];
    final errorCode = json['errorCode'] is String
        ? json['errorCode'] as String
        : null;
    if (error is String) {
      if (errorCode == 'TransferPending') {
        final pendingTxid = json['pendingTxid'];
        if (pendingTxid is String &&
            pendingTxid.length == 64 &&
            RegExp(r'^[0-9a-fA-F]+$').hasMatch(pendingTxid)) {
          if (txid != null && txid != pendingTxid) return null;
          txid = pendingTxid;
        }
      }
      return FaucetWithdrawResult._(
        ok: false,
        error: error,
        txid: txid,
        errorCode: errorCode,
        balancePradha: _faucetInt(json['balancePradha']),
        remainingSecs: _faucetInt(json['remainingSecs']),
        minAmountPradha: _faucetInt(json['minAmountPradha']),
      );
    }
    if (errorCode == 'TransferPending') return null;
    final amount = _faucetInt(json['amountPradha']);
    final fee = _faucetInt(json['feePradha']);
    final balance = _faucetInt(json['balancePradha']);
    if (json['ok'] != true ||
        txid == null ||
        amount == null ||
        amount == 0 ||
        fee == null ||
        balance == null) {
      return null;
    }
    return FaucetWithdrawResult._(
      ok: true,
      txid: txid,
      amountPradha: amount,
      feePradha: fee,
      balancePradha: balance,
    );
  }
}

int? _faucetInt(Object? value) {
  if (value is int) return value >= 0 ? value : null;
  if (value is! double || !value.isFinite || value < 0) return null;
  final integer = value.toInt();
  return integer == value ? integer : null;
}

bool _validOptionalFaucetInts(Map<String, dynamic> json, List<String> keys) =>
    keys.every((key) => json[key] == null || _faucetInt(json[key]) != null);
