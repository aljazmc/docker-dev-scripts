# prometheus-lab

Monitoring lab: a WordPress site monitored with [Prometheus](https://prometheus.io) and visualized in [Grafana](https://grafana.com).

## > Usage

```
./project.sh start      # install WordPress, start monitoring and Grafana
./project.sh traffic    # request WordPress pages for a few minutes
./project.sh clean
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `prometheus-lab`.

| Service    | URL                   | Credentials         |
| ---------- | --------------------- | ------------------- |
| WordPress  | http://localhost      | `<name>` / `<name>` |
| Grafana    | http://localhost:3000 | `<name>` / `<name>` |
| Prometheus | http://localhost:9090 |                     |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>`   |

What is monitored:

* `blackbox-exporter` - availability, HTTP status and response time of the home page and `wp-login.php`
* `apache-exporter` - requests, traffic and workers from Apache's `server-status` page. `config/apache/status.conf` enables it for the Docker networks only.
* `mysqld-exporter` - status, queries and connections of MariaDB

The configuration is generated in `config/` on the first start and not overwritten afterwards: `config/prometheus/prometheus.yml` for the scrape targets, `config/grafana/` for the data source and the `WordPress` dashboard, which is also Grafana's home dashboard. WordPress itself is installed in `wordpress/`.

## > License

Prometheus and its exporters are licensed under the [Apache License 2.0](https://github.com/prometheus/prometheus/blob/main/LICENSE), Grafana under the [GNU Affero General Public License v3.0](https://github.com/grafana/grafana/blob/main/LICENSE) and WordPress under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/).
