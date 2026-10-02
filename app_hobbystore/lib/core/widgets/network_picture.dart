import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen remota con caché en disco. Sin URL, o si falla la descarga,
/// muestra un ícono de reemplazo para que la grilla no quede con huecos.
class NetworkPicture extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const NetworkPicture(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
    final imageUrl = url;
    if (imageUrl == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
