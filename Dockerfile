# TODO: Consider switching to buster and relying more on civi-download-tools
# See https://github.com/michaelmcandrew/civicrm-buildkit-docker/issues/68#issuecomment-888224776 
# for more details.

FROM php:8.3-fpm

# Install apt packages
#
# Required for php extensions
# * gd: libpng-dev, libjpeg62-turbo-dev
# * imagick: libmagickwand-dev
# * imap: libc-client-dev, libkrb5-dev
# * intl: libicu-dev
# * soap: libxml2-dev
# * zip: libzip-dev
#
# Used in the build process
# * default-mysql-client
# * git
# * nodejs
# * sudo
# * unzip
# * zip
#
# Other Utilities
# * bash-completion
# * iproute2 (required to get host ip from container)
# * msmtp-mta (for routing mail to maildev)
# * rsync
# * nano
# * vim
# * less

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  apt-transport-https

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  bash-completion \
  default-mysql-client \
  git \
  iproute2 \
  less \
  libc-client-dev \
  libicu-dev \
  libjpeg62-turbo-dev \
  libkrb5-dev \
  libmagickwand-dev \
  libpng-dev \
  libxml2-dev \
  libzip-dev \
  msmtp-mta \
  nano \
  nodejs \
  rsync \
  sudo \
  unzip \
  vim \
  zip \
  && rm -r /var/lib/apt/lists/*

# Install php extensions (curl, json, mbstring, openssl, posix, phar
# are installed already and don't need to be specified here)
RUN docker-php-ext-install bcmath \
  && docker-php-ext-configure gd --with-jpeg \
  && docker-php-ext-install gd \
  && docker-php-ext-install gettext \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
  && docker-php-ext-install imap \
  && docker-php-ext-install intl \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install opcache \
  && docker-php-ext-install pdo_mysql \
  && docker-php-ext-install soap \
  && docker-php-ext-install zip

# Install and enable imagick PECL extensions
RUN pecl install imagick \
  && docker-php-ext-enable imagick

# Install xdebug PECL extension
RUN pecl install xdebug


ARG BUILDKIT_UID=1000

ARG BUILDKIT_GID=$BUILDKIT_UID

RUN addgroup --gid=$BUILDKIT_GID buildkit

RUN useradd --home-dir /buildkit --create-home --uid $BUILDKIT_UID --gid $BUILDKIT_GID buildkit

# Configure fpm to run as the buildkit user
RUN sed -i 's/user = www-data/user = buildkit/' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's/group = www-data/group = buildkit/' /usr/local/etc/php-fpm.d/www.conf

COPY sudo /etc/sudoers.d/buildkit

USER buildkit

WORKDIR /buildkit

ENV PATH="/buildkit/bin:${PATH}"

RUN git init . \
  && git remote add origin https://github.com/civicrm/civicrm-buildkit.git \
  && git pull origin master

# Need to create this before we configure apache, otherwise it will complain
RUN mkdir -p .amp/apache.d

RUN mkdir -p .cache/bower

RUN mkdir .composer

RUN mkdir .drush

RUN mkdir .npm

RUN civi-download-tools

RUN civibuild cache-warmup

COPY --chown=buildkit:buildkit amp.services.yml /buildkit/.amp/services.yml

COPY buildkit.ini /usr/local/etc/php/conf.d/buildkit.ini

COPY msmtprc /etc/msmtprc

RUN rm /buildkit/app/civicrm.settings.d/100-mail.php

COPY civibuild.conf /buildkit/app/civibuild.conf

USER root

COPY ./docker-civicrm-entrypoint /usr/local/bin

RUN chmod u+x /usr/local/bin/docker-civicrm-entrypoint

ENTRYPOINT [ "docker-civicrm-entrypoint" ]

CMD ["php-fpm"]
