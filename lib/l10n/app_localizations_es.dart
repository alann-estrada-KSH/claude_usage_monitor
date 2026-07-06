// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Monitor de Uso de Claude';

  @override
  String get dashboardTitle => 'Monitor de Uso';

  @override
  String get settingsTooltip => 'Configuración';

  @override
  String get focusModeTooltip => 'Modo enfoque (pantalla completa)';

  @override
  String trayTooltipLine(String label, String five, String weekly) {
    return '$label · Sesión $five% / Semanal $weekly%';
  }

  @override
  String get trayShowHide => 'Mostrar/Ocultar';

  @override
  String get trayRefreshNow => 'Actualizar ahora';

  @override
  String get trayQuit => 'Salir';

  @override
  String get addAccountTooltip => 'Agregar cuenta';

  @override
  String get emptyStateTitle => 'Aún no hay cuentas';

  @override
  String get emptyStateBody =>
      'Agrega una cuenta de Claude.ai para empezar a monitorear sus límites de uso de 5 horas y semanal.';

  @override
  String get addAccountButton => 'Agregar cuenta';

  @override
  String get nameAccountDialogTitle => 'Nombra esta cuenta';

  @override
  String get nameAccountHint => 'ej. Trabajo, Personal';

  @override
  String get cancel => 'Cancelar';

  @override
  String get continueToLogin => 'Continuar a inicio de sesión';

  @override
  String get refreshNowTooltip => 'Actualizar ahora';

  @override
  String get removeAccountTooltip => 'Eliminar cuenta';

  @override
  String get renameAccountTooltip => 'Renombrar cuenta';

  @override
  String get renameAccountDialogTitle => 'Renombra esta cuenta';

  @override
  String get save => 'Guardar';

  @override
  String get noUsageDataYet => 'Aún no hay datos de uso.';

  @override
  String usageDataUnavailable(String reason) {
    return 'Datos de uso no disponibles ($reason)';
  }

  @override
  String get unknownReason => 'razón desconocida';

  @override
  String get sessionExpiredMessage => 'Sesión expirada.';

  @override
  String get reconnectButton => 'Reconectar';

  @override
  String get fiveHourWindow => 'Sesión';

  @override
  String get weeklyWindow => 'Límite semanal';

  @override
  String updatedAgo(String time) {
    return 'Actualizado $time';
  }

  @override
  String get justNow => 'justo ahora';

  @override
  String minutesAgo(int minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String hoursAgo(int hours) {
    return 'hace ${hours}h';
  }

  @override
  String daysAgo(int days) {
    return 'hace ${days}d';
  }

  @override
  String resetsApprox(String time) {
    return 'Se reinicia ~$time';
  }

  @override
  String get resetNow => 'ahora';

  @override
  String resetInHoursMinutes(int hours, int minutes) {
    return 'en ${hours}h ${minutes}m';
  }

  @override
  String resetInMinutes(int minutes) {
    return 'en ${minutes}m';
  }

  @override
  String resetInDays(int days) {
    return 'en ${days}d';
  }

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get removeAccountDialogTitle => '¿Eliminar cuenta?';

  @override
  String removeAccountDialogBody(String label) {
    return 'Esto elimina \"$label\" del panel. No cierra tu sesión en claude.ai.';
  }

  @override
  String get remove => 'Eliminar';

  @override
  String get loginPageTitle => 'Inicia sesión en Claude.ai';

  @override
  String get loginDone => 'Listo';

  @override
  String get loginBanner =>
      'Inicia sesión abajo, luego toca \"Listo\" cuando llegues a tu pantalla de chat de Claude. Nada de lo que escribas aquí sale de este dispositivo.';

  @override
  String get loginDesktopHint =>
      'Se abrió una ventana de inicio de sesión aparte. Inicia sesión ahí, luego vuelve aquí y toca \"Listo\".';

  @override
  String get settingsPageTitle => 'Configuración';

  @override
  String get offlineMessage =>
      'Sin conexión a internet -- actualizaciones en pausa hasta que vuelva.';

  @override
  String get statusUnknown =>
      'Estado de Claude desconocido (no se pudo contactar status.claude.com)';

  @override
  String get statusChecking => 'Verificando estado de Claude...';

  @override
  String get statusSection => 'Actualización de estado de Claude';

  @override
  String get statusPageTitle => 'Estado de Claude';

  @override
  String statusLastChecked(String time) {
    return 'Última consulta: $time';
  }

  @override
  String get statusIncidentsTitle => 'Incidentes sin resolver';

  @override
  String get statusNoIncidents => 'Ninguno reportado.';

  @override
  String get refreshIntervalSection => 'Intervalo de actualización';

  @override
  String refreshIntervalDescription(int seconds) {
    return 'Con qué frecuencia recargar claude.ai/settings/usage en segundo plano. Mínimo ${seconds}s para no saturar el sitio.';
  }

  @override
  String get appearanceSection => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get accentColorSection => 'Color de acento';

  @override
  String get fontSection => 'Fuente';

  @override
  String get fontMonospace => 'Monoespaciada';

  @override
  String get fontComicSans => 'Comic Sans';

  @override
  String get fontConsolas => 'Consolas';

  @override
  String get fontCourierNew => 'Courier New';

  @override
  String get fontGeorgia => 'Georgia';

  @override
  String get languageSection => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get timeFormatSection => 'Formato de hora';

  @override
  String get timeFormat12h => '12h';

  @override
  String get timeFormat24h => '24h';

  @override
  String get focusModeAccountsSection => 'Cuentas visibles en modo enfoque';

  @override
  String get thresholdsSection => 'Umbrales de color de uso';

  @override
  String thresholdWarning(int percent) {
    return 'Advertencia en $percent%';
  }

  @override
  String thresholdCritical(int percent) {
    return 'Crítico en $percent%';
  }

  @override
  String get diagnosticsSection => 'Diagnóstico';

  @override
  String diagnosticsBackend(String backend) {
    return 'Motor de WebView en esta plataforma: $backend';
  }

  @override
  String get diagnosticsBackendAndroid =>
      'flutter_inappwebview (WebView integrado)';

  @override
  String get diagnosticsBackendDesktop =>
      'desktop_webview_window (webkit2gtk / WebView2)';

  @override
  String get diagnosticsRunning => 'Obteniendo datos...';

  @override
  String get diagnosticsRunButton => 'Ejecutar ahora para todas las cuentas';

  @override
  String get diagnosticsNoAccounts => 'Aún no hay cuentas que diagnosticar.';

  @override
  String get diagnosticsNeverScraped => 'Nunca se ha consultado';

  @override
  String get diagnosticsParsedOk => 'Interpretado correctamente';

  @override
  String get diagnosticsParseFailed => 'Falló la interpretación';

  @override
  String get diagnosticsFetchedAt => 'Consultado el';

  @override
  String get diagnosticsFiveHourPercent => '% de 5 horas';

  @override
  String get diagnosticsFiveHourReset => 'Reinicio de 5 horas';

  @override
  String get diagnosticsWeeklyPercent => '% semanal';

  @override
  String get diagnosticsWeeklyReset => 'Reinicio semanal';

  @override
  String get diagnosticsParseError => 'Error de interpretación';

  @override
  String get diagnosticsRawPageText => 'Respuesta cruda de la API';

  @override
  String get diagnosticsCopyRawText => 'Copiar';

  @override
  String get debugModeSection => 'Modo debug';

  @override
  String get debugModeToggle =>
      'Mostrar log de notificaciones y herramientas de prueba';

  @override
  String get debugPanelSection => 'Debug';

  @override
  String get debugSendTestNotification => 'Enviar notificación de prueba';

  @override
  String get debugTestNotificationTitle => 'Notificación de prueba';

  @override
  String get debugTestNotificationBody =>
      'Si ves esto, las notificaciones funcionan.';

  @override
  String get debugSendScheduledTestNotification =>
      'Enviar notificación programada de prueba (15s)';

  @override
  String get debugScheduledTestNotificationBody =>
      'Si ves esto, las notificaciones programadas funcionan incluso en segundo plano.';

  @override
  String get debugScheduledTestSent =>
      'Programada -- llegará en unos 15 segundos.';

  @override
  String get keepAliveSection => 'Mantener sesión activa';

  @override
  String get keepAliveDescription =>
      'Hace ping periódico en segundo plano (con WorkManager, respetando batería) para evitar que Claude cierre tu sesión por inactividad. Mínimo 15 minutos -- es el límite del sistema en Android.';

  @override
  String get keepAliveToggle => 'Mantener sesión activa en segundo plano';

  @override
  String debugNotificationsEnabled(String status) {
    return 'Permiso de notificaciones en Android concedido: $status';
  }

  @override
  String get debugYes => 'sí';

  @override
  String get debugNo => 'no';

  @override
  String get debugNotificationLog =>
      'Log de notificaciones (llaves ya disparadas)';

  @override
  String get debugNotificationLogEmpty => 'Nada registrado aún.';

  @override
  String get resetSection => 'Restablecer';

  @override
  String get resetDescription =>
      'Restablece toda la configuración (intervalos, tema, color, fuente, umbrales, etc.) a sus valores originales. No afecta tus cuentas ni sesiones.';

  @override
  String get resetButton => 'Restablecer configuración';

  @override
  String get resetDialogTitle => '¿Restablecer configuración?';

  @override
  String get resetDialogBody =>
      'Esto regresará todas las preferencias a sus valores originales. No se puede deshacer.';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetDone => 'Configuración restablecida.';

  @override
  String get creditsLine =>
      'Hecho por Alann Estrada -- github.com/alannnn-estrada';

  @override
  String get aboutFooter =>
      'Herramienta no oficial, no afiliada ni respaldada por Anthropic. 100% local: sin telemetría, sin analítica, las cookies nunca salen de este dispositivo.';
}
