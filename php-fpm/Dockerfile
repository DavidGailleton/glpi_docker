FROM php:8.3-fpm-alpine

ENV GLPI_VERSION=10.0.18

COPY conf.d/*.ini $PHP_INI_DIR/conf.d/

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN apk update \
  && apk add --no-cache \
    icu-dev \
    zlib-dev \
    libpng-dev \
    libpng \
    libjpeg-turbo-dev \
    freetype-dev \
    bzip2-dev \
    libzip-dev \
    openldap-dev \
    libsodium-dev \
    mariadb-dev

# Configure and install GD with proper image support
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd

# Install other PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    intl \
    mysqli \
    pdo_mysql \
    exif \
    bz2 \
    zip \
    ldap \
    opcache \
    sodium

# Install Redis and APCu extensions
RUN apk add --no-cache pcre-dev ${PHPIZE_DEPS} \
  && pecl install redis apcu \
  && docker-php-ext-enable redis apcu \
  && apk del pcre-dev ${PHPIZE_DEPS}

RUN docker-php-source delete

WORKDIR /var/www/html

ADD https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz /tmp/

RUN tar -zxf /tmp/glpi-${GLPI_VERSION}.tgz -C /tmp/ \
	&& mv /tmp/glpi/* /var/www/html \
	&& chown -R www-data:www-data /var/www/html \
	&& rm -rf /tmp/glpi-${GLPI_VERSION}.tgz

# Créer les dossiers GLPI nécessaires avec les bonnes permissions
RUN mkdir -p /var/www/html/files/_cache \
	&& mkdir -p /var/www/html/files/_cron \
	&& mkdir -p /var/www/html/files/_dumps \
	&& mkdir -p /var/www/html/files/_graphs \
	&& mkdir -p /var/www/html/files/_lock \
	&& mkdir -p /var/www/html/files/_pictures \
	&& mkdir -p /var/www/html/files/_plugins \
	&& mkdir -p /var/www/html/files/_rss \
	&& mkdir -p /var/www/html/files/_sessions \
	&& mkdir -p /var/www/html/files/_tmp \
	&& mkdir -p /var/www/html/files/_uploads \
	&& chown -R www-data:www-data /var/www/html \
	&& chmod -R 755 /var/www/html/files

# Install netcat for health checks in entrypoint script
RUN apk add --no-cache netcat-openbsd

# Copy and configure entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9000/tcp 

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
