#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
PHP_VERSION=8.4

## Functions

clean() {

    docker compose --profile tools down -v --rmi all --remove-orphans

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
            /README.md/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    apache-exporter:
        image: bitnami/apache-exporter:latest
        command: [ --scrape_uri=http://wordpress/server-status?auto ]
        depends_on:
            - wordpress

    blackbox-exporter:
        image: prom/blackbox-exporter:latest

    database:
        image: mariadb:latest
        volumes:
            - db_data:/var/lib/mysql
        environment:
            MARIADB_ROOT_PASSWORD:  $PROJECT_NAME
            MARIADB_DATABASE:       $PROJECT_NAME
            MARIADB_USER:           $PROJECT_NAME
            MARIADB_PASSWORD:       $PROJECT_NAME
        healthcheck:
            test: [ CMD, healthcheck.sh, --connect, --innodb_initialized ]
            interval: 5s
            timeout: 5s
            retries: 30

    grafana:
        image: grafana/grafana:latest
        volumes:
            - grafana_data:/var/lib/grafana
            - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
            - ./config/grafana/dashboards:/etc/grafana/dashboards:ro
        environment:
            GF_SECURITY_ADMIN_USER:     $PROJECT_NAME
            GF_SECURITY_ADMIN_PASSWORD: $PROJECT_NAME
            GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: /etc/grafana/dashboards/wordpress.json
        ports:
            - 3000:3000
        depends_on:
            - victoriametrics

    myadmin:
        image: phpmyadmin/phpmyadmin
        environment:
            PMA_HOST:               database
            PMA_PORT:               3306
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        ports:
            - 8080:80
        depends_on:
            - database

    mysqld-exporter:
        image: prom/mysqld-exporter:latest
        command: [ --mysqld.address=database:3306, --mysqld.username=root ]
        environment:
            MYSQLD_EXPORTER_PASSWORD:   $PROJECT_NAME
        depends_on:
            database:
                condition: service_healthy

    wordpress:
        image: wordpress:php$PHP_VERSION-apache
        working_dir: /var/www/html
        volumes:
            - ./wordpress:/var/www/html
            - ./config/apache/status.conf:/etc/apache2/conf-enabled/zz-status.conf:ro
        ports:
            - 80:80
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME
        healthcheck:
            ## the entrypoint writes wp-config.php after copying WordPress
            test: [ CMD, test, -f, /var/www/html/wp-config.php ]
            interval: 2s
            timeout: 5s
            retries: 60
        depends_on:
            database:
                condition: service_healthy

    victoriametrics:
        image: victoriametrics/victoria-metrics:latest
        command:
            - -promscrape.config=/etc/victoriametrics/scrape.yml
            - -storageDataPath=/storage
        volumes:
            - vm_data:/storage
            - ./config/victoriametrics/scrape.yml:/etc/victoriametrics/scrape.yml:ro
        ports:
            - 8428:8428

    wpcli:
        image: wordpress:cli-php$PHP_VERSION
        working_dir: /var/www/html
        command: /bin/sh -c ' \
            wp core is-installed --url="http://localhost" || { \
                wp core install \
                --url="http://localhost" \
                --title="$PROJECT_NAME" \
                --admin_user="$PROJECT_NAME" \
                --admin_password="$PROJECT_NAME" \
                --admin_email=foo@bar.com \
                --skip-email \
                && wp post generate --count=20; }; '
        volumes_from:
            - wordpress
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME
        depends_on:
            wordpress:
                condition: service_healthy
        profiles: [ tools ]

volumes:
    db_data:
    grafana_data:
    vm_data:
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

configapache() {

    mkdir -p config/apache

    if [[ ! -f config/apache/status.conf ]]; then
        cat << 'EOF' > config/apache/status.conf
## mod_status for the exporter, reachable from the Docker networks only
ExtendedStatus On

<Location "/server-status">
    SetHandler server-status
    ## keep the WordPress rewrite rules in .htaccess from taking over
    RewriteEngine Off
    Require ip 127.0.0.1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
</Location>
EOF
    fi

}

configgrafana() {

    mkdir -p config/grafana/{dashboards,provisioning/{dashboards,datasources}}

    if [[ ! -f config/grafana/provisioning/datasources/datasources.yml ]]; then
        cat << 'EOF' > config/grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
    ## VictoriaMetrics answers the Prometheus query API
    - name: VictoriaMetrics
      type: prometheus
      uid: metrics
      access: proxy
      url: http://victoriametrics:8428
      isDefault: true
EOF
    fi

    if [[ ! -f config/grafana/provisioning/dashboards/dashboards.yml ]]; then
        cat << 'EOF' > config/grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1

providers:
    - name: wordpress
      type: file
      options:
          path: /etc/grafana/dashboards
EOF
    fi

    if [[ ! -f config/grafana/dashboards/wordpress.json ]]; then
        cat << 'EOF' > config/grafana/dashboards/wordpress.json
{
    "uid": "wordpress",
    "title": "WordPress",
    "tags": [ "wordpress" ],
    "timezone": "browser",
    "refresh": "10s",
    "time": { "from": "now-30m", "to": "now" },
    "schemaVersion": 39,
    "panels": [
        {
            "id": 1, "type": "stat", "title": "WordPress up",
            "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": {
                "mappings": [ { "type": "value", "options": {
                    "0": { "text": "DOWN", "color": "red" },
                    "1": { "text": "UP", "color": "green" } } } ],
                "color": { "mode": "thresholds" },
                "thresholds": { "mode": "absolute", "steps": [
                    { "color": "red", "value": null }, { "color": "green", "value": 1 } ] } } },
            "targets": [ { "refId": "A", "expr": "min(probe_success{job=\"blackbox\"})" } ]
        },
        {
            "id": 2, "type": "stat", "title": "HTTP status (home page)",
            "gridPos": { "x": 6, "y": 0, "w": 6, "h": 4 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "targets": [ { "refId": "A", "expr": "probe_http_status_code{instance=\"http://wordpress/\"}" } ]
        },
        {
            "id": 3, "type": "stat", "title": "Apache up",
            "gridPos": { "x": 12, "y": 0, "w": 6, "h": 4 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": {
                "mappings": [ { "type": "value", "options": {
                    "0": { "text": "DOWN", "color": "red" },
                    "1": { "text": "UP", "color": "green" } } } ] } },
            "targets": [ { "refId": "A", "expr": "apache_up" } ]
        },
        {
            "id": 4, "type": "stat", "title": "MariaDB up",
            "gridPos": { "x": 18, "y": 0, "w": 6, "h": 4 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": {
                "mappings": [ { "type": "value", "options": {
                    "0": { "text": "DOWN", "color": "red" },
                    "1": { "text": "UP", "color": "green" } } } ] } },
            "targets": [ { "refId": "A", "expr": "mysql_up" } ]
        },
        {
            "id": 5, "type": "timeseries", "title": "Response time",
            "gridPos": { "x": 0, "y": 4, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": { "unit": "s" } },
            "targets": [ { "refId": "A", "expr": "probe_duration_seconds{job=\"blackbox\"}", "legendFormat": "{{instance}}" } ]
        },
        {
            "id": 6, "type": "timeseries", "title": "Apache requests",
            "gridPos": { "x": 12, "y": 4, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": { "unit": "reqps" } },
            "targets": [ { "refId": "A", "expr": "rate(apache_accesses_total[1m])", "legendFormat": "requests" } ]
        },
        {
            "id": 7, "type": "timeseries", "title": "Apache workers",
            "gridPos": { "x": 0, "y": 12, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "targets": [ { "refId": "A", "expr": "apache_workers", "legendFormat": "{{state}}" } ]
        },
        {
            "id": 8, "type": "timeseries", "title": "MariaDB queries",
            "gridPos": { "x": 12, "y": 12, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": { "unit": "qps" } },
            "targets": [ { "refId": "A", "expr": "rate(mysql_global_status_queries[1m])", "legendFormat": "queries" } ]
        },
        {
            "id": 9, "type": "timeseries", "title": "MariaDB connections",
            "gridPos": { "x": 0, "y": 20, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "targets": [ { "refId": "A", "expr": "mysql_global_status_threads_connected", "legendFormat": "connected" } ]
        },
        {
            "id": 10, "type": "timeseries", "title": "Apache traffic",
            "gridPos": { "x": 12, "y": 20, "w": 12, "h": 8 },
            "datasource": { "type": "prometheus", "uid": "metrics" },
            "fieldConfig": { "defaults": { "unit": "KBs" } },
            "targets": [ { "refId": "A", "expr": "rate(apache_sent_kilobytes_total[1m])", "legendFormat": "sent" } ]
        }
    ]
}
EOF
    fi

}

configvictoriametrics() {

    mkdir -p config/victoriametrics

    if [[ ! -f config/victoriametrics/scrape.yml ]]; then
        cat << 'EOF' > config/victoriametrics/scrape.yml
global:
    scrape_interval: 15s

scrape_configs:
    - job_name: victoriametrics
      static_configs:
          - targets: [ "localhost:8428" ]

    - job_name: apache
      static_configs:
          - targets: [ "apache-exporter:9117" ]

    - job_name: mysql
      static_configs:
          - targets: [ "mysqld-exporter:9104" ]

    - job_name: blackbox
      metrics_path: /probe
      params:
          module: [ http_2xx ]
      static_configs:
          - targets:
                - http://wordpress/
                - http://wordpress/wp-login.php
      relabel_configs:
          - source_labels: [ __address__ ]
            target_label: __param_target
          - source_labels: [ __param_target ]
            target_label: instance
          - target_label: __address__
            replacement: blackbox-exporter:9115
EOF
    fi

}

gitignore() {

    if [[ ! -f .gitignore ]]; then
        cat << EOF > .gitignore
## Docker related

/docker-compose.yml

## WordPress related

/wordpress
EOF
    fi

}

traffic() {

    ## requests WordPress pages for a few minutes, to have something to look at
    docker compose run --rm --no-deps --entrypoint /bin/sh wpcli -c ' \
        for i in $(seq 600); do \
            wget -q -O /dev/null http://wordpress/; \
            wget -q -O /dev/null "http://wordpress/?p=$((i % 20 + 1))"; \
            wget -q -O /dev/null "http://wordpress/?s=hello"; \
            sleep 0.2; \
        done'

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    gitignore
    configapache
    configgrafana
    configvictoriametrics

    mkdir -p wordpress

    ## waits until the database is ready and WordPress is copied
    docker compose up -d && \
    docker compose run --rm wpcli && \
    echo "WordPress: http://localhost  Grafana: http://localhost:3000  VictoriaMetrics: http://localhost:8428/vmui  phpMyAdmin: http://localhost:8080"

}

"$1"
