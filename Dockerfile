FROM owncloud/ubuntu:16.04

LABEL maintainer="ownCloud DevOps <devops@owncloud.com>" \
  org.label-schema.name="ownCloud CI PHP" \
  org.label-schema.vendor="ownCloud GmbH" \
  org.label-schema.schema-version="1.0"

VOLUME ["/var/www/owncloud"]

ENV ORACLE_HOME=/usr/lib/oracle/12.2/client64
ENV LD_LIBRARY_PATH=/usr/lib/oracle/12.2/client64/lib/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base && \
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/apache2

RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y libxml2-utils git-core unzip npm nodejs-legacy wget fontconfig libaio1 php7.2 php7.2-dev php7.2-xml php7.2-mbstring php7.2-curl php7.2-gd php7.2-zip php7.2-intl php7.2-sqlite3 php7.2-mysql php7.2-pgsql php7.2-soap php7.2-phpdbg php-redis php-memcached php-imagick php-smbclient php-apcu && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

RUN curl -sSo oracle-instantclient12.2-basic_12.2.0.1.0-2_amd64.deb https://minio.owncloud.com/packages/oracle/oracle-instantclient12.2-basic_12.2.0.1.0-2_amd64.deb && \
  dpkg -i oracle-instantclient12.2-basic_12.2.0.1.0-2_amd64.deb && \
  rm oracle-instantclient12.2-basic_12.2.0.1.0-2_amd64.deb

RUN curl -sSo oracle-instantclient12.2-sqlplus_12.2.0.1.0-2_amd64.deb https://minio.owncloud.com/packages/oracle/oracle-instantclient12.2-sqlplus_12.2.0.1.0-2_amd64.deb && \
  dpkg -i oracle-instantclient12.2-sqlplus_12.2.0.1.0-2_amd64.deb && \
  rm oracle-instantclient12.2-sqlplus_12.2.0.1.0-2_amd64.deb

RUN curl -sSo oracle-instantclient12.2-devel_12.2.0.1.0-2_amd64.deb https://minio.owncloud.com/packages/oracle/oracle-instantclient12.2-devel_12.2.0.1.0-2_amd64.deb && \
  dpkg -i oracle-instantclient12.2-devel_12.2.0.1.0-2_amd64.deb && \
  rm oracle-instantclient12.2-devel_12.2.0.1.0-2_amd64.deb

RUN ln -s /usr/include/oracle/12.2/client64 /usr/lib/oracle/12.2/client64/include && \
  echo "instantclient,/usr/lib/oracle/12.2/client64/lib" | pecl install oci8-2.1.8

COPY rootfs /
WORKDIR /var/www/owncloud
