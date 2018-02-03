#
# Builder
#
FROM abiosoft/caddy:builder as builder

ARG version="0.10.10"
ARG plugins="git"

RUN VERSION=${version} PLUGINS=${plugins} /bin/sh /usr/bin/builder.sh

#
# Final stage
#

FROM php:fpm-alpine3.7

RUN apk upgrade --update && apk add git libpng-dev freetype-dev libjpeg-turbo-dev \
&& docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
&& docker-php-ext-configure zip \
&& docker-php-ext-install gd zip

RUN git clone -b master https://github.com/getgrav/grav.git /srv/src && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer

# install caddy
COPY --from=builder /install/caddy /usr/sbin/caddy

# validate install
RUN /usr/sbin/caddy -version
RUN /usr/sbin/caddy -plugins

WORKDIR /srv/src

RUN composer install --no-dev -o && \
    bin/grav install && \
    bin/gpm selfupgrade -f && \
    bin/gpm install admin && \
    chown -R www-data:www-data /srv/src/ 

EXPOSE 80 443 2015 9000
WORKDIR /srv

ENTRYPOINT ["/usr/sbin/caddy"]

CMD ["--conf", "/etc/Caddyfile", "--log", "stdout"]
