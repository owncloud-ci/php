FROM owncloud/ubuntu:16.04

LABEL maintainer="ownCloud DevOps <devops@owncloud.com>" \
  org.label-schema.name="ownCloud CI PHP" \
  org.label-schema.vendor="ownCloud GmbH" \
  org.label-schema.schema-version="1.0"

VOLUME ["/var/www/owncloud"]

RUN apt-get update -y && \
  apt-get install -y software-properties-common language-pack-en-base && \
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && \
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/apache2

RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y git-core unzip npm nodejs-legacy wget fontconfig libaio1 php7.0 php7.0-xml php7.0-mbstring php7.0-curl php7.0-gd php7.0-zip php7.0-intl php7.0-sqlite3 php7.0-mysql php7.0-pgsql php7.0-soap php7.0-phpdbg php-redis php-memcached php-imagick php-smbclient php-apcu php7.0-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#ORACLE INSTALLATION
#get the zips & unzip them & set paths & install oci8
RUN mkdir /opt/oracle && \
  wget -O /opt/oracle/instantclient-basic-linux.x64-12.1.0.2.0.zip \
  https://github.com/DeepDiver1975/oracle_instant_client_for_ubuntu_64bit\
/raw/12.1.as.zip/zips/instantclient-basic-linux.x64-12.1.0.2.0.zip && \
  wget -O /opt/oracle/instantclient-sdk-linux.x64-12.1.0.2.0.zip \
  https://github.com/DeepDiver1975/oracle_instant_client_for_ubuntu_64bit\
/raw/12.1.as.zip/zips/instantclient-sdk-linux.x64-12.1.0.2.0.zip && \
  wget -O /opt/oracle/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip \
  https://github.com/DeepDiver1975/oracle_instant_client_for_ubuntu_64bit\
/raw/12.1.as.zip/zips/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip && \
  unzip /opt/oracle/instantclient-basic-linux.x64-12.1.0.2.0.zip -d /opt/oracle && \
  unzip /opt/oracle/instantclient-sdk-linux.x64-12.1.0.2.0.zip -d /opt/oracle && \
  unzip /opt/oracle/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip -d /opt/oracle && \
  rm /opt/oracle/*.zip && \
  ln -s /opt/oracle/instantclient_12_1/libclntsh.so.12.1 /opt/oracle/instantclient_12_1/libclntsh.so && \
  ln -s /opt/oracle/instantclient_12_1/libocci.so.12.1 /opt/oracle/instantclient_12_1/libocci.so && \
  echo /opt/oracle/instantclient_12_1 > /etc/ld.so.conf.d/oracle-instantclient && \
  ldconfig && \
  printf "instantclient,/opt/oracle/instantclient_12_1" | pecl install oci8 && \
  echo "extension=oci8.so" >> /etc/php/7.0/apache2/php.ini && \
  echo "extension=oci8.so" >> /etc/php/7.0/cli/php.ini

ENV ORACLE_HOME=/opt/oracle/instantclient_12_1 LD_LIBRARY_PATH=/opt/oracle/instantclient_12_1
ENV PATH ${ORACLE_HOME}:${PATH}

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

COPY rootfs /
WORKDIR /var/www/owncloud
