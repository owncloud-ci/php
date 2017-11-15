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
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php5.6 php5.6-xml php5.6-mbstring php5.6-curl php5.6-gd php5.6-zip php5.6-intl php5.6-sqlite3 php5.6-mysql php5.6-pgsql php5.6-soap php5.6-phpdbg php-redis php-memcached php-imagick && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

COPY rootfs /
WORKDIR /var/www/owncloud
