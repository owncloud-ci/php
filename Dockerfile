FROM owncloud/ubuntu:16.04
MAINTAINER ownCloud DevOps <devops@owncloud.com>

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  apt-get update -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php7.1 php7.1-xml php7.1-mbstring php7.1-curl php7.1-gd php7.1-zip php7.1-intl php7.1-sqlite3 php7.1-mysql php7.1-pgsql php7.1-soap php7.1-phpdbg && \
  apt-get install -y php-redis php-memcached php-imagick && \
  apt-get upgrade -y && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/bin --filename=composer
