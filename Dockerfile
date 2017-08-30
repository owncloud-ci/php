FROM owncloud/ubuntu:16.04
MAINTAINER ownCloud DevOps <devops@owncloud.com>

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  apt-get update -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php5.6 php5.6-xml php5.6-mbstring php5.6-curl php5.6-gd php5.6-zip php5.6-intl php5.6-sqlite3 php5.6-mysql php5.6-pgsql php5.6-soap && \
  apt-get install -y php-redis php-memcached php-imagick && \
  apt-get upgrade -y && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/bin --filename=composer
