{
  path = ["psyclyx" "nixos" "network" "tuning"];
  description = "TCP/IP stack tuning for all hosts";
  config = _: {
    boot.kernel.sysctl = {
      # BBR congestion control — better throughput and latency than CUBIC
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Fair Queueing — required companion to BBR for pacing
      "net.core.default_qdisc" = "fq";

      # Socket buffer limits — allow autotuning up to 16 MB
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";

      # Keep congestion window across idle periods
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      # Larger NIC backlog for burst handling
      "net.core.netdev_max_backlog" = 5000;
      # TCP Fast Open (client + server)
      "net.ipv4.tcp_fastopen" = 3;
      # Halve TIME_WAIT duration
      "net.ipv4.tcp_fin_timeout" = 30;
      # Reuse TIME_WAIT sockets for outgoing connections
      "net.ipv4.tcp_tw_reuse" = 1;
      # Reduce SYN-ACK retransmit amplification
      "net.ipv4.tcp_synack_retries" = 2;

      # Enable PMTU discovery — avoids black holes from broken path MTU
      "net.ipv4.tcp_mtu_probing" = 1;
      # Larger listen backlog for burst connections
      "net.core.somaxconn" = 8192;
      # Widen ephemeral port range
      "net.ipv4.ip_local_port_range" = "1024 65535";

      # Detect dead connections faster (10min instead of 2hr)
      "net.ipv4.tcp_keepalive_time" = 600;
      "net.ipv4.tcp_keepalive_intvl" = 15;
      "net.ipv4.tcp_keepalive_probes" = 5;

      # Ignore ICMP redirects — prevents route injection
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      # Don't send ICMP redirects
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
    };
  };
}
