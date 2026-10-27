"""Local-only UDP impairment fixture; never changes game stats or OS networking.

One proxy port serves one client. Fifty milliseconds each way gives a nominal
100ms RTT; independent seeded loss applies to UDP datagrams in both directions,
including ENet acknowledgements/retries. Create --stop-file for a clean report.
"""
from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
import random
import time


class UdpImpairment(asyncio.DatagramProtocol):
    def __init__(self, target_port: int, delay_ms: float, loss: float, seed: int):
        self.target = ("127.0.0.1", target_port)
        self.delay = delay_ms / 1000.0
        self.loss = loss
        self.rng = random.Random(seed)
        self.client = None
        self.transport = None
        self.closed = False
        self.queued = 0
        self.started = time.perf_counter()
        self.directions = {
            name: dict(received=0, dropped=0, forwarded=0, bytes_forwarded=0)
            for name in ("client_to_host", "host_to_client")
        }
        self.overflow = 0
        self.errors = 0
        self.endpoint_closures = 0
        self.error_codes = {}

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        if self.closed:
            return
        if addr == self.target:
            if self.client is None:
                return
            direction, destination = "host_to_client", self.client
        else:
            if self.client is not None and self.client != addr:
                return  # A proxy port represents exactly one client endpoint.
            self.client = addr
            direction, destination = "client_to_host", self.target
        entry = self.directions[direction]
        entry["received"] += 1
        if self.rng.random() < self.loss:
            entry["dropped"] += 1
            return
        if self.queued >= 4096:
            self.overflow += 1
            return
        self.queued += 1
        asyncio.get_running_loop().call_later(
            self.delay, self._forward, data, destination, direction,
            time.perf_counter() + self.delay,
        )

    def _forward(self, data, destination, direction, deadline):
        remaining = deadline - time.perf_counter()
        if remaining > 0:
            # Windows event-loop timers may wake early at their clock resolution.
            # Never silently simulate less delay than the requested network RTT.
            asyncio.get_running_loop().call_later(
                max(0.001, remaining), self._forward,
                data, destination, direction, deadline,
            )
            return
        self.queued -= 1
        if self.closed:
            return
        self.transport.sendto(data, destination)
        entry = self.directions[direction]
        entry["forwarded"] += 1
        entry["bytes_forwarded"] += len(data)

    def error_received(self, error):
        code = getattr(error, "winerror", None) or getattr(error, "errno", None)
        key = f"{type(error).__name__}:{code}"
        self.error_codes[key] = self.error_codes.get(key, 0) + 1
        # UDP can receive an ICMP port-closed notification after an owned peer
        # exits normally. Keep it visible, separate from proxy transport faults.
        if isinstance(error, (ConnectionRefusedError, ConnectionResetError)):
            self.endpoint_closures += 1
        else:
            self.errors += 1

    def report(self):
        return {
            "scope": "local loopback UDP fixture; not two-machine LAN/WAN",
            "listen_port": self.transport.get_extra_info("sockname")[1],
            "target_port": self.target[1],
            "one_way_delay_ms": self.delay * 1000.0,
            "nominal_rtt_ms": self.delay * 2000.0,
            "configured_datagram_loss": self.loss,
            "elapsed_s": time.perf_counter() - self.started,
            "directions": self.directions,
            "queue_overflow": self.overflow,
            "transport_errors": self.errors,
            "endpoint_close_notifications": self.endpoint_closures,
            "error_codes": self.error_codes,
            "pending_on_stop": self.queued,
        }


async def run(args):
    loop = asyncio.get_running_loop()
    transport, proxy = await loop.create_datagram_endpoint(
        lambda: UdpImpairment(args.target_port, args.delay_ms, args.loss, args.seed),
        local_addr=("127.0.0.1", args.listen_port),
    )
    print("UDP_PROXY_READY " + json.dumps(proxy.report()), flush=True)
    try:
        while time.perf_counter() - proxy.started < args.duration:
            if args.stop_file and args.stop_file.exists():
                break
            await asyncio.sleep(0.1)
        # Allow already received datagrams to finish their configured delay.
        await asyncio.sleep(proxy.delay + 0.05)
    finally:
        proxy.closed = True
        report = proxy.report()
        transport.close()
        if args.stats_file:
            args.stats_file.parent.mkdir(parents=True, exist_ok=True)
            args.stats_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("UDP_PROXY_FINISHED " + json.dumps(report), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-port", type=int, required=True)
    parser.add_argument("--listen-port", type=int, default=0)
    parser.add_argument("--delay-ms", type=float, default=50.0)
    parser.add_argument("--loss", type=float, default=0.01)
    parser.add_argument("--seed", type=int, default=42026)
    parser.add_argument("--duration", type=float, default=1200.0)
    parser.add_argument("--stop-file", type=Path)
    parser.add_argument("--stats-file", type=Path)
    args = parser.parse_args()
    if not (1024 <= args.target_port <= 65535 and 0 <= args.listen_port <= 65535):
        parser.error("ports must be usable UDP ports")
    if not (0 <= args.delay_ms <= 5000 and 0 <= args.loss < 1 and 0 < args.duration <= 7200):
        parser.error("invalid delay, loss or duration")
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
