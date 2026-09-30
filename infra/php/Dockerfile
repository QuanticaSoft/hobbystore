FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev libjpeg-dev libpng-dev libwebp-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install pdo_pgsql gd exif \
    && rm -rf /var/lib/apt/lists/*

# Mismo comportamiento que flamenco: .htaccess activo y docroot = public/
ENV APACHE_DOCUMENT_ROOT=/var/www/app/public
RUN a2enmod rewrite \
    && sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri 's!/var/www/!/var/www/app/!g; s!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf
