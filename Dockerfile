FROM owncloud/ubuntu:16.04
MAINTAINER ownCloud DevOps <devops@owncloud.com>

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  apt-get update -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php7.2 php7.2-xml php7.2-mbstring php7.2-curl php7.2-gd php7.2-zip php7.2-intl php7.2-sqlite3 php7.2-mysql php7.2-pgsql && \
  apt-get install -y php-redis php-memcached php-apcu && \
  apt-get upgrade -y && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/bin --filename=composer
