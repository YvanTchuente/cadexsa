FROM node:alpine AS node_stage

#install dependencies
ENV HOME=/home/node/app/
ENV NODE_ENV=production
WORKDIR $HOME
COPY package.json package-lock.json ./
RUN npm install

FROM composer AS composer_stage

# Install dependencies
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-progress

FROM php:8.0.9-apache

# Use the php default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install gd, pdo_mysql and opcache extensions and enable socket extension
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) --ini-name $PHP_INI_DIR/php.ini gd \
    && docker-php-ext-install --ini-name $PHP_INI_DIR/php.ini pdo_mysql opcache sockets

# Enable Apache modules: rewrite
RUN a2enmod rewrite;

ENV HOME=/var/www
ENV DOCUMENT_ROOT=/var/www/html
ENV TIME_ZONE=Africa/Douala

# Copy application source
WORKDIR ${HOME}
COPY app/ html/
COPY --from=composer_stage  /app/vendor ./vendor
COPY --from=node_stage /home/node/app/node_modules ./node_modules
RUN chown -R www-data:www-data .
VOLUME [ "/var/www/html/logs" ]

# Use production configurations
RUN mv "./html/config/db-config-production.php" "./html/config/db-config.php" \
    && rm "./html/config/db-config-development.php" \
    && sed -ri "s/db-config-development/db-config/g" ./html/config/index.php \
    && sed -ri "s/db-config-development/db-config/" ./html/library/Database/Connection.php

# Configure php.ini file
RUN sed -ri -e "s!;date.timezone =!date.timezone = $TIME_ZONE!g" ${PHP_INI_DIR}/php.ini

WORKDIR ${DOCUMENT_ROOT}