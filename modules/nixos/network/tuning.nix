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
    };
  };
}
