FROM owncloud/ubuntu:16.04

LABEL maintainer="ownCloud DevOps <devops@owncloud.com>" \
  org.label-schema.name="ownCloud CI PHP" \
  org.label-schema.vendor="ownCloud GmbH" \
  org.label-schema.schema-version="1.0"

VOLUME ["/var/www/owncloud"]

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base && \
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php

RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php7.0 php7.0-xml php7.0-mbstring php7.0-curl php7.0-gd php7.0-zip php7.0-intl php7.0-sqlite3 php7.0-mysql php7.0-pgsql php7.0-soap php7.0-phpdbg php-redis php-memcached php-imagick && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

COPY rootfs /
WORKDIR /var/www/owncloud
