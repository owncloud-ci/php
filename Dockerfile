FROM owncloud/ubuntu:16.04

LABEL maintainer="ownCloud DevOps <devops@owncloud.com>" \
  org.label-schema.name="ownCloud CI PHP" \
  org.label-schema.vendor="ownCloud GmbH" \
  org.label-schema.schema-version="1.0"

VOLUME ["/var/www/owncloud"]

ENV ORACLE_HOME=/usr/lib/oracle/12.2/client64
ENV LD_LIBRARY_PATH=/usr/lib/oracle/12.2/client64/lib/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y libxml2-utils mysql-client postgresql-client sqlite git-core unzip npm nodejs-legacy wget fontconfig libaio1 php php-dev php-xml php-mbstring php-curl php-gd php-zip php-intl php-sqlite3 php-mysql php-pgsql php-soap php-phpdbg php-redis php-memcached php-imagick php-smbclient php-apcu && \
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
  echo "instantclient,/usr/lib/oracle/12.2/client64/lib" | pecl install oci8

COPY rootfs /
WORKDIR /var/www/owncloud
