FROM owncloud/ubuntu:16.04

LABEL maintainer="ownCloud DevOps <devops@owncloud.com>" \
  org.label-schema.name="ownCloud CI PHP" \
  org.label-schema.vendor="ownCloud GmbH" \
  org.label-schema.schema-version="1.0"

VOLUME ["/var/www/owncloud"]

RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y mysql-client postgresql-client sqlite git-core unzip npm nodejs-legacy wget fontconfig php php-xml php-mbstring php-curl php-gd php-zip php-intl php-sqlite3 php-mysql php-pgsql php-soap php-phpdbg php-redis php-memcached php-imagick php-smbclient php-apcu && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

COPY rootfs /
WORKDIR /var/www/owncloud
