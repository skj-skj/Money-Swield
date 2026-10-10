// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Expense Tracker';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get next => 'Siguiente';

  @override
  String get back => 'Atrás';

  @override
  String get getStarted => 'Empezar';

  @override
  String get continueButton => 'Continuar';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get copyErrorReport => 'Copiar informe de error';

  @override
  String get reportCopied => 'Informe copiado';

  @override
  String get saveFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get loadFailed => 'No se pudo cargar esta lista.';

  @override
  String get migrationChecking => 'Revisando tus datos…';

  @override
  String get migrationBackingUp =>
      'Haciendo una copia de seguridad de tus datos…';

  @override
  String migrationUpdating(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Actualizando tus datos ($currentString de $totalString)';
  }

  @override
  String get migrationVerifying => 'Verificando tus datos…';

  @override
  String get migrationDone => 'Listo';

  @override
  String get migrationKeepOpen => 'Mantén la app abierta, por favor.';

  @override
  String get migrationQuestionTitle => 'Una pregunta rápida';

  @override
  String get migrationFailedTitle => 'No se pudieron actualizar tus datos';

  @override
  String get migrationFailedMessage =>
      'El paso que falló no cambió tus datos. Copia el informe de abajo y envíanoslo para que podamos corregirlo en la próxima actualización.';

  @override
  String migrationFailedStep(String migration) {
    return 'Migración fallida: $migration';
  }

  @override
  String get startupFailedTitle => 'No se pudieron abrir tus datos';

  @override
  String get startupFailedMessage =>
      'No se cambió nada. Copia el informe de abajo y envíanoslo para que podamos corregirlo en la próxima actualización.';

  @override
  String onboardingStep(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Paso $currentString de $totalString';
  }

  @override
  String get onboardingLanguageTitle => 'Elige tu idioma';

  @override
  String get onboardingCurrencyTitle => 'Tu moneda';

  @override
  String get onboardingCurrencySubtitle =>
      'Los nuevos gastos usan esta moneda. Puedes cambiarla cuando quieras en Ajustes.';

  @override
  String get onboardingPaymentMethodTitle => '¿Cómo sueles pagar?';

  @override
  String get onboardingPaymentMethodSubtitle =>
      'Los nuevos gastos usan este método de pago. Puedes cambiarlo cuando quieras en Ajustes.';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String languageSystemDetected(String language) {
    return 'Predeterminado del sistema (detectado: $language)';
  }

  @override
  String get searchCurrencies => 'Buscar por código o nombre';

  @override
  String noCurrencyFound(String query) {
    return 'Ninguna moneda coincide con \"$query\"';
  }

  @override
  String get navHome => 'Inicio';

  @override
  String get navManage => 'Gestionar';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get homeEmptyTitle => 'Aún no hay gastos';

  @override
  String get homeEmptyMessage => 'Toca Añadir gasto para registrar el primero.';

  @override
  String get categoriesTitle => 'Categorías';

  @override
  String get eventsTitle => 'Eventos';

  @override
  String get paymentMethodsTitle => 'Métodos de pago';

  @override
  String get addCategory => 'Añadir categoría';

  @override
  String get addEvent => 'Añadir evento';

  @override
  String get addPaymentMethod => 'Añadir método de pago';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get editPaymentMethod => 'Editar método de pago';

  @override
  String get listEmpty => 'Aún no hay nada. Toca + para añadir.';

  @override
  String archivedSection(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Archivados ($countString)';
  }

  @override
  String get defaultBadge => 'Predeterminado';

  @override
  String get fieldEmoji => 'Emoji';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldDescription => 'Descripción (opcional)';

  @override
  String get errorNameRequired => 'Escribe un nombre';

  @override
  String errorTooLong(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Usa como máximo $maxString caracteres';
  }

  @override
  String errorNameDuplicate(String name) {
    return '\"$name\" ya existe';
  }

  @override
  String get errorEmojiRequired => 'Elige un emoji';

  @override
  String get errorEmojiNotSingle => 'Usa exactamente un emoji';

  @override
  String get resetToDefaultName => 'Restablecer el nombre predeterminado';

  @override
  String deleteConfirmTitle(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get deleteConfirmMessage => 'Esto no se puede deshacer.';

  @override
  String get archive => 'Archivar';

  @override
  String get unarchive => 'Desarchivar';

  @override
  String get setAsDefault => 'Establecer como predeterminado';

  @override
  String get cannotDeleteDefaultHint =>
      'Primero establece otro método como predeterminado';

  @override
  String get pickEmojiTitle => 'Elige un emoji';

  @override
  String get typeAnyEmoji => 'Escribe cualquier emoji';

  @override
  String get useEmoji => 'Usar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingLanguage => 'Idioma';

  @override
  String get settingTheme => 'Tema';

  @override
  String get settingDefaultCurrency => 'Moneda predeterminada';

  @override
  String get settingDefaultPaymentMethod => 'Método de pago predeterminado';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get ok => 'Aceptar';

  @override
  String get addExpense => 'Añadir gasto';

  @override
  String get editExpense => 'Editar gasto';

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldAmount => 'Importe';

  @override
  String get fieldCategory => 'Categoría';

  @override
  String get fieldEvents => 'Eventos';

  @override
  String get fieldPaymentMethod => 'Método de pago';

  @override
  String get fieldCurrency => 'Moneda';

  @override
  String get fieldDate => 'Fecha';

  @override
  String get fieldTime => 'Hora';

  @override
  String get fieldNotes => 'Descripción';

  @override
  String get fieldDeletedAt => 'Eliminado el';

  @override
  String get amountErrorEmpty => 'Introduce un importe';

  @override
  String get amountErrorInvalid => 'Introduce un importe como 110,50 o 50 + 60';

  @override
  String amountErrorTooLarge(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Usa como máximo $maxString cifras antes de los decimales';
  }

  @override
  String amountErrorTooManyDecimals(int digits, String currency) {
    final intl.NumberFormat digitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String digitsString = digitsNumberFormat.format(digits);

    String _temp0 = intl.Intl.pluralLogic(
      digits,
      locale: localeName,
      other: '$currency solo tiene $digitsString decimales',
      one: '$currency solo tiene 1 decimal',
      zero: '$currency no tiene decimales',
    );
    return '$_temp0';
  }

  @override
  String get amountErrorNotPositive => 'Introduce un importe mayor que cero';

  @override
  String amountPreview(String amount) {
    return '= $amount';
  }

  @override
  String get titleRequired => 'Introduce un título';

  @override
  String get categoryRequired => 'Elige una categoría';

  @override
  String get expenseGone => 'Este gasto ya no existe';

  @override
  String get clear => 'Borrar';

  @override
  String get update => 'Actualizar';

  @override
  String get done => 'Listo';

  @override
  String get cleared => 'Formulario borrado';

  @override
  String get draftDiscarded => 'Borrador descartado';

  @override
  String get discardDraft => 'Descartar borrador';

  @override
  String draftRestoredAdd(String age) {
    return 'Gasto sin guardar recuperado ($age)';
  }

  @override
  String draftRestoredEdit(String age) {
    return 'Cambios sin guardar recuperados ($age)';
  }

  @override
  String get draftSaved => 'Borrador guardado';

  @override
  String get draftKeptExpenseGone =>
      'El gasto se eliminó; tus cambios se guardaron. Toca + para añadirlos como un gasto nuevo';

  @override
  String get unsavedChanges => 'Cambios sin guardar';

  @override
  String get itemize => 'Desglosar';

  @override
  String get itemizeTitle => 'Describe los artículos';

  @override
  String get amountErrorDivideByZero => 'No se puede dividir entre cero';

  @override
  String amountApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get keyPlus => 'más';

  @override
  String get keyMinus => 'menos';

  @override
  String get keyTimes => 'por';

  @override
  String get keyDivide => 'entre';

  @override
  String get keyDecimal => 'separador decimal';

  @override
  String get amountChipsLabel => 'Importes habituales';

  @override
  String get titleSuggestionsLabel => 'Títulos anteriores';

  @override
  String get search => 'Buscar';

  @override
  String get closeSearch => 'Cerrar búsqueda';

  @override
  String get searchCategories => 'Buscar categorías…';

  @override
  String get searchEvents => 'Buscar eventos…';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get newEvent => 'Nuevo evento';

  @override
  String get moreResults => 'Más resultados';

  @override
  String get allCategories => 'Todas las categorías';

  @override
  String get allEvents => 'Todos los eventos';

  @override
  String get noMoreMatches => 'No hay más coincidencias';

  @override
  String get noCategoriesYet => 'Aún no hay categorías';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get movedToBin => 'Movido a la papelera';

  @override
  String get undo => 'Deshacer';

  @override
  String get loadMoreFailed => 'No se pudieron cargar más gastos.';

  @override
  String get bin => 'Papelera';

  @override
  String get binSubtitle => 'Los gastos eliminados se guardan 30 días';

  @override
  String get binEmpty => 'Los gastos eliminados se quedan aquí 30 días.';

  @override
  String get deletedToday => 'Eliminado hoy';

  @override
  String get deletedYesterday => 'Eliminado ayer';

  @override
  String deletedDaysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'hace $daysString días',
      one: 'hace 1 día',
    );
    return 'Eliminado $_temp0';
  }

  @override
  String removedInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'se borra en $daysString días',
      one: 'se borra en 1 día',
    );
    return '$_temp0';
  }

  @override
  String get removedOnNextStart => 'se borra al volver a abrir la app';

  @override
  String get restore => 'Restaurar';

  @override
  String get restoreAll => 'Restaurar todo';

  @override
  String get deletePermanently => 'Eliminar para siempre';

  @override
  String deletePermanentlyTitle(String title) {
    return '¿Eliminar \"$title\" para siempre?';
  }

  @override
  String get emptyBin => 'Vaciar papelera';

  @override
  String get emptyBinTitle => '¿Vaciar la papelera?';

  @override
  String get cannotBeUndone => 'Esto no se puede deshacer.';

  @override
  String usedByExpenses(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos',
      one: '1 gasto',
    );
    return '\"$name\" se usa en $_temp0.';
  }

  @override
  String usedByExpensesWithBin(String name, int count, int binned) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat binnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String binnedString = binnedNumberFormat.format(binned);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos',
      one: '1 gasto',
    );
    return '\"$name\" se usa en $_temp0 ($binnedString en la papelera).';
  }

  @override
  String get moveExpensesTo => 'Muévelos a:';

  @override
  String get moveAndDelete => 'Mover y eliminar';

  @override
  String get addAnotherFirst =>
      'Añade otro primero, para que sus gastos tengan adónde ir.';

  @override
  String eventDeleteWithCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos',
      one: '1 gasto',
    );
    return 'Se quitará de $_temp0. Los gastos se mantienen.';
  }

  @override
  String get recentCurrencies => 'Recientes';

  @override
  String get allCurrencies => 'Todas las monedas';

  @override
  String get noneEvent => 'Ninguno';

  @override
  String get settingTileShape => 'Forma de los mosaicos';

  @override
  String get settingButtonShape => 'Forma de los botones';

  @override
  String get shapeSquare => 'Cuadrado';

  @override
  String get shapeRounded => 'Cuadrado redondeado';

  @override
  String get shapeCircle => 'Círculo';

  @override
  String get settingCustomizeTiles => 'Personalizar mosaicos';

  @override
  String get settingCustomizeTilesSubtitle =>
      'Formas de los selectores de categoría y evento';

  @override
  String get preview => 'Vista previa';

  @override
  String get settingThemeColor => 'Color del tema';

  @override
  String get themeColorWallpaper => 'Colores del fondo de pantalla';

  @override
  String get colorPurple => 'Morado';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorTeal => 'Verde azulado';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorAmber => 'Ámbar';

  @override
  String get colorOrange => 'Naranja';

  @override
  String get colorRed => 'Rojo';

  @override
  String get colorPink => 'Rosa';

  @override
  String get restoreDefaultLook => 'Restaurar el aspecto predeterminado';

  @override
  String get restoreDefaultLookSubtitle =>
      'Color del tema y formas de los mosaicos';

  @override
  String get restoreDefaultLookTitle => '¿Restaurar el aspecto predeterminado?';

  @override
  String get restoreDefaultLookMessage =>
      'El color del tema vuelve a los colores del fondo de pantalla, los mosaicos a cuadrados redondeados y los botones a círculos.';

  @override
  String get migrationInstalledTitle => 'Base de datos creada';

  @override
  String get migrationInstalledMessage => 'Todo está listo.';

  @override
  String get migrationUpdatedTitle => 'Actualización completada';

  @override
  String get migrationUpdatedMessage => 'Tus datos están al día.';

  @override
  String get backupAndRestore => 'Copia de seguridad';

  @override
  String get lastBackupNever => 'Nunca se hizo una copia';

  @override
  String get lastBackupToday => 'hoy';

  @override
  String get lastBackupYesterday => 'ayer';

  @override
  String lastBackupDaysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'hace $daysString días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String lastBackupSubtitle(String when) {
    return 'Última copia: $when';
  }

  @override
  String get backUpNow => 'Hacer copia ahora';

  @override
  String get preparingBackup => 'Preparando la copia…';

  @override
  String get backupSaved => 'Copia guardada';

  @override
  String get backupFailedTitle => 'No se pudo hacer la copia';

  @override
  String get backupFailedMessage =>
      'No se guardó nada y tus datos en este teléfono no cambiaron. Copia el informe de abajo y envíanoslo para que podamos corregirlo.';

  @override
  String get restoreFromBackup => 'Restaurar una copia';

  @override
  String get restoreFromBackupSubtitle =>
      'Reemplaza todos los datos de este teléfono por los de un archivo de copia.';

  @override
  String get undoLastRestore => 'Deshacer la última restauración';

  @override
  String undoLastRestoreSubtitle(String date) {
    return 'Vuelve a tus datos de antes de la restauración del $date.';
  }

  @override
  String get restoreConfirmTitle => '¿Restaurar esta copia?';

  @override
  String get undoConfirmTitle => '¿Deshacer la última restauración?';

  @override
  String restoreBackupFrom(String date) {
    return 'Copia del $date';
  }

  @override
  String restoreCopyFrom(String date) {
    return 'Tus datos de antes de la restauración del $date';
  }

  @override
  String restoreExpenseCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos',
      one: '1 gasto',
      zero: 'Ningún gasto',
    );
    return '$_temp0';
  }

  @override
  String restoreBinCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $countString en la papelera',
      one: 'y 1 en la papelera',
    );
    return '$_temp0';
  }

  @override
  String restoreLatestOn(String date) {
    return 'El último el $date';
  }

  @override
  String restoreReplacesData(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos',
      one: '1 gasto',
      zero: 'ningún gasto',
    );
    return 'Se reemplazan todos los datos de este teléfono ($_temp0).';
  }

  @override
  String get restoreKeepsCopy =>
      'Se guarda una copia y puedes deshacer la restauración.';

  @override
  String get restoreBackupButton => 'Restaurar';

  @override
  String get checkingBackup => 'Comprobando la copia…';

  @override
  String get restoringData => 'Restaurando tus datos…';

  @override
  String get backupRestored => 'Copia restaurada';

  @override
  String get backupRestoredDefaultSettings =>
      'Copia restaurada. Sus ajustes faltaban o no se podían leer, así que se usan los ajustes predeterminados. Puedes cambiarlos en Ajustes.';

  @override
  String get restoreFailedTitle => 'No se pudo restaurar';

  @override
  String get restoreFailedMessage =>
      'Tus datos en este teléfono no cambiaron. Copia el informe de abajo y envíanoslo para que podamos corregirlo.';

  @override
  String get restoreFailedRestartMessage =>
      'Tus datos en este teléfono no cambiaron. La app se reinicia para volver a abrirlos. Copia el informe de abajo y envíanoslo para que podamos corregirlo.';

  @override
  String get restartApp => 'Reiniciar la app';

  @override
  String get restoreRejectedTitle => 'No se puede restaurar este archivo';

  @override
  String get notABackup => 'Este archivo no es una copia de Expense Tracker.';

  @override
  String get backupTooNew =>
      'Esta copia se hizo con una versión más nueva de la app. Actualiza la app e inténtalo de nuevo.';

  @override
  String get backupDamaged => 'Esta copia está dañada y no se puede restaurar.';

  @override
  String get periodDay => 'Día';

  @override
  String get periodWeek => 'Semana';

  @override
  String get periodMonth => 'Mes';

  @override
  String get periodYear => 'Año';

  @override
  String weekNumber(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Semana $numberString';
  }

  @override
  String weekNumberWithYear(int number, String year) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Semana $numberString de $year';
  }

  @override
  String weekOfMonth(String month, int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Semana $numberString de $month';
  }

  @override
  String dayWithSubtotal(String date, String amount) {
    return '$date – $amount';
  }

  @override
  String daySubtotalSemantics(String date, String amount) {
    return '$date, $amount';
  }

  @override
  String get trendEmptyWeek => 'No hay gastos esta semana';

  @override
  String get trendEmptyMonth => 'No hay gastos este mes';

  @override
  String get trendEmptyYear => 'No hay gastos este año';

  @override
  String get trendNoMatchWeek => 'Ningún gasto coincide esta semana';

  @override
  String get trendNoMatchMonth => 'Ningún gasto coincide este mes';

  @override
  String get trendNoMatchYear => 'Ningún gasto coincide este año';

  @override
  String get trendFiltered => 'Filtrado';

  @override
  String trendPointLabel(String date, String amount) {
    return '$date · $amount';
  }

  @override
  String trendCardSemantics(String period, String amount) {
    return '$period, total $amount';
  }

  @override
  String trendCardSemanticsFiltered(String period, String amount) {
    return '$period, filtrado, total $amount';
  }

  @override
  String get totalsLoadFailed => 'No se pudieron cargar los totales';

  @override
  String get nextPeriod => 'Periodo siguiente';

  @override
  String get previousPeriod => 'Periodo anterior';

  @override
  String get nextCurrency => 'Moneda siguiente';

  @override
  String get previousCurrency => 'Moneda anterior';

  @override
  String chartCurrencyAnnounce(String currency, String amount) {
    return '$currency, $amount';
  }

  @override
  String totalsJoin(String first, String rest) {
    return '$first + $rest';
  }

  @override
  String totalsJoinSpoken(String first, String rest) {
    return '$first y $rest';
  }

  @override
  String get totalTooLarge => 'Demasiado grande';

  @override
  String get showSubtotal => 'Ver subtotal';

  @override
  String get subtotalLoadFailed => 'No se pudo cargar el subtotal';

  @override
  String groupSubtotalSemantics(String name, String amount) {
    return '$name, subtotal $amount';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get filters => 'Filtros';

  @override
  String get filterSearchHint => 'Buscar en títulos y descripciones';

  @override
  String get filterCategories => 'Categorías';

  @override
  String get filterEvents => 'Eventos';

  @override
  String get filterArchived => 'Archivados';

  @override
  String get groupBy => 'Agrupar por';

  @override
  String get groupedByDay => 'Por día';

  @override
  String get groupedByWeek => 'Por semana';

  @override
  String get groupedByMonth => 'Por mes';

  @override
  String get groupedByYear => 'Por año';

  @override
  String get clearFilters => 'Quitar filtros';

  @override
  String get showResults => 'Ver resultados';

  @override
  String get noFilterMatches => 'Ningún gasto coincide con estos filtros';

  @override
  String filterMore(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$name +$countString';
  }

  @override
  String filterSearchChip(String text) {
    return '«$text»';
  }

  @override
  String get removeFilter => 'Quitar filtro';

  @override
  String get settingsLook => 'Aspecto';

  @override
  String get settingsHome => 'Inicio';

  @override
  String get settingsDefaults => 'Predeterminados';

  @override
  String get settingWeekStart => 'La semana empieza el';

  @override
  String get settingWeekNames => 'Nombres de las semanas';

  @override
  String get settingTrendChart => 'Gráfico de tendencia';

  @override
  String get chartLineFilled => 'Línea suave, rellena';

  @override
  String get chartLine => 'Línea suave';

  @override
  String get chartBars => 'Barras';

  @override
  String get chartDots => 'Puntos';

  @override
  String get chartRunningTotal => 'Total acumulado';

  @override
  String get settingTrendCardSize => 'Tamaño de la tarjeta';

  @override
  String get cardSizeSmall => 'Pequeña';

  @override
  String get cardSizeMedium => 'Mediana';

  @override
  String get cardSizeLarge => 'Grande';

  @override
  String get settingCardHaptics => 'Vibración de la tarjeta';

  @override
  String get hapticsOff => 'Desactivada';

  @override
  String get hapticsLight => 'Suave';

  @override
  String get hapticsMedium => 'Media';

  @override
  String get hapticsStrong => 'Fuerte';

  @override
  String trendRunningTotalPoint(String date, String amount) {
    return 'Hasta $date · $amount';
  }

  @override
  String get restoreHomeDefaults => 'Restaurar valores predeterminados';

  @override
  String get restoreHomeDefaultsSubtitle =>
      'Gráfico, tarjeta y semanas como al principio';

  @override
  String get restoreHomeDefaultsTitle => '¿Restaurar los valores de Inicio?';

  @override
  String get restoreHomeDefaultsMessage =>
      'El gráfico, la tarjeta, su tamaño, el inicio de semana y los nombres de las semanas vuelven a sus valores predeterminados.';

  @override
  String get settingTrendCard => 'Tarjeta de tendencia';

  @override
  String get trendCardLocked => 'Fija arriba';

  @override
  String get trendCardScrolls => 'Se desplaza con la lista';

  @override
  String get trendCardLockedShort => 'Fija';

  @override
  String get trendCardScrollsShort => 'Se desplaza';

  @override
  String get binTileSummary => 'Se guardan 30 días';

  @override
  String settingsTileSummary(String first, String rest) {
    return '$first · $rest';
  }

  @override
  String get addPhotos => 'Añadir fotos';

  @override
  String photosCountOpen(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos, abrir',
      one: '1 foto, abrir',
    );
    return '$_temp0';
  }

  @override
  String get takePhoto => 'Hacer foto';

  @override
  String get chooseFromGallery => 'Elegir de la galería';

  @override
  String photosAddedOf(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$countString de $maxString añadidas';
  }

  @override
  String get photos => 'Fotos';

  @override
  String photosOfMax(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$countString de $maxString';
  }

  @override
  String photosMaxReached(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString fotos es el máximo por gasto';
  }

  @override
  String get photoAlreadyAdded => 'Esa foto ya está aquí';

  @override
  String photoCouldNotBeAdded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron añadir $countString fotos',
      one: 'No se pudo añadir una foto',
    );
    return '$_temp0';
  }

  @override
  String photosOverflow(int max, int added) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);

    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'se añadieron $addedString',
      one: 'se añadió 1',
      zero: 'no se añadió ninguna',
    );
    return 'Solo $maxString fotos por gasto: $_temp0.';
  }

  @override
  String get noCameraApp => 'No se encontró ninguna app de cámara';

  @override
  String get addingPhotos => 'Añadiendo fotos…';

  @override
  String addingPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Añadiendo fotos ($doneString de $totalString)';
  }

  @override
  String draftPhotosMissing(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se encontraron $countString fotos del borrador',
      one: 'No se encontró 1 foto del borrador',
    );
    return '$_temp0';
  }

  @override
  String photosMax(int max, int extra) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);
    final intl.NumberFormat extraNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String extraString = extraNumberFormat.format(extra);

    String _temp0 = intl.Intl.pluralLogic(
      extra,
      locale: localeName,
      other: '$extraString fotos',
      one: '1 foto',
    );
    return 'Como máximo $maxString fotos. Quita $_temp0 para guardar.';
  }

  @override
  String photosNotKept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'No se pudieron conservar $countString fotos: se eliminaron mientras tanto',
      one: 'No se pudo conservar 1 foto: se eliminó mientras tanto',
    );
    return '$_temp0';
  }

  @override
  String get imageMissing => 'Falta la imagen';

  @override
  String get photosSaveFailed =>
      'No se pudieron guardar las fotos. No se guardó nada.';

  @override
  String photosCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String photoNumber(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Foto $indexString de $totalString';
  }

  @override
  String photoCounter(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString / $totalString';
  }

  @override
  String selectedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString seleccionadas';
  }

  @override
  String photosSelectedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos seleccionadas',
      one: '1 foto seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get endSelection => 'Terminar selección';

  @override
  String get selected => 'Seleccionada';

  @override
  String get notSelected => 'No seleccionada';

  @override
  String photosDeleteTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $countString fotos?',
      one: '¿Eliminar esta foto?',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningScreen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminarán para siempre de sus gastos. Las copias que guardaste en Imágenes se quedan.',
      one: 'Se eliminará para siempre de su gasto. Las copias que guardaste en Imágenes se quedan.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningForm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminarán para siempre de este gasto cuando toques Actualizar. Las copias que guardaste en Imágenes se quedan.',
      one: 'Se eliminará para siempre de este gasto cuando toques Actualizar. Las copias que guardaste en Imágenes se quedan.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminarán para siempre de este gasto cuando lo guardes. Las copias que guardaste en Imágenes se quedan.',
      one: 'Se eliminará para siempre de este gasto cuando lo guardes. Las copias que guardaste en Imágenes se quedan.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos eliminadas',
      one: '1 foto eliminada',
    );
    return '$_temp0';
  }

  @override
  String get saveToPictures => 'Guardar en Imágenes';

  @override
  String savedToPictures(String folder) {
    return 'Guardada en $folder';
  }

  @override
  String photosSavedToPictures(int count, String folder) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos guardadas en $folder',
      one: '1 foto guardada en $folder',
    );
    return '$_temp0';
  }

  @override
  String photosSavedSomeFailed(int saved, int failed) {
    final intl.NumberFormat savedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String savedString = savedNumberFormat.format(saved);
    final intl.NumberFormat failedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String failedString = failedNumberFormat.format(failed);

    String _temp0 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failedString no se pudieron guardar',
      one: '1 no se pudo guardar',
    );
    return '$savedString guardadas; $_temp0';
  }

  @override
  String photosMissingNotSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $countString fotos y no se guardaron',
      one: 'Falta 1 foto y no se guardó',
    );
    return '$_temp0';
  }

  @override
  String get noSpaceToSavePhotos =>
      'No hay espacio suficiente para guardar estas fotos';

  @override
  String savingToPictures(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Guardando $doneString / $totalString';
  }

  @override
  String get defaultPictureTitle => 'Gasto';

  @override
  String get reviewPhoto => 'Tu foto';

  @override
  String get rotateLeft => 'Girar a la izquierda';

  @override
  String get rotateRight => 'Girar a la derecha';

  @override
  String rotatedDegrees(int degrees) {
    final intl.NumberFormat degreesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String degreesString = degreesNumberFormat.format(degrees);

    return 'Girada $degreesString grados';
  }

  @override
  String get usePhoto => 'Usar foto';

  @override
  String get discardPhoto => 'Descartar';

  @override
  String get photoFromCameraBack => 'La foto que hiciste ha vuelto';

  @override
  String get noPhotosMatchTooltip => 'Ninguna foto coincide con los filtros';

  @override
  String photoOfExpense(String title, String date) {
    return 'Foto de $title, $date';
  }

  @override
  String get noPhotosMatchFilters =>
      'Ninguna foto coincide con los filtros de Inicio.';

  @override
  String get cameraPhotos => 'Fotos de la cámara';

  @override
  String get galleryPhotos => 'Fotos de la galería';

  @override
  String get photoSizeLabel => 'Tamaño';

  @override
  String get photoQualityLabel => 'Calidad';

  @override
  String get photoSizeOriginal => 'Original';

  @override
  String photoSizeNotRecommended(String size) {
    return '$size (no recomendado)';
  }

  @override
  String settingDefaultValue(String value) {
    return '$value (predeterminado)';
  }

  @override
  String get photoResizedAbove =>
      'Las fotos más grandes se reducen a este tamaño; las más pequeñas se guardan tal cual';

  @override
  String get originalWarning =>
      'No se recomienda guardar los originales: una foto del móvil ocupa 5–10 MB, así que con unas 1.000 fotos ocupan varios GB en el móvil y en las copias con fotos. Los originales también guardan la ubicación de la foto.';

  @override
  String photosUse(String size, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos',
      one: '1 foto',
    );
    return 'Las fotos ocupan $size ($_temp0).';
  }

  @override
  String get noPhotosYet => 'Aún no hay fotos.';

  @override
  String get photosKeptInApp =>
      'Las fotos se guardan dentro de la app y se van con ella. Para quedarte una, ábrela y usa Guardar en Imágenes.';

  @override
  String get photoChangesApplyToNew =>
      'Los cambios se aplican a las fotos que añadas a partir de ahora.';

  @override
  String photosTileCamera(String size) {
    return 'Cámara $size';
  }

  @override
  String photosTileGallery(String size) {
    return 'Galería $size';
  }

  @override
  String get restorePhotoDefaults => 'Restaurar valores predeterminados';

  @override
  String get restorePhotoDefaultsTitle =>
      '¿Restaurar los valores de las fotos?';

  @override
  String get restorePhotoDefaultsMessage =>
      'Las fotos de la cámara y de la galería vuelven a 1080p y calidad 85.';

  @override
  String get includePhotos => 'Incluir fotos';

  @override
  String get photosNotInBackup =>
      'Las fotos no estarán en esta copia. Si la restauras en otro móvil o tras reinstalar, aparecerán como que faltan.';

  @override
  String backupPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Añadiendo fotos a la copia ($doneString de $totalString)';
  }

  @override
  String get savingBackup => 'Guardando la copia…';

  @override
  String get backupNoSpace =>
      'No hay espacio suficiente en el móvil para hacer esta copia';

  @override
  String backupSavedMissingPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltaban $countString fotos y no están en ella',
      one: 'Faltaba 1 foto y no está en ella',
    );
    return 'Copia guardada. $_temp0.';
  }

  @override
  String get saveTargetNoSpace =>
      'No hay espacio suficiente donde elegiste guardarla';

  @override
  String restoreIncludesPhotos(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos',
      one: '1 foto',
    );
    return 'Incluye $_temp0 ($size).';
  }

  @override
  String restoreNoSpaceForPhotos(String size) {
    return 'No hay espacio suficiente para sus fotos (faltan $size).';
  }

  @override
  String get restoreWithoutPhotos => 'Restaurar sin fotos';

  @override
  String get restoreBackupWithoutPhotos =>
      'Esta copia no tiene fotos. Las fotos que este móvil no tenga aparecerán como que faltan.';

  @override
  String restoringPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Restaurando fotos ($doneString de $totalString)';
  }

  @override
  String backupRestoredFailedPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'No se pudieron restaurar $countString fotos y aparecen como que faltan',
      one: 'No se pudo restaurar 1 foto y aparece como que falta',
    );
    return 'Copia restaurada. $_temp0.';
  }

  @override
  String get openBackupNoSpace =>
      'No hay espacio suficiente en el móvil para abrir esta copia';

  @override
  String sizeBytes(String size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size GB';
  }

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryDrinks => 'Bebidas';

  @override
  String get categoryGroceries => 'Supermercado';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categoryClothes => 'Ropa';

  @override
  String get categoryTransport => 'Transporte';

  @override
  String get categoryFuel => 'Combustible';

  @override
  String get categoryRent => 'Alquiler';

  @override
  String get categoryHouse => 'Casa';

  @override
  String get categoryBills => 'Facturas';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryEntertainment => 'Entretenimiento';

  @override
  String get categoryTravel => 'Viajes';

  @override
  String get categoryGifts => 'Regalos';

  @override
  String get categoryPersonalCare => 'Cuidado personal';

  @override
  String get categorySubscription => 'Suscripciones';

  @override
  String get categoryLoan => 'Préstamo';

  @override
  String get categoryInvestment => 'Inversión';

  @override
  String get categoryOther => 'Otros';

  @override
  String get paymentMethodCash => 'Efectivo';

  @override
  String get paymentMethodUpi => 'UPI';

  @override
  String get paymentMethodDebitCard => 'Tarjeta de débito';

  @override
  String get paymentMethodCreditCard => 'Tarjeta de crédito';

  @override
  String get eventBirthday => 'Cumpleaños';

  @override
  String get eventAnniversary => 'Aniversario';

  @override
  String get eventParty => 'Fiesta';

  @override
  String get eventFestival => 'Festival';

  @override
  String get eventTrip => 'Viaje';

  @override
  String get eventWedding => 'Boda';

  @override
  String get eventDiningOut => 'Comer fuera';

  @override
  String scheduleDaily(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString días',
      one: 'Cada día',
    );
    return '$_temp0';
  }

  @override
  String scheduleWeekly(int count, String weekday) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString semanas, el $weekday',
      one: 'Cada semana, el $weekday',
    );
    return '$_temp0';
  }

  @override
  String scheduleMonthly(int count, int day) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString meses, el día $dayString',
      one: 'Cada mes, el día $dayString',
    );
    return '$_temp0';
  }

  @override
  String scheduleMonthlyClamped(int count, int day) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cada $countString meses, el día $dayString (o el último día del mes)',
      one: 'Cada mes, el día $dayString (o el último día del mes)',
    );
    return '$_temp0';
  }

  @override
  String scheduleYearly(int count, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString años, el $date',
      one: 'Cada año, el $date',
    );
    return '$_temp0';
  }

  @override
  String scheduleYearlyLeap(int count, String date, String fallback) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cada $countString años, el $date (el $fallback en los demás años)',
      one: 'Cada año, el $date (el $fallback en los demás años)',
    );
    return '$_temp0';
  }

  @override
  String repeatShortDaily(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString días',
      one: 'Diario',
    );
    return '$_temp0';
  }

  @override
  String repeatShortWeekly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString semanas',
      one: 'Semanal',
    );
    return '$_temp0';
  }

  @override
  String repeatShortMonthly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString meses',
      one: 'Mensual',
    );
    return '$_temp0';
  }

  @override
  String repeatShortYearly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $countString años',
      one: 'Anual',
    );
    return '$_temp0';
  }

  @override
  String get endsNever => 'Sin fecha de fin';

  @override
  String endsOn(String date) {
    return 'Termina el $date';
  }

  @override
  String nextOn(String date) {
    return 'Próximo: $date';
  }

  @override
  String get noMorePayments => 'No hay más pagos';

  @override
  String archivedStopped(String date) {
    return 'detenido el $date';
  }

  @override
  String archivedExpired(String date) {
    return 'terminó el $date';
  }

  @override
  String get repeats => 'Se repite';

  @override
  String get repeatEvery => 'Cada';

  @override
  String repeatUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'semanas',
      one: 'semana',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'meses',
      one: 'mes',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'años',
      one: 'año',
    );
    return '$_temp0';
  }

  @override
  String get repeatEnds => 'Termina';

  @override
  String get repeatEndsNever => 'Nunca';

  @override
  String get repeatEndsOn => 'El';

  @override
  String get repeatEndDate => 'Fecha de fin';

  @override
  String repeatIntervalError(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'De 1 a $maxString';
  }

  @override
  String get repeatEndMissing => 'Elige una fecha de fin';

  @override
  String repeatEndBeforeStart(String date) {
    return 'Termina antes del primer pago ($date)';
  }

  @override
  String repeatEndTooLate(String date) {
    return 'Elige una fecha hasta el $date';
  }

  @override
  String repeatTooManyPast(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Son $countString pagos anteriores; como máximo $maxString. Elige una fecha posterior o un intervalo más largo.';
  }

  @override
  String repeatAlsoAdds(int count, String dates) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'También añade $countString pagos anteriores: $dates',
      one: 'También añade 1 pago anterior: $dates',
    );
    return '$_temp0';
  }

  @override
  String repeatAndMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $countString más',
      one: 'y 1 más',
    );
    return '$_temp0';
  }

  @override
  String get repeatThisPaymentOnly =>
      'Los cambios aquí son solo para este pago.';

  @override
  String repeatLinkSemantics(String title, String schedule) {
    return 'Gasto recurrente $title, $schedule. Abre su página.';
  }

  @override
  String get repeatsMark => 'Se repite';

  @override
  String savedRepeats(String schedule) {
    return 'Guardado. Se repite: $schedule';
  }

  @override
  String savedWithEarlier(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guardado con $countString pagos anteriores.',
      one: 'Guardado con 1 pago anterior.',
    );
    return '$_temp0';
  }

  @override
  String addedRecurring(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $countString gastos recurrentes',
      one: 'Se añadió 1 gasto recurrente',
    );
    return '$_temp0';
  }

  @override
  String heldOne(String title, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pagos pendientes',
      one: '1 pago pendiente',
    );
    return '$title tiene $_temp0';
  }

  @override
  String heldMany(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos recurrentes tienen pagos pendientes',
    );
    return '$_temp0';
  }

  @override
  String get review => 'Revisar';

  @override
  String usedByTemplatesOnly(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos recurrentes',
      one: '1 gasto recurrente',
    );
    return '\"$name\" se usa en $_temp0.';
  }

  @override
  String alsoUsedByTemplates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'También se usa en $countString gastos recurrentes: sus próximos pagos usarán el que elijas.',
      one: 'También se usa en 1 gasto recurrente: sus próximos pagos usarán el que elijas.',
    );
    return '$_temp0';
  }

  @override
  String templatesMoveToo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sus próximos pagos usarán el que elijas.',
      one: 'Sus próximos pagos usarán el que elijas.',
    );
    return '$_temp0';
  }

  @override
  String eventDeleteTemplates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se quitará de $countString gastos recurrentes: sus próximos pagos llegarán sin él.',
      one: 'Se quitará de 1 gasto recurrente: sus próximos pagos llegarán sin él.',
    );
    return '$_temp0';
  }

  @override
  String get recurringTitle => 'Recurrentes';

  @override
  String recurringRunning(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString activos',
      one: '1 activo',
      zero: 'Ninguno activo',
    );
    return '$_temp0';
  }

  @override
  String get recurringEmpty =>
      'Todavía no se repite nada. Activa «Se repite» al añadir un gasto.';

  @override
  String get recurringWaiting => 'Pendientes';

  @override
  String get recurringActive => 'Activos';

  @override
  String recurringPaymentsWaiting(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pagos pendientes',
      one: '1 pago pendiente',
    );
    return '$_temp0';
  }

  @override
  String recurringRowNext(String schedule, String date) {
    return '$schedule · próximo $date';
  }

  @override
  String recurringRowEnds(String date) {
    return 'No hay más pagos · termina el $date';
  }

  @override
  String get recurringBroken =>
      'Este gasto recurrente no se puede leer, así que no añade pagos.';

  @override
  String get recurringPrice => 'Precio';

  @override
  String get recurringScheduled => 'programado';

  @override
  String priceFromDate(String date) {
    return 'desde el $date';
  }

  @override
  String get removeScheduledPrice => 'Quitar precio programado';

  @override
  String recurringPayments(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pagos ($countString)';
  }

  @override
  String get recurringNoPayments =>
      'Sin pagos (los eliminados no se muestran).';

  @override
  String get showAll => 'Ver todos';

  @override
  String get changePrice => 'Cambiar precio';

  @override
  String get newPrice => 'Nuevo precio';

  @override
  String get priceFrom => 'Desde';

  @override
  String get priceKeepsPast => 'Los pagos ya añadidos conservan su precio.';

  @override
  String priceReplaces(String amount, String date) {
    return 'Sustituye $amount desde el $date';
  }

  @override
  String get priceInForce => 'Ya rige un precio desde esa fecha';

  @override
  String priceBeforeStart(String date) {
    return 'Elige el $date o después';
  }

  @override
  String get priceChanged => 'Precio cambiado';

  @override
  String get stop => 'Detener';

  @override
  String recurringStopped(String title) {
    return '$title se detuvo y se archivó.';
  }

  @override
  String get undoStopRefused =>
      'No se pudo deshacer: desde entonces se restauró, se eliminó o se cambió por otro.';

  @override
  String get archiveTitle => 'Archivo';

  @override
  String get archivedBadge => 'Archivado';

  @override
  String restoreRecurringTitle(String title) {
    return '¿Restaurar $title?';
  }

  @override
  String restoreRecurringText(String date) {
    return 'Volverá a añadir pagos desde el $date.';
  }

  @override
  String get restoreRecurringNoMore => 'No le quedan pagos antes de su fin.';

  @override
  String restoreEndPassed(String date) {
    return 'Su fin, el $date, ya pasó: se restaura sin fin. Edítalo para poner uno.';
  }

  @override
  String recurringRestored(String title, String date) {
    return '$title restaurado. Próximo: $date';
  }

  @override
  String recurringRestoredNoNext(String title) {
    return '$title restaurado.';
  }

  @override
  String get deleteForGood => 'Eliminar para siempre';

  @override
  String deleteForGoodTitle(String title) {
    return '¿Eliminar $title para siempre?';
  }

  @override
  String deleteForGoodText(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sus $countString pagos se quedan, sin la marca de repetición. No se puede deshacer.',
      one:
          'Su pago se queda, sin la marca de repetición. No se puede deshacer.',
      zero: 'No tiene pagos. No se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String recurringDeleted(String title, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$title eliminado. Sus $countString pagos se quedan.',
      one: '$title eliminado. Su pago se queda.',
      zero: '$title eliminado.',
    );
    return '$_temp0';
  }

  @override
  String get recurringGone => 'Este gasto recurrente ya no existe.';

  @override
  String get editRecurring => 'Editar gasto recurrente';

  @override
  String get recurringChangesApplyLater =>
      'Los cambios se aplican a los pagos que se añadan a partir de ahora.';

  @override
  String recurringEndNotBefore(String date) {
    return 'Elige el $date o después: ya hay un pago añadido hasta entonces';
  }

  @override
  String get discardChangesTitle => '¿Descartar los cambios?';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discard => 'Descartar';

  @override
  String recurringHoldText(int count, String range) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hay $countString pagos pendientes, $range.',
      one: 'Hay 1 pago pendiente, $range.',
    );
    return '$_temp0';
  }

  @override
  String recurringHoldMany(int max, String range) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Hay más de $maxString pagos pendientes, $range.';
  }

  @override
  String addAllN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir los $countString',
      one: 'Añadirlo',
    );
    return '$_temp0';
  }

  @override
  String addFirstN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Añadir los primeros $countString';
  }

  @override
  String get skipThem => 'Omitirlos';

  @override
  String addedPayments(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $countString pagos',
      one: 'Se añadió 1 pago',
      zero: 'No se añadió ningún pago',
    );
    return '$_temp0';
  }

  @override
  String skippedPayments(int count, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron $countString. Próximo: $date',
      one: 'Se omitió 1. Próximo: $date',
    );
    return '$_temp0';
  }

  @override
  String skippedPaymentsNoNext(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron $countString. No hay más pagos.',
      one: 'Se omitió 1. No hay más pagos.',
    );
    return '$_temp0';
  }

  @override
  String get recurringGenerateFailed =>
      'No se pudieron añadir sus pagos. Se volverá a intentar.';

  @override
  String binPaymentOf(String title, String schedule) {
    return 'Pago de $title ($schedule)';
  }

  @override
  String restoreRecurringCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gastos recurrentes',
      one: '1 gasto recurrente',
    );
    return '$_temp0';
  }

  @override
  String get changesSaved => 'Cambios guardados';

  @override
  String get newRecurring => 'Nuevo gasto recurrente';

  @override
  String get recurringNoneWaiting => 'No hay nada pendiente de decidir.';

  @override
  String get recurringNoneActive =>
      'No hay nada activo. Activa «Se repite» al añadir un gasto.';

  @override
  String get recurringNoneArchived =>
      'No hay nada archivado. Aquí van los detenidos y los terminados.';

  @override
  String get repeatEndsAfter => 'Tras';

  @override
  String repeatEndsAfterUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pagos',
      one: 'pago',
    );
    return '$_temp0';
  }

  @override
  String get repeatCountLabel => 'Número de pagos';

  @override
  String repeatCountError(int min, int max) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'De $minString a $maxString';
  }

  @override
  String repeatLast(String date) {
    return 'último $date';
  }

  @override
  String repeatCountTooLate(String date) {
    return 'El último pago sería después del $date. Usa menos pagos.';
  }

  @override
  String updatedRepeats(String schedule) {
    return 'Actualizado. Se repite: $schedule';
  }

  @override
  String updatedWithEarlier(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Actualizado con $countString pagos anteriores.',
      one: 'Actualizado con 1 pago anterior.',
    );
    return '$_temp0';
  }

  @override
  String get howOften => 'Frecuencia';

  @override
  String get firstPayment => 'Primer pago';

  @override
  String get newItemNotice =>
      'Al guardar se crea un nuevo gasto recurrente; este se archiva.';

  @override
  String get scheduleLockedNotice =>
      'Hay pagos pendientes. Añádelos u omítelos en la página del gasto antes de cambiar la frecuencia.';

  @override
  String firstPaymentTooEarly(String date) {
    return 'Elige el $date o después';
  }

  @override
  String get newItemTitle => '¿Crear un nuevo gasto recurrente?';

  @override
  String newItemText(int count, String name, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cambiar la frecuencia crea un gasto nuevo, $name, desde el $date. Este se archiva: no añade nada más, y puedes restaurarlo o eliminarlo desde el Archivo. Sus $countString pagos se quedan.',
      one:
          'Cambiar la frecuencia crea un gasto nuevo, $name, desde el $date. Este se archiva: no añade nada más, y puedes restaurarlo o eliminarlo desde el Archivo. Su pago se queda.',
      zero:
          'Cambiar la frecuencia crea un gasto nuevo, $name, desde el $date. Este se archiva: no añade nada más, y puedes restaurarlo o eliminarlo desde el Archivo.',
    );
    return '$_temp0';
  }

  @override
  String get createNew => 'Crear nuevo';

  @override
  String recurringArchivedShort(String title) {
    return '$title archivado';
  }

  @override
  String archivedReplaced(String date) {
    return 'reemplazado el $date';
  }

  @override
  String swapTitle(String name) {
    return '¿Volver a $name?';
  }

  @override
  String swapText(int count, String name) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$name se archiva: no añade nada más. Sus $countString pagos ya añadidos se quedan. Elimina de la lista los que no quieras.',
      one:
          '$name se archiva: no añade nada más. Su pago ya añadido se queda. Elimínalo de la lista si no lo quieres.',
      zero: '$name se archiva: no añade nada más. No añadió pagos.',
    );
    return '$_temp0';
  }

  @override
  String get switchBack => 'Volver';

  @override
  String switchedBack(String name) {
    return 'Se volvió a $name';
  }

  @override
  String get addSelected => 'Añadir algunos';

  @override
  String get whichPaymentsToAdd => '¿Qué pagos añadir?';

  @override
  String get selectNone => 'Ninguno';

  @override
  String addN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $countString',
      one: 'Añadir 1',
    );
    return '$_temp0';
  }

  @override
  String skipAllN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Omitir los $countString',
      one: 'Omitirlo',
    );
    return '$_temp0';
  }

  @override
  String addedAndSkipped(int added, int skipped, String date) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString añadidos, $skippedString omitidos. Próximo: $date';
  }

  @override
  String addedAndSkippedNoNext(int added, int skipped) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString añadidos, $skippedString omitidos. No hay más pagos.';
  }

  @override
  String addedAndSkippedMore(int added, int skipped) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString añadidos, $skippedString omitidos. Hay más pendientes.';
  }

  @override
  String get upcomingTitle => 'Próximos pagos';

  @override
  String get upcomingTooltip => 'Próximos pagos';

  @override
  String get upcomingEmpty =>
      'No hay nada próximo. Aquí aparecen los gastos recurrentes que añadas.';

  @override
  String get upcomingEnd => 'Muestra los próximos 12 meses.';

  @override
  String get skip => 'Omitir';

  @override
  String skipDialogTitle(String title, String date) {
    return '¿Omitir $title el $date?';
  }

  @override
  String get skipOnlyThis => 'Omitir solo este pago';

  @override
  String stopItem(String title) {
    return 'Detener $title: no más pagos';
  }

  @override
  String get skipped => 'Omitido';

  @override
  String skippedOn(String title, String date) {
    return 'Se omitió $title el $date';
  }

  @override
  String get bringBack => 'Recuperar';

  @override
  String paymentBack(String title, String date) {
    return '$title del $date ha vuelto';
  }

  @override
  String upcomingRowSemantics(String title, String amount, String date) {
    return '$title, $amount, $date';
  }

  @override
  String get onlyRecurring => 'Solo recurrentes';

  @override
  String get filterChipRecurring => '🔁 Recurrentes';

  @override
  String get noUpcomingMatchTooltip =>
      'Ningún próximo pago coincide con los filtros';

  @override
  String get noUpcomingMatchFilters =>
      'Ningún próximo pago coincide con los filtros de Inicio.';
}
