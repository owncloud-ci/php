FROM owncloud/ubuntu:16.04
MAINTAINER ownCloud DevOps <devops@owncloud.com>

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base

RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget php7.1 php7.1-xml php7.1-mbstring php7.1-curl && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/bin --filename=composer
