# Stage 1: Build with composer
FROM composer:1.7 as builder

WORKDIR /var/www
COPY . ./

RUN composer install

# Stage 2: use php 7!
FROM php:7.2-fpm as server

# just the basics needed for a typical Laravel CRUD app 
RUN apt-get update && apt-get install -y libmcrypt-dev \
    mysql-client --no-install-recommends \
    && pecl install mcrypt-1.0.1 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install pdo_mysql

# use build from stage 1
COPY --from=builder /var/www /var/www
