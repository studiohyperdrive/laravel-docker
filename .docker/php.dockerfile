# Use php 7!
FROM php:7.2-fpm

# just the basics needed for a typical Laravel CRUD app 
RUN apt-get update && apt-get install -y libmcrypt-dev \
    mysql-client --no-install-recommends \
    && pecl install mcrypt-1.0.1 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install pdo_mysql
