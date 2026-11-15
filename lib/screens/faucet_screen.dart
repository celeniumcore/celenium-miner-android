import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/bridge_api.dart';
import '../services/device_identity.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/surface.dart';

class FaucetScreen extends StatefulWidget {
  const FaucetScreen({super.key, required this.address, required this.api});

  final String address;
  final BridgeApi? api;

  @override
  State<FaucetScreen> createState() => _FaucetScreenState();
}

class _FaucetScreenState extends State<FaucetScreen> {
  bool _loading = true;
  bool _claiming = false;
  bool _claimedToday = false;
  int? _balancePradha;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FaucetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address || oldWidget.api != widget.api) {
      _load();
    }
  }

  Future<void> _load() async {
    final api = widget.api;
    final address = widget.address;
    if (api == null || address.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _balancePradha = null;
        _claimedToday = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await api.getFaucetBalance(address);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _balancePradha = result.balancePradha;
        _claimedToday = !result.canClaimToday;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _claim() async {
    final api = widget.api;
    final address = widget.address;
    if (api == null || address.isEmpty || _claiming) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      final deviceId = await deviceIdentity();
      final result = await api.claimFaucet(address, deviceId: deviceId);
      if (!mounted) return;
      if (result.ok) {
        setState(() {
          _claiming = false;
          _claimedToday = true;
          _balancePradha = result.balancePradha ?? _balancePradha;
          _error = null;
        });
        final reward = result.rewardPradha ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10nOf(context).faucetClaimed(reward))),
        );
      } else {
        final err = (result.error ?? '').toLowerCase();
        final already = err.contains('already');
        setState(() {
          _claiming = false;
          _claimedToday = already || _claimedToday;
          _error = already ? null : result.error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              already
                  ? l10nOf(context).faucetAlreadyClaimed
                  : l10nOf(context).faucetClaimFailed,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _claiming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10nOf(context).faucetClaimFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final ready = widget.api != null && widget.address.isNotEmpty;
    final canClaim = ready && !_loading && !_claiming && !_claimedToday;

    return CenContent(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CenCard(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_balancePradha != null)
                        Text(
                          _formatPradha(_balancePradha!),
                          style: TypeScale.mono(context, size: 28).copyWith(
                            color: Palette.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_error != null && _error!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TypeScale.label(context)
                              .copyWith(color: Palette.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canClaim ? _claim : null,
                          child: Text(
                            _claiming
                                ? l10n.faucetClaiming
                                : _claimedToday
                                ? l10n.faucetAlreadyClaimed
                                : l10n.faucetClaim,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _formatPradha(int pradha) {
  final negative = pradha < 0;
  var p = pradha.abs();
  final whole = p ~/ 100000000;
  final frac = p % 100000000;
  var fracTrim = frac.toString().padLeft(8, '0');
  if (fracTrim.length > 4) {
    fracTrim = fracTrim.substring(0, 4).replaceFirst(RegExp(r'0+$'), '');
  }
  if (fracTrim.isEmpty) fracTrim = '0';
  final s = fracTrim == '0' ? '$whole' : '$whole.$fracTrim';
  return negative ? '-$s' : s;
}
