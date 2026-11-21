# victoriametrics-lab

Monitoring lab: a WordPress site monitored with [VictoriaMetrics](https://victoriametrics.com) and visualized in [Grafana](https://grafana.com).

## > Usage

```
./project.sh start      # install WordPress, start monitoring and Grafana
./project.sh traffic    # request WordPress pages for a few minutes
./project.sh clean
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `victoriametrics-lab`.

| Service         | URL                        | Credentials         |
| --------------- | -------------------------- | ------------------- |
| WordPress       | http://localhost           | `<name>` / `<name>` |
| Grafana         | http://localhost:3000      | `<name>` / `<name>` |
| VictoriaMetrics | http://localhost:8428/vmui |                     |
| phpMyAdmin      | http://localhost:8080      | `root` / `<name>`   |

The single-node VictoriaMetrics scrapes the same exporters as `prometheus-lab`, with a Prometheus-compatible scrape configuration:

* `blackbox-exporter` - availability, HTTP status and response time of the home page and `wp-login.php`
* `apache-exporter` - requests, traffic and workers from Apache's `server-status` page. `config/apache/status.conf` enables it for the Docker networks only.
* `mysqld-exporter` - status, queries and connections of MariaDB

Grafana queries VictoriaMetrics through its Prometheus-compatible API, so the `WordPress` dashboard is the same as in `prometheus-lab`. The configuration is generated in `config/` on the first start and not overwritten afterwards: `config/victoriametrics/scrape.yml` for the scrape targets, `config/grafana/` for the data source and the dashboard, which is also Grafana's home dashboard. WordPress itself is installed in `wordpress/`.

## > License

VictoriaMetrics and the Prometheus exporters are licensed under the [Apache License 2.0](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/master/LICENSE), Grafana under the [GNU Affero General Public License v3.0](https://github.com/grafana/grafana/blob/main/LICENSE) and WordPress under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/).
