import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/bridge_api.dart';
import '../services/device_identity.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import 'cen_ui.dart';

/// Claims credit the off-chain balance; withdrawals remain a separate action.
class FaucetCard extends StatefulWidget {
  const FaucetCard({
    super.key,
    required this.address,
    required this.api,
    this.onWithdrawn,
  });

  final String address;
  final BridgeApi? api;
  final VoidCallback? onWithdrawn;

  @override
  State<FaucetCard> createState() => _FaucetCardState();
}

class _FaucetCardState extends State<FaucetCard> with WidgetsBindingObserver {
  FaucetBalance? _balance;
  FaucetClaimResult? _claimFailure;
  Timer? _poll;
  bool _busy = false;
  bool _withdrawing = false;
  bool _withdrawNeedsReview = false;
  bool _reading = false;
  bool _failed = false;
  int _epoch = 0;

  bool get _available => widget.api != null && widget.address.isNotEmpty;
  bool get _working => _busy || _withdrawing;
  int get _minWithdrawPradha => _balance?.minWithdrawPradha ?? 1000;
  bool get _canWithdraw =>
      !_working &&
      !_reading &&
      !_failed &&
      !_withdrawNeedsReview &&
      _available &&
      _balance != null &&
      _balance!.balancePradha >= _minWithdrawPradha;
  bool get _canClaim => !_working;

  bool get _dailyPool => _balance?.rewardModel == 'daily-pool-halving';
  bool get _daily => _dailyPool || _balance?.rewardModel == 'daily-fixed';
  bool get _activating =>
      !_daily &&
      (_balance?.canStartDrip ?? false) &&
      (_balance?.rewardPradha ?? 0) == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant FaucetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address || oldWidget.api != widget.api) {
      _epoch++;
      _balance = null;
      _claimFailure = null;
      _busy = false;
      _withdrawing = false;
      _withdrawNeedsReview = false;
      _reading = false;
      _failed = false;
      _startPolling();
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      if (!_working) _refresh();
    } else {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    if (!_available) return;
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_working && TickerMode.valuesOf(context).enabled) _refresh();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = widget.api;
    if (!_available || api == null || _reading) return;
    final epoch = _epoch;
    final address = widget.address;
    setState(() => _reading = true);
    try {
      final balance = await api.fetchFaucetBalance(address);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _failed = balance == null;
        if (balance != null) {
          _balance = balance;
          if (balance.canClaimToday || balance.canStartDrip == true) {
            _claimFailure = null;
          }
        }
      });
    } on Object {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _reading = false);
    }
  }

  Future<void> _claim() async {
    final api = widget.api;
    if (!_canClaim) return;
    if (!_available || api == null) {
      final l10n = l10nOf(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            widget.address.isEmpty
                ? l10n.faucetNeedsWallet
                : l10n.faucetUnavailable,
          ),
        ),
      );
      return;
    }
    final address = widget.address;
    final epoch = ++_epoch;
    final previous = _balance;
    setState(() {
      _busy = true;
      _reading = false;
      _claimFailure = null;
    });
    try {
      final deviceId = await androidId() ?? '';
      if (!mounted || epoch != _epoch) return;
      final result = await api.claimFaucet(address, deviceId);
      if (!mounted || epoch != _epoch) return;
      final l10n = l10nOf(context);
      setState(() {
        _claimFailure = result.ok ? null : result;
        if (result.ok) {
          // Do not reuse a pre-claim delta while the follow-up read is pending.
          _balance = FaucetBalance(
            balancePradha: result.balancePradha,
            totalClaimedPradha:
                (previous?.totalClaimedPradha ?? 0) + result.rewardPradha,
            canClaimToday: false,
            rewardPradha: 0,
            dailyRewardPradha:
                result.dailyRewardPradha ?? previous?.dailyRewardPradha,
            claimedTodayPradha: result.claimedTodayPradha,
            rewardModel: result.rewardModel ?? previous?.rewardModel,
            minWithdrawPradha:
                result.minWithdrawPradha ?? previous?.minWithdrawPradha,
            minRewardPradha:
                result.minRewardPradha ?? previous?.minRewardPradha,
            maxRewardPradha:
                result.maxRewardPradha ?? previous?.maxRewardPradha,
          );
        }
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            result.ok
                ? (result.startedDrip == true && result.rewardPradha == 0
                      ? l10n.faucetActivated
                      : l10n.faucetClaimed(result.rewardPradha))
                : _errorText(l10n, result),
          ),
        ),
      );
      await _refresh();
    } on Object {
      if (!mounted || epoch != _epoch) return;
      setState(() => _failed = true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10nOf(context).faucetClaimFailed)),
      );
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (!_canWithdraw) return;
    final api = widget.api!;
    final address = widget.address;
    final amount = _balance!.balancePradha;
    final epoch = ++_epoch;
    final l10n = l10nOf(context);
    setState(() => _withdrawing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.faucetWithdraw),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.faucetWithdrawConfirm(amount)),
                const SizedBox(height: Palette.md),
                SelectableText(address, style: TypeScale.mono(dialogContext)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.faucetCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.faucetConfirmWithdraw),
            ),
          ],
        ),
      );
      if (!mounted || epoch != _epoch || confirmed != true) return;
      final result = await api.withdrawFaucet(address, amountPradha: amount);
      if (!mounted || epoch != _epoch) return;
      final previous = _balance!;
      setState(() {
        _withdrawNeedsReview = !result.ok && result.txid != null;
        if (result.balancePradha != null) {
          _balance = FaucetBalance(
            balancePradha: result.balancePradha!,
            totalClaimedPradha: previous.totalClaimedPradha,
            canClaimToday: false,
            rewardPradha: 0,
            dailyRewardPradha: previous.dailyRewardPradha,
            claimedTodayPradha: previous.claimedTodayPradha,
            rewardModel: previous.rewardModel,
            minWithdrawPradha: previous.minWithdrawPradha,
            minRewardPradha: previous.minRewardPradha,
            maxRewardPradha: previous.maxRewardPradha,
          );
        }
      });
      await _refresh();
      if (!mounted || epoch != _epoch) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            result.ok
                ? l10n.faucetWithdrawSubmitted
                : result.txid != null
                ? l10n.faucetWithdrawReview
                : l10n.faucetWithdrawFailed,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.ok
                      ? l10n.faucetWithdrawAccepted(
                          result.amountPradha!,
                          result.feePradha!,
                        )
                      : result.txid != null
                      ? l10n.faucetWithdrawUncertain
                      : _withdrawError(l10n, result),
                ),
                if (result.txid != null) ...[
                  const SizedBox(height: Palette.md),
                  const Text('TXID'),
                  SelectableText(
                    result.txid!,
                    style: TypeScale.mono(dialogContext),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.faucetClose),
            ),
          ],
        ),
      );
      if (!mounted || epoch != _epoch) return;
      if (result.ok || result.txid != null) widget.onWithdrawn?.call();
    } on Object {
      if (!mounted || epoch != _epoch) return;
      setState(() => _failed = true);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(l10n.faucetWithdrawNetwork)));
    } finally {
      if (mounted && epoch == _epoch) setState(() => _withdrawing = false);
    }
  }

  String _withdrawError(AppLocalizations l10n, FaucetWithdrawResult result) {
    final error = result.error ?? '';
    final code = result.errorCode;
    if (code == 'SmallTransferNotSupported' || error.contains('storage mass')) {
      return l10n.faucetSmallTransferUnsupported;
    }
    if (code == 'StorageUnavailable' || error.contains('storage')) {
      return l10n.faucetStorageUnavailable;
    }
    if (code == 'ReservoirUnfunded' || error.contains('no on-chain funds')) {
      return l10n.faucetUnfunded;
    }
    if (code == 'NotConfigured' || error.contains('not configured')) {
      return l10n.faucetWithdrawNotConfigured;
    }
    if (code == 'Cooldown' || error.startsWith('please wait ')) {
      final seconds =
          result.remainingSecs ??
          int.tryParse(
            RegExp(r'please wait (\d+) seconds').firstMatch(error)?.group(1) ??
                '',
          );
      return seconds == null
          ? l10n.faucetWithdrawCooldown
          : l10n.faucetWithdrawWait(seconds);
    }
    if (code == 'BelowMinimum' ||
        result.minAmountPradha != null ||
        error.contains('minimum withdrawal')) {
      return l10n.faucetWithdrawMinimum(
        result.minAmountPradha ?? _minWithdrawPradha,
      );
    }
    if (code == 'FeeBudgetExhausted' || error.contains('fee budget')) {
      return l10n.faucetWithdrawFeeBudget;
    }
    if (code == 'InvalidAddress' || error.contains('valid Celenium address')) {
      return l10n.faucetInvalidAddress;
    }
    return l10n.faucetWithdrawRetry;
  }

  String _errorText(AppLocalizations l10n, FaucetClaimResult failure) =>
      switch (failure.errorCode ?? failure.error) {
        'NothingAccrued' || 'nothing accrued yet' =>
          _daily ? l10n.faucetNotEligible : l10n.faucetNothingAccrued,
        'AlreadyClaimed' ||
        'already claimed today' => l10n.faucetAlreadyClaimed,
        'DailyCapReached' => l10n.faucetDailyCap,
        'ReservoirFull' => l10n.faucetReservoirFull,
        'InvalidAddress' => l10n.faucetInvalidAddress,
        'StorageUnavailable' => l10n.faucetStorageUnavailable,
        _ => l10n.faucetClaimFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final balance = _balance;
    final quota = balance?.dailyRewardPradha;
    final claimed = balance?.claimedTodayPradha;
    final capped =
        quota != null && quota > 0 && claimed != null && claimed >= quota;
    final String? status = _withdrawNeedsReview
        ? l10n.faucetWithdrawUncertain
        : !_available
        ? (widget.address.isEmpty
              ? l10n.faucetNeedsWallet
              : l10n.faucetUnavailable)
        : _failed
        ? l10n.faucetLoadFailed
        : balance == null
        ? l10n.faucetLoading
        : _claimFailure != null
        ? _errorText(l10n, _claimFailure!)
        : _activating
        ? l10n.faucetActivationInfo
        : capped && !balance.canClaimToday
        ? (_daily ? l10n.faucetAlreadyClaimed : l10n.faucetDailyCap)
        : balance.rewardPradha == 0 && (quota ?? 0) > 0
        ? (_daily ? l10n.faucetNotEligible : l10n.faucetNothingAccrued)
        : !balance.canClaimToday
        ? l10n.faucetNotEligible
        : balance.rewardPradha == null
        ? l10n.faucetLegacyReady
        : null;

    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.faucetTitle,
                  style: TypeScale.headline(context),
                ),
              ),
              IconButton(
                tooltip: l10n.faucetRefresh,
                onPressed: !_available || _reading || _working
                    ? null
                    : _refresh,
                color: Palette.slateLight,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (balance != null) ...[
            const SizedBox(height: Palette.sm),
            Text(
              l10n.faucetBalance(balance.balancePradha),
              style: TypeScale.title(context),
            ),
            const SizedBox(height: Palette.md),
            if (_daily && quota != null) ...[
              Text(
                l10n.faucetDailyReward(quota),
                style: TypeScale.title(context)
                    .copyWith(color: Palette.goldLight),
              ),
              const SizedBox(height: Palette.xs),
            ],
            if (balance.rewardPradha != null)
              Text(
                l10n.faucetReady(balance.rewardPradha!),
                style: TypeScale.title(context)
                    .copyWith(color: _daily ? Palette.ink : Palette.goldLight),
              ),
            if (quota != null && !_daily) ...[
              const SizedBox(height: Palette.xs),
              Text(l10n.faucetQuota(quota), style: TypeScale.label(context)),
            ],
            if (claimed != null) ...[
              const SizedBox(height: Palette.xs),
              Text(
                l10n.faucetClaimedToday(claimed),
                style: TypeScale.label(context),
              ),
            ],
            if ((balance.pendingPreviousPradha ?? 0) > 0) ...[
              const SizedBox(height: Palette.xs),
              Text(
                l10n.faucetPendingPrevious(balance.pendingPreviousPradha!),
                style: TypeScale.label(context),
              ),
            ],
            if (_dailyPool &&
                balance.minRewardPradha != null &&
                balance.maxRewardPradha != null) ...[
              const SizedBox(height: Palette.xs),
              Text(
                l10n.faucetDailyPoolBounds(
                  balance.minRewardPradha!,
                  balance.maxRewardPradha!,
                ),
                style: TypeScale.label(context),
              ),
            ],
          ],
          if (status != null) ...[
            const SizedBox(height: Palette.md),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                style: TypeScale.label(
                  context,
                ).copyWith(color: _failed ? Palette.red : Palette.slateLight),
              ),
            ),
          ],
          const SizedBox(height: Palette.lg),
          FilledButton(
            onPressed: _canClaim ? _claim : null,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.goldDim,
              padding: const EdgeInsets.symmetric(
                horizontal: Palette.lg,
                vertical: Palette.md,
              ),
            ),
            child: Text(
              _busy
                  ? l10n.faucetClaiming
                  : _activating
                  ? l10n.faucetActivate
                  : _daily || balance == null
                  ? l10n.faucetClaimDaily
                  : l10n.faucetClaim,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Palette.md),
          OutlinedButton(
            onPressed: _canWithdraw ? _withdraw : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Palette.slate),
              padding: const EdgeInsets.symmetric(
                horizontal: Palette.lg,
                vertical: Palette.md,
              ),
            ),
            child: Text(
              _withdrawing ? l10n.faucetWithdrawing : l10n.faucetWithdraw,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Palette.md),
          Text(
            _dailyPool
                ? l10n.faucetDailyPoolInfo(_minWithdrawPradha)
                : _daily || balance == null
                ? l10n.faucetDailyInfo(_minWithdrawPradha)
                : l10n.faucetInfo(_minWithdrawPradha),
            style: TypeScale.caption(context),
          ),
        ],
      ),
    );
  }
}
