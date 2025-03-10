#!/usr/bin/bash

# Set correct permissions in misp-custom
MISP_CUSTOM_DIR="/var/www/MISP/misp-custom"
chown -R www-data:www-data "$MISP_CUSTOM_DIR"

# Set correct permissions for cron
chown root:root /etc/cron.d/misp


sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.attachments_dir" "/var/www/MISP/app/files"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Action_services_url" "http://misp-modules"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_url" "http://misp-modules"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_url" "http://misp-modules"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_url" "http://misp-modules"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" "/usr/local/bin/python3"

sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_host" "redis"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_password" "redispassword"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_port" "6379"

sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.contact" "info@botvrij.eu"
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.email" "info@botvrij.eu"

sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Security.syslog" true
sudo -H -E -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Security.syslog_ident" "mispsyslog"

sudo -H -E -u www-data sh -c 'cp /custom/files/edge.css /var/www/MISP/app/webroot/css/edge.css'