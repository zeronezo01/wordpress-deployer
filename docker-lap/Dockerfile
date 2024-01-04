FROM ubuntu:20.04
MAINTAINER zeronezo01 zeronezo01@163.com

ARG DOMAIN

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
#install apache2 source
RUN apt install -y openssl cron curl socat apache2 apache2-utils
#install php source
RUN apt install -y php7.4 libapache2-mod-php7.4 php7.4-mysql php7.4-curl php7.4-gd php7.4-xml\
    php7.4-mbstring php7.4-xmlrpc php7.4-zip php7.4-zip php7.4-intl

RUN apt clean

COPY apache2/000-default.conf /etc/apache2/sites-available/
COPY apache2/default-ssl.conf /etc/apache2/sites-available/

RUN ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf
RUN a2enmod ssl
RUN a2enmod rewrite
RUN mkdir -p /etc/apache2/ssl

CMD ["apache2ctl", "-D", "FOREGROUND"]
