# Prometheus Metrics Exporter

This packet forwarder includes an optional Prometheus metrics HTTP endpoint that exports real-time metrics for monitoring with Prometheus, Zabbix, or other compatible monitoring systems.

## Configuration

Add the following fields to the `gateway_conf` section of your `global_conf.json`:

```json
{
    "gateway_conf": {
        ...
        "prometheus_enabled": true,
        "prometheus_listen_addr": "0.0.0.0",
        "prometheus_port": 9100
    }
}
```

### Configuration Parameters

- **`prometheus_enabled`** (boolean, optional, default: `false`)
  - Enable or disable the Prometheus metrics HTTP endpoint

- **`prometheus_listen_addr`** (string, optional, default: `"0.0.0.0"`)
  - IP address to bind the HTTP server to
  - Use `"127.0.0.1"` for localhost-only access
  - Use `"0.0.0.0"` to listen on all interfaces

- **`prometheus_port`** (integer, optional, default: `9100`)
  - TCP port for the HTTP metrics endpoint
  - Standard Prometheus exporter port is 9100

## Accessing Metrics

Once enabled, metrics are available at:

```
http://<gateway-ip>:9100/metrics
```

Example:
```bash
curl http://localhost:9100/metrics
```

### Docker/Podman Usage

When running in a container, expose the Prometheus port:

```bash
# Docker
docker run -p 9100:9100 your-image:tag

# Podman
podman run -p 9100:9100 your-image:tag
```

Access metrics from the host:
```bash
curl http://localhost:9100/metrics
```

## Available Metrics

### Upstream (Receive) Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `lora_packets_received_total{status="all"}` | counter | Total packets received by concentrator |
| `lora_packets_received_total{status="ok"}` | counter | Packets received with valid CRC |
| `lora_packets_received_total{status="crc_bad"}` | counter | Packets received with CRC error |
| `lora_packets_received_total{status="no_crc"}` | counter | Packets received without CRC |
| `lora_packets_forwarded_total` | counter | Packets forwarded to network server |
| `lora_upstream_bytes_total{type="network"}` | counter | Total upstream UDP bytes |
| `lora_upstream_bytes_total{type="payload"}` | counter | Total upstream payload bytes |
| `lora_upstream_datagrams_total{type="sent"}` | counter | Upstream datagrams sent |
| `lora_upstream_datagrams_total{type="ack"}` | counter | Upstream datagrams acknowledged |

### Downstream (Transmit) Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `lora_downstream_pull_requests_total{type="sent"}` | counter | PULL_DATA requests sent |
| `lora_downstream_pull_requests_total{type="ack"}` | counter | PULL_DATA acknowledgments received |
| `lora_downstream_datagrams_received_total` | counter | Downstream datagrams received |
| `lora_downstream_bytes_total{type="network"}` | counter | Total downstream UDP bytes |
| `lora_downstream_bytes_total{type="payload"}` | counter | Total downstream payload bytes |
| `lora_transmit_total{status="ok"}` | counter | Successful transmissions |
| `lora_transmit_total{status="fail"}` | counter | Failed transmissions |
| `lora_transmit_total{status="requested"}` | counter | Transmission requests from server |
| `lora_transmit_rejected_total{reason="collision_packet"}` | counter | TX rejected due to packet collision |
| `lora_transmit_rejected_total{reason="collision_beacon"}` | counter | TX rejected due to beacon collision |
| `lora_transmit_rejected_total{reason="too_late"}` | counter | TX rejected - timestamp too late |
| `lora_transmit_rejected_total{reason="too_early"}` | counter | TX rejected - timestamp too early |

### Beacon Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `lora_beacon_total{status="queued"}` | counter | Beacons queued for transmission |
| `lora_beacon_total{status="sent"}` | counter | Beacons successfully transmitted |
| `lora_beacon_total{status="rejected"}` | counter | Beacons rejected |

### Hardware Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `lora_concentrator_temperature_celsius` | gauge | SX1302 concentrator temperature in Celsius |
| `lora_sx1302_counter_inst` | counter | SX1302 internal timestamp counter (microseconds) |
| `lora_sx1302_counter_pps` | counter | SX1302 PPS/trigger counter (microseconds) |

### GPS Metrics (when GPS is available)

| Metric Name | Type | Description |
|-------------|------|-------------|
| `lora_gps_latitude` | gauge | GPS latitude in degrees |
| `lora_gps_longitude` | gauge | GPS longitude in degrees |
| `lora_gps_altitude_meters` | gauge | GPS altitude in meters |

## Prometheus Configuration

Add a scrape job to your Prometheus `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'lora-gateway'
    static_configs:
      - targets: ['<gateway-ip>:9100']
        labels:
          gateway_id: 'gateway-001'
```

## Zabbix Configuration

### Using Zabbix Agent 2 (HTTP Agent)

Create a Zabbix template with HTTP agent items:

1. **Item Prototype Example:**
   - Type: HTTP agent
   - URL: `http://<gateway-ip>:9100/metrics`
   - Type of information: Numeric (unsigned)
   - Preprocessing:
     - Prometheus pattern: `lora_packets_received_total{status="ok"}`

### Using Prometheus Data Source

Alternatively, configure Zabbix to use Prometheus as a data source and import metrics directly.

## Security Considerations

### Network Security

1. **Firewall Rules:**
   ```bash
   # Allow access only from monitoring server
   iptables -A INPUT -p tcp --dport 9100 -s <zabbix-ip> -j ACCEPT
   iptables -A INPUT -p tcp --dport 9100 -j DROP
   ```

2. **Localhost-only access:**
   Set `"prometheus_listen_addr": "127.0.0.1"` and use SSH tunneling:
   ```bash
   ssh -L 9100:localhost:9100 user@gateway-ip
   ```

### Performance Impact

The Prometheus exporter is designed to have minimal impact on packet forwarding:

- Separate thread with independent event loop
- Mutex-protected snapshot reads (< 1ms lock time)
- Connection limit: 10 concurrent connections
- Connection timeout: 30 seconds
- No blocking operations in packet processing threads

## Troubleshooting

### Metrics endpoint not accessible

1. Check if Prometheus thread started:
   ```
   INFO: [prometheus] HTTP server started on 0.0.0.0:9100
   ```

2. Verify port is listening:
   ```bash
   netstat -tuln | grep 9100
   ```

3. Check firewall rules:
   ```bash
   iptables -L -n | grep 9100
   ```

### Thread creation failed

If you see:
```
WARNING: [main] impossible to create prometheus thread, metrics disabled
```

The packet forwarder will continue operating normally without metrics. Check:
- System resource limits: `ulimit -a`
- Available memory
- libmicrohttpd installation: `ldconfig -p | grep microhttpd`

## Dependencies

- **libmicrohttpd** - Embedded HTTP server library
  - Debian/Ubuntu: `apt-get install libmicrohttpd-dev`
  - RHEL/CentOS: `yum install libmicrohttpd-devel`
  - Arch Linux: `pacman -S libmicrohttpd`
  - **Docker/Podman:** Already included in the Docker image (automatically installed)

## Example Output

```
# HELP lora_packets_received_total Total number of packets received by the concentrator
# TYPE lora_packets_received_total counter
lora_packets_received_total{status="all"} 1250
lora_packets_received_total{status="ok"} 1243
lora_packets_received_total{status="crc_bad"} 5
lora_packets_received_total{status="no_crc"} 2
# HELP lora_packets_forwarded_total Total number of packets forwarded to the server
# TYPE lora_packets_forwarded_total counter
lora_packets_forwarded_total 1243
# HELP lora_concentrator_temperature_celsius Concentrator temperature in Celsius
# TYPE lora_concentrator_temperature_celsius gauge
lora_concentrator_temperature_celsius 42.3
# HELP lora_sx1302_counter_inst SX1302 internal timestamp counter (microseconds)
# TYPE lora_sx1302_counter_inst counter
lora_sx1302_counter_inst 90885035
# HELP lora_sx1302_counter_pps SX1302 PPS/trigger counter (microseconds)
# TYPE lora_sx1302_counter_pps counter
lora_sx1302_counter_pps 0
```

## Implementation Details

- **Thread safety:** All metrics use mutex-protected reads
- **Mutex order:** Consistent with existing code to prevent deadlocks
- **Signal handling:** Prometheus thread blocks all signals to prevent interference
- **Graceful shutdown:** HTTP server is properly stopped on exit
- **Error handling:** All libmicrohttpd function returns are checked
- **Memory management:** All HTTP responses are properly freed
