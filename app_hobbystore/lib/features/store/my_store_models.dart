const storeStatusLabels = {
  'pending': 'En revisión',
  'approved': 'Aprobada',
  'suspended': 'Suspendida',
};

/// Una tienda vista por su dueño o por el admin (incluye estado y WhatsApp).
class MyStore {
  final String slug;
  final String name;
  final String? description;
  final String city;
  final String whatsappPhone;
  final List<String> deliveryOptions;
  final String? logoUrl;
  final String status;
  final bool isFeatured;

  /// Motivo de una suspensión, escrito por el admin.
  final String? reviewNote;

  const MyStore({
    required this.slug,
    required this.name,
    required this.city,
    required this.whatsappPhone,
    required this.deliveryOptions,
    required this.status,
    required this.isFeatured,
    this.description,
    this.logoUrl,
    this.reviewNote,
  });

  factory MyStore.fromJson(Map<String, dynamic> json) => MyStore(
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    city: json['city'] as String,
    whatsappPhone: json['whatsapp_phone'] as String,
    deliveryOptions: List<String>.from(json['delivery_options'] as List),
    logoUrl: json['logo_url'] as String?,
    status: json['status'] as String,
    isFeatured: json['is_featured'] as bool,
    reviewNote: json['review_note'] as String?,
  );

  bool get isApproved => status == 'approved';

  /// Los 8 dígitos del celular, sin el +591.
  String get localWhatsapp => whatsappPhone.replaceFirst('+591', '');
}

/// Datos del formulario de tienda, tal como los espera la API.
class StoreFields {
  final String name;
  final String description;
  final String city;

  /// 8 dígitos; se envía con +591.
  final String localWhatsapp;
  final List<String> deliveryOptions;

  const StoreFields({
    required this.name,
    required this.description,
    required this.city,
    required this.localWhatsapp,
    required this.deliveryOptions,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'city': city,
    'whatsapp_phone': '+591$localWhatsapp',
    'delivery_options': deliveryOptions,
  };
}
