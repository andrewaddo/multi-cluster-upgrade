import requests
import time
import threading
import csv
import sys
import argparse
import statistics
from datetime import datetime

class MetricsCollector:
    def __init__(self):
        self.results = []
        self.lock = threading.Lock()
        self.start_time = None

    def add_result(self, timestamp, latency, status_code, cluster, version, error=None):
        with self.lock:
            self.results.append({
                'timestamp': timestamp,
                'latency': latency,
                'status_code': status_code,
                'cluster': cluster,
                'version': version,
                'error': error
            })

    def get_summary(self):
        with self.lock:
            if not self.results:
                return None
            
            latencies = sorted([r['latency'] for r in self.results if r['latency'] is not None])
            successes = [r for r in self.results if r['status_code'] == 200]
            errors = [r for r in self.results if r['status_code'] != 200]
            
            p95 = 0
            if latencies:
                idx = int(len(latencies) * 0.95)
                p95 = latencies[min(idx, len(latencies)-1)]

            summary = {
                'total_requests': len(self.results),
                'success_count': len(successes),
                'error_count': len(errors),
                'error_rate': (len(errors) / len(self.results)) * 100 if self.results else 0,
                'avg_latency': statistics.mean(latencies) if latencies else 0,
                'p95_latency': p95,
                'cluster_dist': {},
                'version_dist': {}
            }
            
            for r in successes:
                c = r['cluster']
                v = r['version']
                summary['cluster_dist'][c] = summary['cluster_dist'].get(c, 0) + 1
                summary['version_dist'][v] = summary['version_dist'].get(v, 0) + 1
                
            return summary

    def save_to_csv(self, filename):
        with self.lock:
            if not self.results:
                return
            keys = self.results[0].keys()
            with open(filename, 'w', newline='') as f:
                dict_writer = csv.DictWriter(f, fieldnames=keys)
                dict_writer.writeheader()
                dict_writer.writerows(self.results)

def worker(url, collector, stop_event, rate_limit_sleep, host_header=None, resolve_map=None):
    from urllib.parse import urlparse
    parsed_url = urlparse(url)
    target_host = parsed_url.hostname
    target_port = parsed_url.port or (80 if parsed_url.scheme == 'http' else 443)
    target_path = parsed_url.path
    if parsed_url.query:
        target_path += "?" + parsed_url.query

    while not stop_event.is_set():
        start = time.time()
        timestamp = datetime.now().isoformat()
        try:
            # Disable keep-alive for better LB visibility
            headers = {'Connection': 'close'}
            if host_header:
                headers['Host'] = host_header
            
            # If resolve_map is provided, try all IPs until success
            response = None
            if resolve_map and target_host in resolve_map:
                ips = resolve_map[target_host]
                for ip in ips:
                    try:
                        temp_url = f"{parsed_url.scheme}://{ip}:{target_port}{target_path}"
                        response = requests.get(temp_url, timeout=2, headers=headers)
                        if response.status_code != 0:
                            break
                    except:
                        continue
            
            if response is None:
                response = requests.get(url, timeout=5, headers=headers)
            
            latency = (time.time() - start) * 1000 # ms
            status_code = response.status_code
            
            cluster = "unknown"
            version = "unknown"
            if status_code == 200:
                try:
                    data = response.json()
                    cluster = data.get("cluster", "unknown")
                    version = data.get("version", "unknown")
                except:
                    pass
            
            collector.add_result(timestamp, latency, status_code, cluster, version)
            
        except Exception as e:
            latency = (time.time() - start) * 1000
            collector.add_result(timestamp, latency, 0, "error", "error", error=str(e))
        
        time.sleep(rate_limit_sleep)

def main():
    parser = argparse.ArgumentParser(description="Performance Load Tester for GKE Version Update")
    parser.add_argument("url", help="Target URL (e.g. http://<gateway-ip>/status)")
    parser.add_argument("--rps", type=float, default=5.0, help="Target Requests Per Second (approx)")
    parser.add_argument("--duration", type=int, default=60, help="Duration in seconds (0 for infinite)")
    parser.add_argument("--output", default="migration_report.csv", help="Filename for the CSV report")
    parser.add_argument("--host", help="Custom Host header")
    parser.add_argument("--resolve", help="Custom resolve mapping (e.g. app.demo.gke:ip1,ip2)")
    
    args = parser.parse_args()

    resolve_map = {}
    if args.resolve:
        parts = args.resolve.split(':')
        if len(parts) == 2:
            host = parts[0]
            ips = parts[1].split(',')
            resolve_map[host] = ips
    
    rate_limit_sleep = 1.0 / args.rps
    collector = MetricsCollector()
    stop_event = threading.Event()
    
    print(f"Starting load test...")
    print(f"Target URL: {args.url}")
    if args.host:
        print(f"Host Header: {args.host}")
    if resolve_map:
        print(f"Resolve Mapping: {resolve_map}")
    print(f"Target RPS: {args.rps}")
    print(f"CSV Report will be saved to: {args.output}")
    print("Press Ctrl+C to stop and generate report.\n")
    
    t = threading.Thread(target=worker, args=(args.url, collector, stop_event, rate_limit_sleep, args.host, resolve_map))
    t.start()
    
    start_time = time.time()
    try:
        while True:
            elapsed = time.time() - start_time
            if args.duration > 0 and elapsed >= args.duration:
                break
            
            summary = collector.get_summary()
            if summary:
                sys.stdout.write(
                    f"\r[Elapsed: {int(elapsed)}s] Req: {summary['total_requests']} | "
                    f"Err: {summary['error_count']} ({summary['error_rate']:.1f}%) | "
                    f"P95 Latency: {summary['p95_latency']:.1f}ms   "
                )
                sys.stdout.flush()
            
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nStopping test...")
    
    stop_event.set()
    t.join()
    
    print("\n" + "="*40)
    print("MIGRATION PERFORMANCE REPORT")
    print("="*40)
    
    summary = collector.get_summary()
    if summary:
        print(f"Total Requests:   {summary['total_requests']}")
        print(f"Successful:       {summary['success_count']}")
        print(f"Failed:           {summary['error_count']}")
        print(f"Error Rate:       {summary['error_rate']:.2f}%")
        print(f"Average Latency:  {summary['avg_latency']:.2f} ms")
        print(f"P95 Latency:      {summary['p95_latency']:.2f} ms")
        print("\nTraffic Distribution by Cluster:")
        for cluster, count in summary['cluster_dist'].items():
            pct = (count / summary['success_count']) * 100
            print(f"  - {cluster}: {count} ({pct:.1f}%)")
        print("\nTraffic Distribution by Version:")
        for version, count in summary['version_dist'].items():
            pct = (count / summary['success_count']) * 100
            print(f"  - {version}: {count} ({pct:.1f}%)")
        
        collector.save_to_csv(args.output)
        print(f"\nDetailed metrics saved to: {args.output}")
    else:
        print("No data collected.")

if __name__ == "__main__":
    main()
