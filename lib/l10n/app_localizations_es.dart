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
    return 'Actualizando tus datos ($current de $total)';
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
    return 'Paso $current de $total';
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
    return 'Archivados ($count)';
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
    return 'Usa como máximo $max caracteres';
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
    return 'Usa como máximo $max cifras antes de los decimales';
  }

  @override
  String amountErrorTooManyDecimals(int digits, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      digits,
      locale: localeName,
      other: '$currency solo tiene $digits decimales',
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'hace $days días',
      one: 'hace 1 día',
    );
    return 'Eliminado $_temp0';
  }

  @override
  String removedInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'se borra en $days días',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
      one: '1 gasto',
    );
    return '\"$name\" se usa en $_temp0.';
  }

  @override
  String usedByExpensesWithBin(String name, int count, int binned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
      one: '1 gasto',
    );
    return '\"$name\" se usa en $_temp0 ($binned en la papelera).';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'hace $days días',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
      one: '1 gasto',
      zero: 'Ningún gasto',
    );
    return '$_temp0';
  }

  @override
  String restoreBinCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $count en la papelera',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
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
}
