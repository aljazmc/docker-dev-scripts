#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
PHP_VERSION=8.4
ZABBIX_VERSION=8.0

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
            GF_PLUGINS_PREINSTALL_SYNC: alexanderzobnin-zabbix-app
        ports:
            - 3000:3000
        depends_on:
            - zabbix-web

    myadmin:
        image: phpmyadmin/phpmyadmin
        environment:
            PMA_HOSTS:              database,zabbix-db
            PMA_PORT:               3306
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        ports:
            - 8080:80
        depends_on:
            - database
            - zabbix-db

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

    zabbix-agent:
        image: zabbix/zabbix-agent2:alpine-$ZABBIX_VERSION-latest
        environment:
            ZBX_HOSTNAME:           WordPress
            ZBX_SERVER_HOST:        zabbix-server

    zabbix-db:
        image: mariadb:11.8
        command: [ --character-set-server=utf8mb4, --collation-server=utf8mb4_bin ]
        volumes:
            - zabbix_db_data:/var/lib/mysql
        environment:
            MARIADB_ROOT_PASSWORD:  $PROJECT_NAME
            MARIADB_DATABASE:       zabbix
            MARIADB_USER:           zabbix
            MARIADB_PASSWORD:       $PROJECT_NAME
        healthcheck:
            test: [ CMD, healthcheck.sh, --connect, --innodb_initialized ]
            interval: 5s
            timeout: 5s
            retries: 30

    zabbix-server:
        image: zabbix/zabbix-server-mysql:alpine-$ZABBIX_VERSION-latest
        environment:
            DB_SERVER_HOST:         zabbix-db
            MYSQL_DATABASE:         zabbix
            MYSQL_USER:             zabbix
            MYSQL_PASSWORD:         $PROJECT_NAME
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        depends_on:
            zabbix-db:
                condition: service_healthy

    zabbix-setup:
        image: php:$PHP_VERSION-cli-alpine
        command: [ php, /setup/setup.php ]
        volumes:
            - ./config/zabbix:/setup:ro
        environment:
            ZABBIX_API:             http://zabbix-web:8080/api_jsonrpc.php
            MYSQL_PASSWORD:         $PROJECT_NAME
        depends_on:
            - zabbix-web
        profiles: [ tools ]

    zabbix-web:
        image: zabbix/zabbix-web-nginx-mysql:alpine-$ZABBIX_VERSION-latest
        environment:
            ZBX_SERVER_HOST:        zabbix-server
            DB_SERVER_HOST:         zabbix-db
            MYSQL_DATABASE:         zabbix
            MYSQL_USER:             zabbix
            MYSQL_PASSWORD:         $PROJECT_NAME
            PHP_TZ:                 UTC
        ports:
            - 8081:8080
        depends_on:
            zabbix-db:
                condition: service_healthy
            zabbix-server:
                condition: service_started

volumes:
    db_data:
    grafana_data:
    zabbix_db_data:
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

    mkdir -p config/grafana/{dashboards,provisioning/{dashboards,datasources,plugins}}

    if [[ ! -f config/grafana/provisioning/datasources/datasources.yml ]]; then
        cat << 'EOF' > config/grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
    - name: Zabbix
      type: alexanderzobnin-zabbix-datasource
      uid: zabbix
      access: proxy
      url: http://zabbix-web:8080/api_jsonrpc.php
      isDefault: true
      jsonData:
          authType: userLogin
          username: Admin
          trends: true
      secureJsonData:
          password: zabbix
EOF
    fi

    if [[ ! -f config/grafana/provisioning/plugins/zabbix.yml ]]; then
        cat << 'EOF' > config/grafana/provisioning/plugins/zabbix.yml
apiVersion: 1

apps:
    - type: alexanderzobnin-zabbix-app
      disabled: false
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
    "tags": [
        "wordpress"
    ],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
        "from": "now-30m",
        "to": "now"
    },
    "schemaVersion": 39,
    "panels": [
        {
            "id": 1,
            "type": "stat",
            "title": "WordPress up",
            "gridPos": {
                "x": 0,
                "y": 0,
                "w": 6,
                "h": 4
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "/^Failed step of scenario/"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "mappings": [
                        {
                            "type": "value",
                            "options": {
                                "0": {
                                    "text": "UP",
                                    "color": "green"
                                }
                            }
                        },
                        {
                            "type": "range",
                            "options": {
                                "from": 1,
                                "to": 100,
                                "result": {
                                    "text": "DOWN",
                                    "color": "red"
                                }
                            }
                        }
                    ]
                },
                "overrides": []
            }
        },
        {
            "id": 2,
            "type": "stat",
            "title": "HTTP status (home page)",
            "gridPos": {
                "x": 6,
                "y": 0,
                "w": 6,
                "h": 4
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "/^Response code for step .Home./"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ]
        },
        {
            "id": 3,
            "type": "stat",
            "title": "Apache up",
            "gridPos": {
                "x": 12,
                "y": 0,
                "w": 6,
                "h": 4
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Service ping"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "mappings": [
                        {
                            "type": "value",
                            "options": {
                                "0": {
                                    "text": "DOWN",
                                    "color": "red"
                                },
                                "1": {
                                    "text": "UP",
                                    "color": "green"
                                }
                            }
                        }
                    ]
                },
                "overrides": []
            }
        },
        {
            "id": 4,
            "type": "stat",
            "title": "MariaDB up",
            "gridPos": {
                "x": 18,
                "y": 0,
                "w": 6,
                "h": 4
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Status"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "mappings": [
                        {
                            "type": "value",
                            "options": {
                                "0": {
                                    "text": "DOWN",
                                    "color": "red"
                                },
                                "1": {
                                    "text": "UP",
                                    "color": "green"
                                }
                            }
                        }
                    ]
                },
                "overrides": []
            }
        },
        {
            "id": 5,
            "type": "timeseries",
            "title": "Response time",
            "gridPos": {
                "x": 0,
                "y": 4,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "/^Response time for step/"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "unit": "s"
                },
                "overrides": []
            }
        },
        {
            "id": 6,
            "type": "timeseries",
            "title": "Apache requests",
            "gridPos": {
                "x": 12,
                "y": 4,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Requests per second"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "unit": "reqps"
                },
                "overrides": []
            }
        },
        {
            "id": 7,
            "type": "timeseries",
            "title": "Apache workers",
            "gridPos": {
                "x": 0,
                "y": 12,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "/^Total workers (busy|idle)$/"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ]
        },
        {
            "id": 8,
            "type": "timeseries",
            "title": "MariaDB queries",
            "gridPos": {
                "x": 12,
                "y": 12,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Queries per second"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "unit": "qps"
                },
                "overrides": []
            }
        },
        {
            "id": 9,
            "type": "timeseries",
            "title": "MariaDB connections",
            "gridPos": {
                "x": 0,
                "y": 20,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Threads connected"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ]
        },
        {
            "id": 10,
            "type": "timeseries",
            "title": "Apache traffic",
            "gridPos": {
                "x": 12,
                "y": 20,
                "w": 12,
                "h": 8
            },
            "datasource": {
                "type": "alexanderzobnin-zabbix-datasource",
                "uid": "zabbix"
            },
            "targets": [
                {
                    "refId": "A",
                    "datasource": {
                        "type": "alexanderzobnin-zabbix-datasource",
                        "uid": "zabbix"
                    },
                    "queryType": "0",
                    "group": {
                        "filter": "WordPress"
                    },
                    "host": {
                        "filter": "WordPress"
                    },
                    "itemTag": {
                        "filter": ""
                    },
                    "item": {
                        "filter": "Bytes per second"
                    },
                    "functions": [],
                    "options": {
                        "showDisabledItems": false,
                        "skipEmptyValues": false,
                        "disableDataAlignment": false,
                        "useTrends": "default"
                    }
                }
            ],
            "fieldConfig": {
                "defaults": {
                    "unit": "Bps"
                },
                "overrides": []
            }
        }
    ]
}
EOF
    fi

}

configzabbix() {

    mkdir -p config/zabbix

    if [[ ! -f config/zabbix/setup.php ]]; then
        cat << 'EOF' > config/zabbix/setup.php
<?php

/*
 * Adds WordPress to Zabbix through its API: a host with the Apache and
 * MariaDB templates, a web scenario for the site and a trigger for it.
 * Runs once; does nothing if the host already exists.
 */

declare(strict_types=1);

const HOST = 'WordPress';

function api(string $method, array $params, ?string $token = null): mixed
{
    $headers = "Content-Type: application/json-rpc\r\n";
    if ($token !== null) {
        $headers .= "Authorization: Bearer {$token}\r\n";
    }
    $context = stream_context_create(['http' => [
        'method' => 'POST',
        'header' => $headers,
        'content' => json_encode(['jsonrpc' => '2.0', 'method' => $method, 'params' => $params, 'id' => 1]),
        'ignore_errors' => true,
        'timeout' => 30,
    ]]);
    $body = @file_get_contents((string) getenv('ZABBIX_API'), false, $context);
    $response = is_string($body) ? json_decode($body, true) : null;
    if (!is_array($response)) {
        throw new RuntimeException("{$method}: no valid response");
    }
    if (isset($response['error'])) {
        throw new RuntimeException("{$method}: {$response['error']['message']} {$response['error']['data']}");
    }

    return $response['result'];
}

## the frontend answers once the server has created the database schema
echo "Waiting for the Zabbix API.\n";
for ($attempt = 1;; $attempt++) {
    try {
        $token = api('user.login', ['username' => 'Admin', 'password' => 'zabbix']);
        break;
    } catch (RuntimeException $e) {
        if ($attempt === 150) {
            fwrite(STDERR, $e->getMessage() . "\n");
            exit(1);
        }
        sleep(2);
    }
}

## the default host expects an agent on 127.0.0.1, which the containers do not have
foreach (api('host.get', ['output' => ['hostid'], 'filter' => ['host' => ['Zabbix server'], 'status' => 0]], $token) as $server) {
    api('host.update', ['hostid' => $server['hostid'], 'status' => 1], $token);
}

if (api('host.get', ['filter' => ['host' => [HOST]]], $token) !== []) {
    echo 'Zabbix already monitors ' . HOST . ".\n";
    exit(0);
}

$groups = api('hostgroup.get', ['filter' => ['name' => [HOST]]], $token);
$groupId = $groups !== []
    ? $groups[0]['groupid']
    : api('hostgroup.create', ['name' => HOST], $token)['groupids'][0];

$templateNames = ['Apache by HTTP', 'MySQL by Zabbix agent 2'];
$templates = api('template.get', ['output' => ['templateid'], 'filter' => ['host' => $templateNames]], $token);
if (count($templates) !== count($templateNames)) {
    fwrite(STDERR, 'Templates not found: ' . implode(', ', $templateNames) . "\n");
    exit(1);
}

$hostId = api('host.create', [
    'host' => HOST,
    'groups' => [['groupid' => $groupId]],
    'templates' => array_map(fn (array $t): array => ['templateid' => $t['templateid']], $templates),
    ## agent 2 runs the MariaDB checks, the server queries Apache directly
    'interfaces' => [['type' => 1, 'main' => 1, 'useip' => 0, 'ip' => '', 'dns' => 'zabbix-agent', 'port' => '10050']],
    'macros' => [
        ['macro' => '{$APACHE.STATUS.HOST}', 'value' => 'wordpress'],
        ['macro' => '{$MYSQL.DSN}', 'value' => 'tcp://database:3306'],
        ['macro' => '{$MYSQL.USER}', 'value' => 'root'],
        ['macro' => '{$MYSQL.PASSWORD}', 'value' => (string) getenv('MYSQL_PASSWORD'), 'type' => 1],
    ],
], $token)['hostids'][0];

api('httptest.create', [
    'name' => HOST,
    'hostid' => $hostId,
    'delay' => '30s',
    'steps' => [
        ['no' => 1, 'name' => 'Home', 'url' => 'http://wordpress/', 'status_codes' => '200'],
        ['no' => 2, 'name' => 'Login', 'url' => 'http://wordpress/wp-login.php', 'status_codes' => '200'],
    ],
], $token);

api('trigger.create', [
    'description' => 'WordPress is not available',
    'expression' => 'last(/' . HOST . '/web.test.fail[' . HOST . '])<>0',
    'priority' => 4,
], $token);

echo 'Zabbix now monitors ' . HOST . ".\n";
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
    configzabbix

    mkdir -p wordpress

    ## waits until the database is ready and WordPress is copied
    docker compose up -d && \
    docker compose run --rm wpcli && \
    docker compose run --rm zabbix-setup && \
    echo "WordPress: http://localhost  Grafana: http://localhost:3000  Zabbix: http://localhost:8081  phpMyAdmin: http://localhost:8080"

}

"$1"
