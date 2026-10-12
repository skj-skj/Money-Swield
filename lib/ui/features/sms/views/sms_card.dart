import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/money.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/sms_suggestion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';

/// One suggestion on the SMS screen: the amount, the payee as the SMS has it
/// (up to 2 lines), the payment method and the time it came, and a dismiss icon
/// in the top right. Its height follows its content (a large font grows it;
/// only the payee is cut).
class SmsCard extends StatelessWidget {
  const SmsCard({
    super.key,
    required this.sms,
    required this.method,
    required this.onTap,
    required this.onDismiss,
  });

  final SmsSuggestion sms;

  /// The payment method with the suggestion's built-in key, or null when
  /// it was deleted: its built-in name shows.
  final PaymentMethod? method;

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  static const payeeMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final amount = MoneyFormatter.of(context)
        .format(Money(sms.amountMinor, sms.currencyCode));
    final method = this.method;
    final methodName = method == null
        ? paymentMethodBuiltinName(l10n, sms.paymentMethodKey)
        : paymentMethodName(l10n, method);
    final emoji =
        method?.emoji ?? paymentMethodBuiltinEmoji(sms.paymentMethodKey);
    final time = timeText(locale, sms.wallClock);
    final payee = sms.payee;
    return Semantics(
      container: true,
      child: Card(
        key: ValueKey('smsCard ${sms.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          // The parts there are, so a card without a payee
                          // isn't read as "₹110, , Debit card" (found with the
                          // Oppo's UI dump).
                          label: smsCardLabel(
                            amount: amount,
                            payee: payee,
                            method: methodName,
                            time: time,
                          ),
                          button: true,
                          excludeSemantics: true,
                          // One line, shrunk to fit: "₹1,23,456.00" wrapped
                          // its last digit onto a second line at 360 dp
                          // (found on the Oppo).
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              amount,
                              maxLines: 1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('smsDismiss ${sms.id}'),
                      tooltip: l10n.smsDismiss,
                      onPressed: onDismiss,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (payee != null)
                          Text(
                            payee,
                            maxLines: payeeMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '$emoji $methodName · $time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What TalkBack reads for a card: amount, payee (when there is one),
/// payment method and time, comma-separated.
String smsCardLabel({
  required String amount,
  required String? payee,
  required String method,
  required String time,
}) => [amount, ?payee, method, time].join(', ');
