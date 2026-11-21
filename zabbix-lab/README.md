# zabbix-lab

Monitoring lab: a WordPress site monitored with [Zabbix](https://www.zabbix.com) and visualized in [Grafana](https://grafana.com).

## > Usage

```
./project.sh start      # install WordPress, start and configure Zabbix and Grafana
./project.sh traffic    # request WordPress pages for a few minutes
./project.sh clean
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `zabbix-lab`.

| Service    | URL                   | Credentials         |
| ---------- | --------------------- | ------------------- |
| WordPress  | http://localhost      | `<name>` / `<name>` |
| Grafana    | http://localhost:3000 | `<name>` / `<name>` |
| Zabbix     | http://localhost:8081 | `Admin` / `zabbix`  |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>`   |

Zabbix (`ZABBIX_VERSION` in `project.sh`) stores its data in its own MariaDB 11.8 (`zabbix-db`), as it does not support the newest MariaDB used by WordPress. On the first start `config/zabbix/setup.php` adds the `WordPress` host through the Zabbix API:

* the `Apache by HTTP` template - requests, traffic and workers from Apache's `server-status` page. `config/apache/status.conf` enables it for the Docker networks only.
* the `MySQL by Zabbix agent 2` template - status, queries, connections and more of MariaDB, collected by `zabbix-agent`
* a `WordPress` web scenario - response code and time of the home page and `wp-login.php` every 30 seconds, with the trigger *WordPress is not available*

It also disables the default `Zabbix server` host, which expects an agent on 127.0.0.1. Grafana gets the [Zabbix plugin](https://grafana.com/grafana/plugins/alexanderzobnin-zabbix-app/) and the `WordPress` dashboard, which is also its home dashboard. The configuration is generated in `config/` on the first start and not overwritten afterwards. WordPress itself is installed in `wordpress/`.

## > License

Zabbix is licensed under the [GNU Affero General Public License v3.0](https://www.zabbix.com/license), Grafana and the Zabbix plugin for Grafana under the [GNU Affero General Public License v3.0](https://github.com/grafana/grafana/blob/main/LICENSE) and the [Apache License 2.0](https://github.com/grafana/grafana-zabbix/blob/main/LICENSE) respectively, and WordPress under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/).
