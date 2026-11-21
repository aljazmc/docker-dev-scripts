# zabbix-lab

Monitoring lab: a WordPress site monitored with [Zabbix](https://www.zabbix.com) and visualized in [Grafana](https://grafana.com).

## > Usage

```
./project.sh start      # install WordPress, start the monitoring and Grafana
./project.sh traffic    # request WordPress pages for a few minutes, to have something to look at
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `zabbix-lab`.

| Service    | URL                   | Credentials         |
| ---------- | --------------------- | ------------------- |
| WordPress  | http://localhost      | `<name>` / `<name>` |
| Grafana    | http://localhost:3000 | `<name>` / `<name>` |
| Zabbix     | http://localhost:8081 | `Admin` / `zabbix`  |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>`   |

`./project.sh start` generates `docker-compose.yml` and the configuration in `config/`, starts the services, installs WordPress in `wordpress/` and adds 20 sample posts. The services wait for the database's health check, so no fixed delays are needed.

Zabbix (`ZABBIX_VERSION` in `project.sh`) stores its data in its own MariaDB 11.8 (`zabbix-db`), as it does not support the newest MariaDB that WordPress uses. Once its API answers, `config/zabbix/setup.php` adds the `WordPress` host:

* the `Apache by HTTP` template - requests, traffic and workers from Apache's `server-status` page
* the `MySQL by Zabbix agent 2` template - status, queries, connections and more of MariaDB, collected by `zabbix-agent`
* the `WordPress` web scenario - response code and time of the home page and `wp-login.php` every 30 seconds, with the trigger *WordPress is not available*

It also disables the default `Zabbix server` host, which expects an agent on 127.0.0.1. `config/apache/status.conf` enables Apache's `server-status` page for the Docker networks only. As Docker forwards published ports through its network, it is reachable from the host too.

Grafana gets the data source and the `WordPress` dashboard, which is also its home dashboard, from `config/grafana/`. Grafana uses the [Zabbix plugin](https://grafana.com/grafana/plugins/alexanderzobnin-zabbix-app/). The files are generated on the first start and not overwritten afterwards, so you can change them.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you. The ports are the same in all labs, so run one lab at a time.

## > License

Zabbix is licensed under the [GNU Affero General Public License v3.0](https://www.zabbix.com/license), Grafana under the [GNU Affero General Public License v3.0](https://github.com/grafana/grafana/blob/main/LICENSE) and the Zabbix plugin for Grafana under the [Apache License 2.0](https://github.com/grafana/grafana-zabbix/blob/main/LICENSE). WordPress is licensed under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/).
