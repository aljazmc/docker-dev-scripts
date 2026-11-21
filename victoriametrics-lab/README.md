# victoriametrics-lab

Monitoring lab: a WordPress site monitored with [VictoriaMetrics](https://victoriametrics.com) and visualized in [Grafana](https://grafana.com).

## > Usage

```
./project.sh start      # install WordPress, start the monitoring and Grafana
./project.sh traffic    # request WordPress pages for a few minutes, to have something to look at
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `victoriametrics-lab`.

| Service         | URL                        | Credentials         |
| --------------- | -------------------------- | ------------------- |
| WordPress       | http://localhost           | `<name>` / `<name>` |
| Grafana         | http://localhost:3000      | `<name>` / `<name>` |
| VictoriaMetrics | http://localhost:8428/vmui |                     |
| phpMyAdmin      | http://localhost:8080      | `root` / `<name>`   |

`./project.sh start` generates `docker-compose.yml` and the configuration in `config/`, starts the services, installs WordPress in `wordpress/` and adds 20 sample posts. The services wait for the database's health check, so no fixed delays are needed.

The single-node VictoriaMetrics scrapes the same exporters as `prometheus-lab` every 15 seconds:

* `blackbox-exporter` - availability, HTTP status and response time of the home page and `wp-login.php`
* `apache-exporter` - requests, traffic and workers from Apache's `server-status` page
* `mysqld-exporter` - status, queries and connections of MariaDB

`config/apache/status.conf` enables Apache's `server-status` page for the Docker networks only. As Docker forwards published ports through its network, it is reachable from the host too. Grafana queries VictoriaMetrics through its Prometheus-compatible API, so the dashboard is the same as in `prometheus-lab`.

Grafana gets the data source and the `WordPress` dashboard, which is also its home dashboard, from `config/grafana/`. `config/victoriametrics/scrape.yml` holds the scrape targets, in the Prometheus format. The files are generated on the first start and not overwritten afterwards, so you can change them.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you. The ports are the same in all labs, so run one lab at a time.

## > License

VictoriaMetrics and the Prometheus exporters are licensed under the [Apache License 2.0](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/master/LICENSE), Grafana under the [GNU Affero General Public License v3.0](https://github.com/grafana/grafana/blob/main/LICENSE). WordPress is licensed under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/).
