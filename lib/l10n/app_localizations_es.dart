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
  String get homeEmptyMessage =>
      'La opción de añadir gastos llegará en la próxima actualización.';

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
