import 'package:url_launcher/url_launcher.dart';

/// Abre enlaces fuera de la app (WhatsApp). Inyectable para que los tests no
/// dependan del plugin nativo.
class ExternalLinks {
  const ExternalLinks();

  /// wa.me es https: el sistema lo abre en WhatsApp si está instalado, si no
  /// en el navegador. Por eso no hace falta canLaunchUrl ni declarar esquemas.
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
