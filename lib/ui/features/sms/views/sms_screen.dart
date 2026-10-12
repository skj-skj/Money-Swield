import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/sms_suggestion.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/sms/sms_groups.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/period_names.dart';
import '../../../core/scroll_paging.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/framed_months.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../../core/widgets/two_column_masonry.dart';
import '../../expenses/expense_form_opener.dart';
import '../../recurring/views/recurring_navigation.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/sms_cubit.dart';
import '../view_models/sms_list_cubit.dart';
import 'sms_card.dart';
import 'sms_texts.dart';

/// The suggestions from bank SMS: month frames with sticky day headers like the
/// Photos screen, each day's cards in two columns of their own height. Ignores
/// Home's filters. A tap opens the Add form filled from the SMS (asking first
/// when another draft waits); the dismiss icon removes a card with Undo.
class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key, required this.dependencies, required this.sms});

  final AppDependencies dependencies;

  /// The app-level SMS state: the permission banner, "Checked 14:05", and a
  /// reload when a scan stores new suggestions.
  final SmsCubit sms;

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> with ScrollPaging<SmsScreen> {
  late final _cubit = SmsListCubit(
    repository: widget.dependencies.smsSuggestions,
    drafts: widget.dependencies.drafts,
    paymentMethods: widget.dependencies.paymentMethods,
  )..load();

  late final _opener = ExpenseFormOpener(
    dependencies: widget.dependencies,
    pendingDraft: _cubit.pendingDraft,
    dismissDraft: _cubit.dismissDraft,
    onOpenRecurring: (context, id) =>
        openRecurringFromForm(context, widget.dependencies, id),
  );

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  double get loadMoreLead => 600.0;

  @override
  void loadMore() => _cubit.loadMore();

  @override
  void dispose() {
    _cubit.close();
    // The badge follows what was added or dismissed here.
    widget.sms.refreshCount();
    super.dispose();
  }

  BuildContext get _messengerContext => _scaffoldKey.currentContext ?? context;

  Future<void> _open(SmsSuggestion sms) async {
    final (:opened, :result) = await _opener.openSms(context, sms);
    if (!opened || !mounted) return;
    await _cubit.reload();
    await widget.sms.refreshCount();
    if (!mounted) return;
    showExpenseFormResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      result,
      // Add only: nothing to bin from here.
      onUndoBin: (_) {},
    );
  }

  Future<void> _dismiss(SmsSuggestion sms) async {
    final l10n = AppLocalizations.of(context);
    final messenger = _messenger.currentState;
    var dismissed = false;
    await saveOrShowError(
      _messengerContext,
      () async => dismissed = await _cubit.dismiss(sms.id),
    );
    if (!dismissed || !mounted) return;
    // Each dismiss replaces the last one's snackbar; its Undo brings back the
    // card it names.
    messenger?.hideCurrentSnackBar();
    showMessage(
      messenger,
      l10n.smsDismissed,
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => _cubit.undo(sms.id),
      ),
    );
  }

  /// The banner's Allow. A channel error (a second tap while Android's
  /// dialog is open answers "busy") shows as an error, as Settings → SMS
  /// does, instead of escaping as an unhandled one.
  Future<void> _allow() async {
    var result = SmsEnableResult.enabled;
    await saveOrShowError(
      _messengerContext,
      () async => result = await widget.sms.enable(),
    );
    if (!mounted) return;
    if (result == SmsEnableResult.refused) {
      showMessage(
        _messenger.currentState,
        AppLocalizations.of(context).smsPermissionRefused,
        long: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalListener<SmsCubit, SmsState>(
      bloc: widget.sms,
      listenWhen: (previous, current) =>
          previous.scanVersion != current.scanVersion,
      listener: (context, _) => _cubit.reload(),
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(title: Text(l10n.smsSuggestions)),
          body: Column(
            children: [
              BlocSignalBuilder<SmsCubit, SmsState>(
                bloc: widget.sms,
                builder: (context, sms) =>
                    sms.availability == SmsAvailability.needsPermission
                    ? _PermissionBanner(state: sms, onAllow: _allow)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: BlocSignalBuilder<SmsListCubit, SmsListState>(
                  bloc: _cubit,
                  builder: (context, state) => AsyncBody(
                    phase: switch (state) {
                      SmsListLoading() => LoadPhase.loading,
                      SmsListFailed() => LoadPhase.failed,
                      SmsListLoaded(:final rows) when rows.isEmpty =>
                        LoadPhase.empty,
                      SmsListLoaded() => LoadPhase.loaded,
                    },
                    onRetry: _cubit.load,
                    empty: BlocSignalBuilder<SmsCubit, SmsState>(
                      bloc: widget.sms,
                      builder: (context, sms) => EmptyStateView(
                        icon: Icons.sms_outlined,
                        title: l10n.smsNone,
                        message: switch (sms.lastScanAt) {
                          final at? => smsLastCheckedText(context, at),
                          null => null,
                        },
                      ),
                    ),
                    builder: (context) =>
                        _grid(context, state as SmsListLoaded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, SmsListLoaded state) {
    final settings = context.read<SettingsCubit>().value;
    final names = PeriodNames.of(
      context,
      today: todayOn(widget.dependencies.now()),
      weekLabel: settings.weekLabel,
    );
    if (state.hasMore && !state.loadingMore && !state.loadMoreFailed) {
      loadMoreAfterFrame();
    }
    final footer = state.loadingMore || state.loadMoreFailed;
    return CustomScrollView(
      controller: pagingScroll,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ...framedMonthSlivers<
          SmsMonth,
          ({String day, List<SmsSuggestion> items})
        >(
          context,
          months: state.months,
          monthStart: (month) => month.range.from,
          isOpen: (month) => month.open,
          daysOf: (month) => month.days,
          dayOf: (day) => day.day,
          names: names,
          dayBody: (context, day) => SliverToBoxAdapter(
            child: TwoColumnMasonry(
              spacing: 8,
              children: [
                for (final sms in day.items)
                  SmsCard(
                    sms: sms,
                    method: state.methods[sms.paymentMethodKey],
                    onTap: () => _open(sms),
                    onDismiss: () => _dismiss(sms),
                  ),
              ],
            ),
          ),
          openFooter: footer
              ? LoadMoreFooter(
                  failed: state.loadMoreFailed,
                  onRetry: _cubit.loadMore,
                )
              : null,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// "SMS permission is off" with Allow, or Open settings once Android won't ask
/// any more.
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.state, required this.onAllow});

  final SmsState state;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      key: const ValueKey('smsPermissionBanner'),
      leading: const Icon(Icons.sms_failed_outlined),
      content: Text(l10n.smsPermissionOff),
      actions: [
        TextButton(
          onPressed: onAllow,
          child: Text(state.canAsk ? l10n.smsAllow : l10n.smsOpenSettings),
        ),
      ],
    );
  }
}
