#!/usr/bin/env bash
set -eo pipefail

declare -x XDEBUG_ENABLED
[[ -z "${XDEBUG_ENABLED}" ]] && XDEBUG_ENABLED="false"

declare -x XDEBUG_REMOTE_ENABLE
[[ -z "${XDEBUG_REMOTE_ENABLE}" ]] && XDEBUG_REMOTE_ENABLE="1"

declare -x XDEBUG_REMOTE_AUTOSTART
[[ -z "${XDEBUG_REMOTE_AUTOSTART}" ]] && XDEBUG_REMOTE_AUTOSTART="1"

declare -x XDEBUG_REMOTE_PORT
[[ -z "${XDEBUG_REMOTE_PORT}" ]] && XDEBUG_REMOTE_PORT="9000"

declare -x XDEBUG_REMOTE_HOST
[[ -z "${XDEBUG_REMOTE_HOST}" ]] && XDEBUG_REMOTE_HOST="localhost"

declare -x XDEBUG_REMOTE_CONNECT_BACK
[[ -z "${XDEBUG_REMOTE_CONNECT_BACK}" ]] && XDEBUG_REMOTE_CONNECT_BACK="0"

declare -x XDEBUG_IDEKEY
[[ -z "${XDEBUG_IDEKEY}" ]] && XDEBUG_IDEKEY="PHPSTORM"

if [[ "${XDEBUG_ENABLED}" == "true" || "${XDEBUG_ENABLED}" == "1" ]]; then

  echo "configuring xdebug"
  php_version=$(phpquery -V)

  envsubst \
    '${XDEBUG_REMOTE_ENABLE} ${XDEBUG_REMOTE_AUTOSTART} ${XDEBUG_IDEKEY} ${XDEBUG_REMOTE_PORT} ${XDEBUG_REMOTE_HOST} ${XDEBUG_REMOTE_CONNECT_BACK}' \
      < /etc/templates/xdebug.tmpl >| "/etc/php/${php_version}/mods-available/00-xdebug.ini"

  for SAPI in $( echo "cli,apache2,fpm" | tr "," " ")
    do
      if [[ ! -e "/etc/php/${php_version}/${SAPI}/conf.d/00-xdebug.ini" ]]; then
        ln -s /etc/php/${php_version}/mods-available/00-xdebug.ini /etc/php/${php_version}/${SAPI}/conf.d/00-xdebug.ini
      fi
    done
fi

true