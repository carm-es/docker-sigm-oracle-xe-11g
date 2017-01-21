#!/bin/bash

# Establecer castellano en la Debian que viene 
# con PostGres/9.2

 sed -i "s/^#\ es_ES/es_ES/g" /etc/locale.gen

 echo "locales locales/locales_to_be_generated multiselect es_ES ISO-8859-1, es_ES.UTF-8 UTF-8, es_ES@euro ISO-8859-15" | debconf-set-selections

 echo "locales locales/default_environment_locale select es_ES" | debconf-set-selections

 DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

 echo "LANG=es_ES.UTF8
LANGUAGE=es_ES.ISO-8859-15@euro
LC_ALL=es_ES.UTF8
LC_CTYPE=es_ES.UTF8
LC_MESSAGES=es_ES.UTF8
LC_TIME=es_ES.UTF8
LC_PAPER=es_ES.UTF8
LC_MEASUREMENT=es_ES.UTF8
LC_MONETARY=es_ES.UTF8
LC_NUMERIC=es_ES.UTF8" > /etc/default/locale

 echo "LANG=es_ES.UTF8" > /etc/locale.conf
