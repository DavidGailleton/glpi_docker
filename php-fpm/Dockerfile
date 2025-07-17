FROM php:8.3-fpm-alpine

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

ADD https://github.com/glpi-project/glpi/releases/download/10.0.18/glpi-10.0.18.tgz /tmp/

RUN tar -zxf /tmp/glpi-10.0.18.tgz -C /tmp/ \
	&& mv /tmp/glpi/* /var/www/html \
	&& chown -R www-data:www-data /var/www/html \
	&& rm -rf /tmp/glpi-10.0.18.tgz

# Créer les dossiers GLPI nécessaires avec les bonnes permissions
RUN mkdir -p /var/lib/glpi/_cache \
	&& mkdir -p /var/lib/glpi/_cron \
	&& mkdir -p /var/lib/glpi/_dumps \
	&& mkdir -p /var/lib/glpi/_graphs \
	&& mkdir -p /var/lib/glpi/_lock \
	&& mkdir -p /var/lib/glpi/_pictures \
	&& mkdir -p /var/lib/glpi/_plugins \
	&& mkdir -p /var/lib/glpi/_rss \
	&& mkdir -p /var/lib/glpi/_sessions \
	&& mkdir -p /var/lib/glpi/_tmp \
	&& mkdir -p /var/lib/glpi/_uploads \
	&& chown -R www-data:www-data /var/lib/glpi \
	&& chmod -R 755 /var/lib/glpi

EXPOSE 9000/tcp 

CMD ["php-fpm"]
