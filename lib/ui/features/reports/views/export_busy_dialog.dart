import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/report_document.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/report_export_cubit.dart';

/// "Making the PDF… page 12 of 40" with Cancel, while [cubit] works. Back is
/// Cancel too; the screen closes it when the export is done. Once the file is
/// being saved or shared, Cancel is off: the copy to Download (or the
/// hand-over) can't be stopped half-way, so a Cancel there would be ignored and
/// the file saved anyway.
class ExportBusyDialog extends StatelessWidget {
  const ExportBusyDialog({super.key, required this.cubit});

  final ReportExportCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<ReportExportCubit, ExportState>(
      bloc: cubit,
      builder: (context, state) {
        final working = state is ExportWorking ? state : null;
        final canCancel = working?.step != ExportStep.saving;
        final pdf = working?.format != ReportExport.xlsx;
        final text = working != null && working.pages > 0
            ? l10n.reportMakingPdfPage(working.page, working.pages)
            : pdf
            ? l10n.reportMakingPdf
            : l10n.reportMakingExcel;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && canCancel) cubit.cancel();
          },
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    value: working != null && working.pages > 0
                        ? working.page / working.pages
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(text, key: const ValueKey('exportBusyText')),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const ValueKey('exportCancel'),
                onPressed: canCancel ? cubit.cancel : null,
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }
}
