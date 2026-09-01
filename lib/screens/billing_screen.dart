library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/external_links.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';

class BillingScreen extends StatefulWidget {
  final bool embedded;

  const BillingScreen({super.key, this.embedded = false});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin, ConnectionReloadMixin<BillingScreen> {
  late final TabController _tabs;
  final _thresholdController = TextEditingController();
  final _reloadController = TextEditingController();
  BillingState? _billing;
  SubscriptionState? _subscription;
  UsageBars? _usageBars;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  ApiClient? _loadedApi;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _billing = null;
      _subscription = null;
      _usageBars = null;
      _loadedApi = null;
      _busy = false;
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.billingNotConnected;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        api.billingState(),
        api.subscriptionState(),
        api.usageBars().onError((_, _) => UsageBars()),
      ]);
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      final billing = results[0] as BillingState;
      setState(() {
        _billing = billing;
        _subscription = results[1] as SubscriptionState;
        _usageBars = results[2] as UsageBars;
        _loadedApi = api;
        _thresholdController.text =
            billing.autoReloadConfig?.threshold?.toString() ?? '';
        _reloadController.text =
            billing.autoReloadConfig?.reloadTo?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Uri? get _portal {
    final candidate = _subscription?.portalUrl ?? _billing?.portalUrl;
    return candidate != null && candidate.hasScheme ? candidate : null;
  }

  Future<void> _openPortal({String? tierId}) async {
    final api = _loadedApi;
    if (api == null || !_ownsTarget(api, _mutationGeneration)) {
      showHermesToast(context, message: context.l10n.backendDisconnected);
      return;
    }
    final portal = _portal;
    if (portal == null) {
      showHermesToast(context, message: context.l10n.billingPortalMissing);
      return;
    }
    final query = {
      ...portal.queryParameters,
      if ((_subscription?.orgId ?? '').isNotEmpty)
        'org_id': _subscription!.orgId!,
      'plan': ?tierId,
    };
    final opened = await launchUrl(
      portal.replace(queryParameters: query),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showHermesToast(context, message: context.l10n.billingPortalOpenFailed);
    }
  }

  Future<void> _showFailure(
    Object error,
    String title, {
    VoidCallback? onRetry,
  }) async {
    if (!mounted) return;
    final details = error is ApiException ? error.details : null;
    final rawError = details?['error'];
    final nested = rawError is Map
        ? rawError.cast<String, dynamic>()
        : const <String, dynamic>{};
    // Desktop parity (`errors.ts` `resolveRefusal`): a flat `error` STRING is
    // the typed refusal kind (e.g. "insufficient_scope") — only when it's a
    // Map does it carry a nested message/recovery/portal_url instead.
    final refusalKind = rawError is String
        ? rawError
        : nested['code']?.toString();
    final message =
        nested['message']?.toString() ??
        details?['message']?.toString() ??
        (error is ApiException ? error.message : '$error');
    final recovery =
        nested['recovery']?.toString() ?? details?['recovery']?.toString();
    final portalRaw =
        nested['portal_url']?.toString() ?? details?['portal_url']?.toString();
    final portal = Uri.tryParse(portalRaw ?? '');
    final needsStepUp = refusalKind == 'insufficient_scope';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          [
            message,
            if (recovery != null && recovery.isNotEmpty) recovery,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonClose),
          ),
          if (needsStepUp)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(_startStepUp(onGranted: onRetry));
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(context.l10n.billingVerifyAndContinue),
            )
          else if (portal != null && portal.hasScheme)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(
                  launchExternalOrNotify(
                    context,
                    portal,
                    failureMessage: context.l10n.billingPortalOpenFailed,
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.billingOpenPortal),
            ),
        ],
      ),
    );
  }

  /// Desktop parity: `use-step-up.ts`. Starts the remote-spending step-up
  /// RPC and, while it's in flight, listens for the `billing.step_up.
  /// verification` gateway event carrying the device-code — shown inline so
  /// the user can open the verification page without leaving the app.
  Future<void> _startStepUp({VoidCallback? onGranted}) async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    final generation = _mutationGeneration;
    if (api == null || !_ownsTarget(api, generation)) return;
    final gateway = connection.gateway;
    if (gateway == null) {
      if (mounted) {
        showHermesToast(context, message: context.l10n.billingGatewayMissing);
      }
      return;
    }
    String? userCode;
    String? verificationUrl;
    late StateSetter dialogSetState;
    StreamSubscription? sub;
    var resolved = false;
    // Tracks whether *this* verification dialog is still the one showing —
    // the user can dismiss it (Cancel) while `billingStepUp()` is still in
    // flight, and may have opened a different dialog by the time it
    // resolves. Without this, the unconditional `Navigator.pop()` below pops
    // whatever the top route happens to be at that later moment, which can
    // be that unrelated dialog instead of this (already-closed) one.
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState = setState;
            return AlertDialog(
              title: Text(context.l10n.billingVerificationRequired),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (verificationUrl == null)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(context.l10n.billingVerificationStarting),
                        ),
                      ],
                    )
                  else ...[
                    Text(context.l10n.billingVerificationInstructions),
                    if (userCode != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        userCode!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => launchExternalOrNotify(
                        context,
                        Uri.parse(verificationUrl!),
                        failureMessage: context.l10n.billingPortalOpenFailed,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(context.l10n.billingOpenVerification),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            );
          },
        ),
      ).whenComplete(() {
        dialogOpen = false;
        sub?.cancel();
      }),
    );
    sub = connection.events.listen((event) {
      if (event.type != 'billing.step_up.verification' ||
          resolved ||
          !_ownsTarget(api, generation)) {
        return;
      }
      final url = event.payload['verification_url']?.toString();
      if (url == null || url.isEmpty) return;
      userCode = event.payload['user_code']?.toString();
      verificationUrl = url;
      dialogSetState(() {});
    });
    try {
      final result = await api.billingStepUp();
      resolved = true;
      if (!mounted || !_ownsTarget(api, generation)) return;
      if (dialogOpen && Navigator.canPop(context)) Navigator.of(context).pop();
      if (result['granted'] == true) {
        showHermesToast(
          context,
          message: context.l10n.billingVerificationSucceeded,
          kind: HermesToastKind.success,
        );
        onGranted?.call();
        await _load();
      } else {
        showHermesToast(
          context,
          message: context.l10n.billingVerificationIncomplete,
        );
      }
    } catch (e) {
      resolved = true;
      if (mounted && dialogOpen && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted && _ownsTarget(api, generation)) {
        showHermesToast(
          context,
          message: context.l10n.billingVerificationFailed('$e'),
        );
      }
    }
  }

  Future<void> _charge() async {
    final l10n = context.l10n;
    final billing = _billing;
    if (billing == null) return;
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    final generation = _mutationGeneration;
    if (api == null || !_ownsTarget(api, generation)) return;
    if (!billing.canCharge) {
      if (_portal != null) {
        await _openPortal();
      } else {
        showHermesToast(context, message: context.l10n.billingChargeForbidden);
      }
      return;
    }
    final controller = TextEditingController(
      text: billing.chargePresets.firstOrNull?.toStringAsFixed(0) ?? '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final parsed = double.tryParse(controller.text);
          final valid =
              parsed != null &&
              (billing.minimumCharge == null ||
                  parsed >= billing.minimumCharge!) &&
              (billing.maximumCharge == null ||
                  parsed <= billing.maximumCharge!);
          return AlertDialog(
            title: Text(context.l10n.billingPurchaseCredits),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (billing.chargePresets.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (
                        var index = 0;
                        index < billing.chargePresets.length;
                        index++
                      )
                        ChoiceChip(
                          label: Text(
                            index < billing.chargePresetsDisplay.length
                                ? billing.chargePresetsDisplay[index]
                                : '\$${billing.chargePresets[index]}',
                          ),
                          selected: parsed == billing.chargePresets[index],
                          onSelected: (_) => setDialogState(
                            () => controller.text = billing.chargePresets[index]
                                .toStringAsFixed(0),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: context.l10n.billingAmountUsd,
                    prefixText: '\$',
                    helperText: _chargeBounds(billing),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(ctx, parsed) : null,
                child: Text(context.l10n.billingConfirmPurchase),
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      final key =
          'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      final result = await api.billingCharge(amount, idempotencyKey: key);
      if (!mounted || !_ownsTarget(api, generation)) return;
      final chargeId = result['charge_id']?.toString();
      if (chargeId != null && chargeId.isNotEmpty) {
        await _waitForCharge(api, chargeId, generation);
      }
      if (!mounted || !_ownsTarget(api, generation)) return;
      await _load();
      if (mounted && _ownsTarget(api, generation)) {
        showHermesToast(
          context,
          message: l10n.billingChargeCompleted,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (_ownsTarget(api, generation)) {
        await _showFailure(error, l10n.billingChargeIncomplete);
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  String? _chargeBounds(BillingState billing) {
    if (billing.minimumCharge == null && billing.maximumCharge == null) {
      return null;
    }
    return [
      if (billing.minimumCharge != null)
        context.l10n.billingMinimumCharge('${billing.minimumCharge}'),
      if (billing.maximumCharge != null)
        context.l10n.billingMaximumCharge('${billing.maximumCharge}'),
    ].join(context.l10n.commonListSeparator);
  }

  Future<void> _waitForCharge(
    ApiClient api,
    String chargeId,
    int generation,
  ) async {
    final l10n = context.l10n;
    for (var attempt = 0; attempt < 45; attempt++) {
      if (!_ownsTarget(api, generation)) {
        throw StateError(l10n.backendDisconnected);
      }
      if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 2));
      if (!_ownsTarget(api, generation)) {
        throw StateError(l10n.backendDisconnected);
      }
      final status = await api.billingChargeStatus(chargeId);
      final value = status['status']?.toString().toLowerCase() ?? '';
      if (const {
        'succeeded',
        'settled',
        'complete',
        'completed',
      }.contains(value)) {
        return;
      }
      if (const {
        'failed',
        'declined',
        'canceled',
        'cancelled',
      }.contains(value)) {
        throw ApiException(
          422,
          status['message']?.toString() ?? l10n.billingPaymentIncomplete,
          status,
        );
      }
    }
    throw ApiException(408, l10n.billingPaymentTimeout);
  }

  Future<void> _saveAutoReload(bool enabled) async {
    final l10n = context.l10n;
    final billing = _billing;
    final config = billing?.autoReloadConfig;
    final threshold = double.tryParse(_thresholdController.text);
    final reloadTo = double.tryParse(_reloadController.text);
    if (billing == null || config == null) return;
    if (threshold == null || reloadTo == null) {
      showHermesToast(
        context,
        message: context.l10n.billingInvalidReloadValues,
      );
      return;
    }
    if (billing.minimumCharge != null && reloadTo < billing.minimumCharge!) {
      showHermesToast(context, message: context.l10n.billingReloadBelowMinimum);
      return;
    }
    if (billing.maximumCharge != null && reloadTo > billing.maximumCharge!) {
      showHermesToast(context, message: context.l10n.billingReloadAboveMaximum);
      return;
    }
    final api = _loadedApi;
    final generation = _mutationGeneration;
    if (api == null || !_ownsTarget(api, generation)) return;
    setState(() => _busy = true);
    try {
      await api.updateAutoReload(enabled, threshold, reloadTo);
      if (!mounted || !_ownsTarget(api, generation)) return;
      await _load();
      if (mounted && _ownsTarget(api, generation)) {
        showHermesToast(
          context,
          message: enabled
              ? l10n.billingAutoReloadEnabled
              : l10n.billingAutoReloadDisabled,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (_ownsTarget(api, generation)) {
        await _showFailure(error, l10n.billingAutoReloadUpdateFailed);
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changePlan(SubscriptionTier tier) async {
    final l10n = context.l10n;
    final subscription = _subscription;
    if (subscription == null) return;
    final current = subscription.currentTier;
    final upgrade = current == null || tier.order > current.order;
    if (upgrade && _portal != null) {
      await _openPortal(tierId: tier.id);
      return;
    }
    if (!subscription.canChangePlan) {
      if (_portal != null) {
        await _openPortal(tierId: tier.id);
      } else {
        showHermesToast(
          context,
          message: context.l10n.billingPlanChangeForbidden,
        );
      }
      return;
    }
    final api = _loadedApi;
    final generation = _mutationGeneration;
    if (api == null || !_ownsTarget(api, generation)) return;
    setState(() => _busy = true);
    try {
      final preview = await api.subscriptionPreview({'target_plan': tier.id});
      if (!mounted || !_ownsTarget(api, generation)) return;
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      final effect = preview['effect']?.toString() ?? '';
      final amountCents = (preview['amount_due_now_cents'] as num?)?.toInt();
      final effectiveAt = preview['effective_at']?.toString();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.billingSwitchPlan(tier.name)),
          content: Text(switch (effect) {
            'charge_now' =>
              amountCents == null
                  ? context.l10n.billingUpgradeChargeNow
                  : context.l10n.billingUpgradeAmount(
                      (amountCents / 100).toStringAsFixed(2),
                    ),
            'scheduled' =>
              effectiveAt == null
                  ? context.l10n.billingPlanChangePeriodEnd
                  : context.l10n.billingPlanChangeEffectiveAt(effectiveAt),
            'no_op' => context.l10n.billingPlanAlreadyActive,
            'blocked' =>
              preview['reason']?.toString() ??
                  context.l10n.billingPlanChangeUnavailable,
            _ =>
              upgrade
                  ? context.l10n.billingConfirmUpgrade
                  : context.l10n.billingDowngradePeriodEnd,
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: effect == 'blocked' || effect == 'no_op'
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(context.l10n.commonConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (!_ownsTarget(api, generation)) return;
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      if (upgrade) {
        final result = await api.subscriptionUpgrade({
          'target_plan': tier.id,
          'idempotency_key':
              'mobile-plan-${DateTime.now().microsecondsSinceEpoch}',
        });
        if (!mounted || !_ownsTarget(api, generation)) return;
        final recovery = Uri.tryParse(result['recovery_url']?.toString() ?? '');
        if (recovery != null && recovery.hasScheme) {
          if (!mounted) return;
          await launchExternalOrNotify(
            context,
            recovery,
            failureMessage: context.l10n.billingPortalOpenFailed,
          );
        }
      } else {
        await api.subscriptionChange({'target_plan': tier.id});
      }
      if (!mounted || !_ownsTarget(api, generation)) return;
      await _load();
    } catch (error) {
      if (_ownsTarget(api, generation)) {
        await _showFailure(error, l10n.billingPlanChangeFailed);
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancelSubscription() async {
    final api = _loadedApi;
    if (api == null || !_ownsTarget(api, _mutationGeneration)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.billingCancelAtPeriodEndQuestion),
        content: Text(context.l10n.billingCancelAtPeriodEndDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.billingConfirmCancellation),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runSubscriptionMutation(
      (api) => api.subscriptionChange({'cancel_at_period_end': true}),
      context.l10n.billingCancelFailed,
      expectedApi: api,
    );
  }

  Future<void> _resumeSubscription() async {
    await _runSubscriptionMutation(
      (api) => api.subscriptionResume(),
      context.l10n.billingResumeFailed,
    );
  }

  Future<void> _runSubscriptionMutation(
    Future<Map<String, dynamic>> Function(ApiClient api) action,
    String errorTitle, {
    ApiClient? expectedApi,
  }) async {
    final connection = context.read<ConnectionStore>();
    final api = expectedApi ?? _loadedApi;
    if (api == null) return;
    final generation = _mutationGeneration;
    if (!_ownsTarget(api, generation)) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await action(api);
      if (!mounted || !_ownsTarget(api, generation)) return;
      await _load();
    } catch (error) {
      if (_ownsTarget(api, generation)) {
        await _showFailure(error, errorTitle);
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  bool _ownsTarget(ApiClient api, int generation) =>
      mounted &&
      generation == _mutationGeneration &&
      identical(_loadedApi, api) &&
      identical(context.read<ConnectionStore>().api, api);

  @override
  Widget build(BuildContext context) {
    final body = _loading && _billing == null
        ? HermesLoadingState(label: context.l10n.billingLoading)
        : _billing == null
        ? HermesErrorState(description: _error, onRetry: _load)
        : _content();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.billingTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _content() {
    final billing = _billing!;
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: _load,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _planSummary(),
        ),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              text: context.l10n.billingAccountTab,
            ),
            Tab(
              icon: const Icon(Icons.query_stats),
              text: context.l10n.billingUsageTab,
            ),
            Tab(
              icon: const Icon(Icons.layers_outlined),
              text: context.l10n.billingPlansTab,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_accountTab(billing), _usageTab(billing), _plansTab()],
          ),
        ),
      ],
    );
  }

  Widget _planSummary() {
    final billing = _billing!;
    final subscription = _subscription;
    final tier = subscription?.currentTier;
    final planName =
        tier?.name ??
        subscription?.name ??
        billing.usage?.planName ??
        context.l10n.billingNoActivePlan;
    final pending = subscription?.pendingDowngradeTierName != null
        ? context.l10n.billingPendingDowngrade(
            subscription!.pendingDowngradeDisplay ??
                subscription.pendingDowngradeAt ??
                context.l10n.billingPeriodEnd,
            subscription.pendingDowngradeTierName!,
          )
        : subscription?.canceledAtPeriodEnd == true
        ? context.l10n.billingPendingCancellation(
            subscription!.cancellationEffectiveDisplay ??
                subscription.cancellationEffectiveAt ??
                context.l10n.billingPeriodEnd,
          )
        : null;
    return HermesGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      [
                        if (tier?.priceDisplay.isNotEmpty == true)
                          context.l10n.billingPerMonth(tier!.priceDisplay),
                        if (subscription?.orgName != null)
                          subscription!.orgName!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              HermesStatusChip(
                color: billing.loggedIn
                    ? HermesSemantic.green
                    : HermesSemantic.gray,
                label: billing.loggedIn
                    ? context.l10n.billingLoggedIn
                    : context.l10n.billingLoggedOut,
              ),
            ],
          ),
          if (pending != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(pending)),
                TextButton(
                  onPressed: _busy ? null : _resumeSubscription,
                  child: Text(context.l10n.commonUndo),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountTab(BillingState billing) {
    final payment = billing.paymentMethod;
    final autoReload = billing.autoReloadConfig;
    final cap = billing.monthlyCap;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          icon: Icons.account_balance_wallet_outlined,
          title: context.l10n.billingAccountBalance,
          trailing: billing.balanceDisplay.isNotEmpty
              ? billing.balanceDisplay
              : '\$${billing.balance.toStringAsFixed(2)}',
          child: FilledButton.icon(
            onPressed: _busy || !billing.loggedIn ? null : _charge,
            icon: const Icon(Icons.add),
            label: Text(
              billing.canCharge
                  ? context.l10n.billingPurchaseCredits
                  : context.l10n.billingManageInPortal,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _section(
          icon: Icons.credit_card,
          title: context.l10n.billingPaymentMethod,
          trailing: payment?.display ?? context.l10n.billingNotProvided,
          child: OutlinedButton.icon(
            onPressed: _portal == null ? null : _openPortal,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              payment == null
                  ? context.l10n.commonAdd
                  : context.l10n.commonManage,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (autoReload == null)
          _section(
            icon: Icons.autorenew,
            title: context.l10n.billingAutoReload,
            trailing: context.l10n.billingUnavailableForAccount,
            child: _portal == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: _openPortal,
                    child: Text(context.l10n.billingManageInPortal),
                  ),
          )
        else
          HermesGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.billingAutoReload),
                    subtitle: Text(context.l10n.billingAutoReloadDescription),
                    value: autoReload.enabled,
                    onChanged: _busy ? null : (value) => _saveAutoReload(value),
                  ),
                ),
                if (autoReload.enabled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _thresholdController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: context.l10n.billingTriggerThreshold,
                            prefixText: '\$',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _reloadController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: context.l10n.billingReloadTo,
                            prefixText: '\$',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _saveAutoReload(true),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(context.l10n.billingSaveAutoReload),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (cap != null) ...[
          const SizedBox(height: 12),
          HermesGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.billingMonthlySpendingCap,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      cap.limitDisplay.isNotEmpty
                          ? cap.limitDisplay
                          : cap.limit == null
                          ? context.l10n.billingNotSet
                          : '\$${cap.limit}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: cap.limit == null || cap.limit == 0
                      ? 0
                      : ((cap.spent ?? 0) / cap.limit!).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 6),
                Text(
                  cap.spentDisplay.isEmpty
                      ? context.l10n.billingSpentThisMonth(
                          '\$${cap.spent ?? 0}',
                        )
                      : context.l10n.billingSpentThisMonth(cap.spentDisplay),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _usageTab(BillingState billing) {
    final usage = billing.usage ?? _subscription?.usage ?? _usageBars?.usage;
    if (usage == null || !usage.available) {
      return HermesEmptyState(
        icon: Icons.query_stats,
        title: context.l10n.billingNoUsageData,
        description: context.l10n.billingNoUsageDescription,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          icon: Icons.savings_outlined,
          title: context.l10n.billingAvailableCredits,
          trailing:
              usage.totalSpendableDisplay ??
              billing.balanceDisplay.ifEmpty(
                '\$${billing.balance.toStringAsFixed(2)}',
              ),
          child: Text(
            [
              if (usage.planName != null) usage.planName!,
              if (usage.renewsDisplay != null)
                context.l10n.billingRenews(usage.renewsDisplay!),
            ].join(' · '),
          ),
        ),
        if (usage.planBar != null) ...[
          const SizedBox(height: 12),
          _usageBar(context.l10n.billingPlanCredits, usage.planBar!),
        ],
        if (usage.topupBar != null) ...[
          const SizedBox(height: 12),
          _usageBar(context.l10n.billingTopupCredits, usage.topupBar!),
        ],
      ],
    );
  }

  Widget _usageBar(String title, BillingUsageBar bar) {
    return HermesGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(context.l10n.billingRemaining(bar.remainingDisplay)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: bar.fillFraction),
          const SizedBox(height: 6),
          Text(
            context.l10n.billingUsedOf(bar.spentDisplay, bar.totalDisplay),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _plansTab() {
    final subscription = _subscription;
    if (subscription == null) {
      return HermesLoadingState(label: context.l10n.billingLoadingPlans);
    }
    if (subscription.tiers.isEmpty) {
      return HermesEmptyState(
        icon: Icons.layers_outlined,
        title: context.l10n.billingNoPlans,
        description:
            subscription.error ?? context.l10n.billingViewSubscriptionInPortal,
        primaryLabel: _portal == null ? null : context.l10n.billingOpenPortal,
        onPrimary: _portal == null ? null : _openPortal,
      );
    }
    final current = subscription.currentTier;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final tier in subscription.tiers) ...[
          HermesGlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tier.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (tier.isCurrent || tier.id == subscription.typeId)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: HermesStatusChip(
                                color: HermesSemantic.green,
                                label: context.l10n.billingCurrent,
                              ),
                            ),
                          if (tier.name ==
                              subscription.pendingDowngradeTierName)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: HermesStatusChip(
                                color: HermesSemantic.orange,
                                label: context.l10n.billingPending,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        [
                          if (tier.priceDisplay.isNotEmpty)
                            context.l10n.billingPerMonth(tier.priceDisplay),
                          if (tier.monthlyCredits != null)
                            context.l10n.billingCreditsPerMonth(
                              '${tier.monthlyCredits}',
                            ),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!tier.isCurrent &&
                    tier.id != subscription.typeId &&
                    tier.name != subscription.pendingDowngradeTierName)
                  FilledButton(
                    onPressed: _busy || !tier.isEnabled
                        ? null
                        : () => _changePlan(tier),
                    child: Text(
                      current == null || tier.order > current.order
                          ? context.l10n.commonSelect
                          : context.l10n.billingDowngrade,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (subscription.typeId != null && !subscription.canceledAtPeriodEnd)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: HermesSemantic.red),
            onPressed: _busy || !subscription.canChangePlan
                ? null
                : _cancelSubscription,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(context.l10n.billingCancelAtPeriodEnd),
          ),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String trailing,
    required Widget child,
  }) {
    return HermesGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: Text(
                  trailing,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _tabs.dispose();
    _thresholdController.dispose();
    _reloadController.dispose();
    super.dispose();
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
