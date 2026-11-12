ARG DOCKER_HUB_PROXY=""

# --- php-base
FROM "${DOCKER_HUB_PROXY}python:3.14-slim-trixie" AS php-base

ARG CORE_TAG
ARG CORE_COMMIT
ARG PHP_API_VERSION
RUN : "${PHP_API_VERSION:?Build argument PHP_API_VERSION is required and cannot be empty.}"
ARG PHP_PACKAGE_VERSION
RUN : "${PHP_PACKAGE_VERSION:?Build argument PHP_PACKAGE_VERSION is required and cannot be empty.}"

# environment
ENV DEBIAN_FRONTEND=noninteractive

    # Uncomment when building in corporate environments
    # COPY ./cert.pem /usr/local/share/ca-certificates/rootca.pem
    # COPY ./cert.pem /usr/lib/ssl/cert.pem

RUN bash <<-'EOF' 
        apt-get update
            apt-get install -y --no-install-recommends \
                lsb-release \
                ca-certificates \
                tini \
                gettext \
                procps \
                sudo \
                nginx \
                openssl \
                gpg \
                gpg-agent \
                mariadb-client \
                rsync \
                rsyslog \
                php${PHP_PACKAGE_VERSION} \
                php${PHP_PACKAGE_VERSION}-apcu \
                php${PHP_PACKAGE_VERSION}-curl \
                php${PHP_PACKAGE_VERSION}-xml \
                php${PHP_PACKAGE_VERSION}-intl \
                php${PHP_PACKAGE_VERSION}-bcmath \
                php${PHP_PACKAGE_VERSION}-mbstring \
                php${PHP_PACKAGE_VERSION}-mysql \
                php${PHP_PACKAGE_VERSION}-redis \
                php${PHP_PACKAGE_VERSION}-gd \
                php${PHP_PACKAGE_VERSION}-fpm \
                php${PHP_PACKAGE_VERSION}-zip \
                php${PHP_PACKAGE_VERSION}-ldap \
                libmagic1 \
                libldap-common \
                librdkafka1 \
                libbrotli1 \
                libsimdjson25 \
                libzstd1 \
                ssdeep \
                stunnel4 \
                libfuzzy2 \
                unzip \
                zip \
                curl \
                uuid-runtime \
                jq
EOF

# --- composer-build
FROM php-base AS composer-build

# environment
WORKDIR /tmp
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
ARG CORE_TAG
ARG CORE_COMMIT
    
# prepare composer.json
RUN curl -o /tmp/composer.json https://raw.githubusercontent.com/MISP/MISP/${CORE_COMMIT:-${CORE_TAG}}/app/composer.json
RUN sed -i '/cake-resque/d' /tmp/composer.json
RUN sed -i 's/authentication",/authentication"/' /tmp/composer.json

# inject composer binary
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# install dependencies
RUN composer config --no-interaction allow-plugins.composer/installers true
RUN composer install
RUN bash <<-'EOF' 
            composer require --with-all-dependencies --no-interaction \
                elasticsearch/elasticsearch:^8.7.0 \
                jakub-onderka/openid-connect-php:^1.0.0 \
                certmichelin/openid-connect-php:1.3.0 \
                phpseclib/phpseclib:^3.0.47 \
                aws/aws-sdk-php
EOF

# --- php-build
FROM php-base AS php-build
# environment
ENV TZ=Etc/UTC
ARG CORE_TAG
ARG CORE_COMMIT
ARG PHP_API_VERSION
RUN : "${PHP_API_VERSION:?Build argument PHP_API_VERSION is required and cannot be empty.}"
ARG PHP_PACKAGE_VERSION
RUN : "${PHP_PACKAGE_VERSION:?Build argument PHP_PACKAGE_VERSION is required and cannot be empty.}"
ARG CORE_FLAVOR

    RUN bash <<-'EOF' 
            apt-get install -y --no-install-recommends \
                gcc \
                g++ \
                git \
                make \
                php${PHP_PACKAGE_VERSION}-dev \
                php-pear \
                libbrotli-dev \
                libfuzzy-dev \
                librdkafka-dev \
                libsimdjson-dev \
                libzstd-dev
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

# configure alternatives for php
RUN update-alternatives --set php /usr/bin/php${PHP_PACKAGE_VERSION}
RUN update-alternatives --set php-config /usr/bin/php-config${PHP_PACKAGE_VERSION}
RUN update-alternatives --set phpize /usr/bin/phpize${PHP_PACKAGE_VERSION}

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<-'EOF' 
    cp "/usr/lib/$(gcc -dumpmachine)"/libfuzzy.* /usr/lib
    pie install --no-cache \
        rdkafka/rdkafka \
        kjdev/zstd \
        kjdev/brotli \
        awesome/simdjson_plus
    git clone --recursive --depth=1 https://github.com/JakubOnderka/pecl-text-ssdeep.git /tmp/pecl-text-ssdeep
    cd /tmp/pecl-text-ssdeep && phpize && ./configure && make && make install
    tar -czf /pecl_libs.tar.gz \
        /usr/lib/php/${PHP_API_VERSION}/ssdeep.so \
        /usr/lib/php/${PHP_API_VERSION}/rdkafka.so \
        /usr/lib/php/${PHP_API_VERSION}/brotli.so \
        /usr/lib/php/${PHP_API_VERSION}/simdjson_plus.so \
        /usr/lib/php/${PHP_API_VERSION}/zstd.so
EOF

# --- python-build
FROM php-base AS python-build
    ARG CORE_TAG
    ARG CORE_COMMIT

    RUN apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    git \
    make \
    libfuzzy-dev \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # Download MISP using git in the /var/www/ directory. Remove unnecessary items.
    RUN bash <<-'EOF' 
        if [ ! -z "${CORE_COMMIT}" ]; then
            git clone https://github.com/MISP/MISP.git /var/www/MISP && cd /var/www/MISP && git checkout "${CORE_COMMIT}"
        else
            git clone --branch "${CORE_TAG}" --depth 1 https://github.com/MISP/MISP.git /var/www/MISP
        fi
        cd /var/www/MISP || exit; git submodule update --init --recursive .
EOF

ARG PYPI_SETUPTOOLS_VERSION
RUN : "${PYPI_SETUPTOOLS_VERSION:?Build argument PYPI_SETUPTOOLS_VERSION is required and cannot be empty.}"
ARG PYPI_SUPERVISOR_VERSION
RUN : "${PYPI_SUPERVISOR_VERSION:?Build argument PYPI_SUPERVISOR_VERSION is required and cannot be empty.}"
ARG PYPI_JSONSCHEMA_VERSION
ARG PYPI_LIEF_VERSION
ARG PYPI_MISP_STIX_VERSION
ARG PYPI_PLYARA_VERSION
ARG PYPI_PYDEEP2_VERSION
ARG PYPI_PYMISP_VERSION
ARG PYPI_PYTHON_MAGIC_VERSION
ARG PYPI_PYZMQ_VERSION
ARG PYPI_REDIS_VERSION
ARG PYPI_TAXII2_CLIENT_VERSION
RUN bash <<-'EOF'
        mkdir /wheels

        # Add additional dependencies (container specific)
        # The "set" line contains the list of modules we want to ensure are present.
        # PYPI_MODULE_NAME_VERSION env vars can be set to specify the version desired,
        # e.g. PYPI_SURICATA_VERSION="==2.0" to specify exactly version 2.0 for the suricata package
        #
        # 1. Check for presence of each module in requirements.txt
        # 2. If missing, add it (with optional version from env (defaults to empty string))
        # 3. If present, replace with our specified version if it exists, otherwise leave
        #    the upstream version alone.
        set -- "jsonschema" "lief" "misp-stix" "plyara" "pydeep2" "pymisp" "python-magic" "pyzmq" "redis" "taxii2-client" "setuptools" "supervisor"
        for mod in "$@"; do
            mod_version_var=$(echo "PYPI_${mod}_VERSION" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
            mod_version=$(eval "echo \"\$$mod_version_var\"")
            grep -q ${mod} /var/www/MISP/requirements.txt
            exists=$?
            if [ "${exists}" -eq "1" ]; then
                echo "Adding missing module ${mod} with version '${mod_version}'"
                echo ${mod}${mod_version} >> /var/www/MISP/requirements.txt
            else
                if [ "$(echo ${mod_version} | wc -m)" -gt 1 ]; then
                    echo "Overwriting existing module ${mod}, version '${mod_version}'"
                    sed -i "/${mod}/s/.*/${mod}${mod_version}/" /var/www/MISP/requirements.txt
                else
                    echo "Skipping overwriting ${mod} due to missing version variable"
                fi
            fi
        done;

        pip wheel --no-cache-dir -w /wheels/ -r /var/www/MISP/requirements.txt

        # Remove files we do not care for
        find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type f -exec rm {} +
        find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type d -exec rm -r {} +
        find /var/www/MISP/INSTALL/* ! -name 'MYSQL.sql' -type l -exec rm {} +
        # Remove most files in .git - we do not use git functionality in docker
        find /var/www/MISP/.git/* ! -name HEAD -exec rm -rf {} +
        # Remove libraries submodules
        rm -rf /var/www/MISP/PyMISP
        rm -rf /var/www/MISP/app/files/scripts/cti-python-stix2
        rm -rf /var/www/MISP/app/files/scripts/misp-stix
        rm -rf /var/www/MISP/app/files/scripts/mixbox
        rm -rf /var/www/MISP/app/files/scripts/python-cybox
        rm -rf /var/www/MISP/app/files/scripts/python-maec
        rm -rf /var/www/MISP/app/files/scripts/python-stix
        # Remove unneded directories
        rm -rf /var/www/MISP/.forgejo
        rm -rf /var/www/MISP/.github
        rm -rf /var/www/MISP/build
        rm -rf /var/www/MISP/format
        rm -rf /var/www/MISP/debian
        rm -rf /var/www/MISP/docs
        rm -rf /var/www/MISP/tools
        find /var/www/MISP/tests/* ! -name 'modify_config.php' -type f -exec rm {} +
        find /var/www/MISP/tests/* ! -name 'modify_config.php' -type d -exec rm -r {} +
        find /var/www/MISP/tests/* ! -name 'modify_config.php' -type l -exec rm {} +
EOF

# --- final stage
FROM php-base
ARG CORE_TAG
ARG CORE_COMMIT
ARG PHP_PACKAGE_VERSION
ENV PATH="/var/www/MISP/app/Console:${PATH}"
    ENV DEBIAN_FRONTEND=noninteractive
    RUN : "${PHP_PACKAGE_VERSION:?Build argument PHP_PACKAGE_VERSION is required and cannot be empty.}"

    RUN bash <<-'EOF' 
        set -euo pipefail
        apt-get install -y --no-install-recommends \
            gettext \
            procps \
            sudo \
            nginx \
            cron \
            openssl \
            gpg \
            gpg-agent \
            mariadb-client \
            rsync \
            rsyslog \
            logrotate \
            php${PHP_PACKAGE_VERSION} \
            php${PHP_PACKAGE_VERSION}-apcu \
            php${PHP_PACKAGE_VERSION}-curl \
            php${PHP_PACKAGE_VERSION}-xml \
            php${PHP_PACKAGE_VERSION}-intl \
            php${PHP_PACKAGE_VERSION}-bcmath \
            php${PHP_PACKAGE_VERSION}-mbstring \
            php${PHP_PACKAGE_VERSION}-mysql \
            php${PHP_PACKAGE_VERSION}-redis \
            php${PHP_PACKAGE_VERSION}-gd \
            php${PHP_PACKAGE_VERSION}-fpm \
            php${PHP_PACKAGE_VERSION}-zip \
            php${PHP_PACKAGE_VERSION}-ldap \
            libmagic1 \
            libldap-common \
            librdkafka1 \
            libbrotli1 \
            libsimdjson25 \
            libzstd1 \
            ssdeep \
            libfuzzy2 \
            unzip \
            zip \
            curl \
            uuid-runtime \
            jq
        apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EOF

    # Remove some defaults (kernel logging) and fix alternatives
    RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf
RUN update-alternatives --set php /usr/bin/php${PHP_PACKAGE_VERSION}
RUN ln -sf /usr/sbin/php-fpm${PHP_PACKAGE_VERSION} /usr/local/sbin/php-fpm
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install python modules.
#
# The wheels are bind-mounted rather than COPYed. A COPY commits them to their own
# layer, and the `rm -rf /wheels` that used to follow could only write a whiteout on
# top of that layer -- it cannot remove the layer from the image, so the wheels
# shipped in everything we publish. A bind mount is never committed to a layer.
RUN --mount=type=bind,from=python-build,source=/wheels,target=/wheels \
    pip install --no-cache-dir /wheels/*.whl

    # PHP: install prebuilt libraries, then install the app's PHP deps
    COPY --from=php-build /pecl_libs.tar.gz /
    RUN tar -xzf /pecl_libs.tar.gz && rm /pecl_libs.tar.gz

    # Do an early chown to limit image size
    COPY --from=python-build --chown=www-data:www-data --chmod=0550 /var/www/MISP /var/www/MISP
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/composer.lock /var/www/MISP/app/composer.lock
    COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Vendor /var/www/MISP/app/Vendor
# From 2.5.51 there is no /tmp/Plugin
# COPY --from=composer-build --chown=www-data:www-data --chmod=0550 /tmp/Plugin /var/www/MISP/app/Plugin

    # Gather these in one layer, only act on actual directories under /etc/php/
    RUN bash <<-'EOF' 
        set -- "ssdeep" "rdkafka" "brotli" "simdjson_plus" "zstd"
        for mod in "$@"; do
            for dir in /etc/php/*/; do
                echo "extension=${mod}.so" > "${dir}mods-available/${mod}.ini"
            done;
            phpenmod "${mod}"
        done;
        phpenmod redis
EOF

    # nginx
    RUN rm /etc/nginx/sites-enabled/*; mkdir -p /run/php /etc/nginx/certs

    # Make a copy of the file and configuration stores, so we can sync from it

    # The spirit of the upstream dockerization is to make:
    #   1) User and group aligned in terms of permissions
    #   2) Files executable and read only, because of some rogue scripts like 'cake'
    #   3) Directories writable, because sometimes MISP add new files

    RUN bash <<-'EOF' 
        cp -R /var/www/MISP/app/files /var/www/MISP/app/files.dist
        echo "${CORE_COMMIT:-${CORE_TAG}}" > /var/www/MISP/app/files/VERSION
        cp -R /var/www/MISP/app/Config /var/www/MISP/app/Config.dist
        find /var/www/MISP \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data '{}' +;
        find /var/www/MISP -not -perm 550 -type f -exec chmod 0550 '{}' +;
        find /var/www/MISP -not -perm 770 -type d -exec chmod 0770 '{}' +;
        # Diagnostics wants this file to be present and writable even if we do not use git in docker land
        touch /var/www/MISP/.git/ORIG_HEAD && chmod 0600 /var/www/MISP/.git/ORIG_HEAD && chown www-data:www-data /var/www/MISP/.git/ORIG_HEAD
EOF

    # Customisations        
    COPY files/etc/logger/40-misp.conf /etc/rsyslog.d/
    COPY files/etc/logger/misp.logrotate /etc/logrotate.d/misp
    RUN chmod og-w /etc/logrotate.d/misp

    RUN mkdir /var/www/MISP/app/webroot/misp-export
    RUN mkdir /var/www/MISP/misp-custom
    RUN mkdir /var/www/MISP/misp-custom/scripts
    RUN /usr/local/bin/python -m venv /var/www/MISP/misp-custom/venv
    WORKDIR /var/www/MISP/misp-custom/scripts
    RUN /var/www/MISP/misp-custom/venv/bin/pip install asn1crypto attrs azure-keyvault-secrets azure-identity \
                            certifi charset-normalizer colorama Deprecated distlib filelock idna importlib-resources \
                            jmespath jsonschema misp-stix pipenv platformdirs pyasn1 pycparser pymisp pyrsistent python-dateutil \
                            PyYAML requests requests-futures rsa six urllib3 virtualenv virtualenv-clone wrapt \
                            zmq redis pyaml tldextract markdown2 \
                            setuptools feedparser bs4 markdownify flask scraper

    # Installation is complete (custom venv above needs ensurepip, so this runs after it).
    # Keep pip and its vendored dependencies out of the system Python runtime.
    RUN python -m pip uninstall --yes pip && \
        python -c 'import pathlib, shutil, sysconfig; shutil.rmtree(pathlib.Path(sysconfig.get_path("stdlib")) / "ensurepip")'
                            
    RUN mkdir /var/log/supervisor
    # Copy all our image specific files to appropriate locations
    COPY files/ /
    RUN chmod 0755 /etc /etc/logger /etc/misp-docker /etc/nginx /etc/nginx/includes /etc/nginx/sites-available \
                   /etc/supervisor /etc/supervisor/conf.d /var /var/log /var/log/supervisor /var/www /var/www/html
    # Template PHP version into nginx config
    RUN sed -i "s/@PHP_PACKAGE_VERSION@/${PHP_PACKAGE_VERSION}/g" /etc/nginx/includes/misp
# define entrypoint
    ENTRYPOINT [ "/entrypoint.sh" ]

    # Change Workdirectory
    WORKDIR /var/www/MISP
