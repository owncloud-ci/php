FROM owncloud/ubuntu:16.04
MAINTAINER ownCloud DevOps <devops@owncloud.com>

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  apt-get update -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig php7.0 php7.0-xml php7.0-mbstring php7.0-curl php7.0-gd php7.0-zip php7.0-intl php7.0-sqlite3 php7.0-mysql php7.0-pgsql && \
  apt-get upgrade -y && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/bin --filename=composer
