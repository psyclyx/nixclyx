{
  path = ["psyclyx" "nixos" "system" "tuning"];
  description = "Kernel, VM, and filesystem tuning for all hosts";
  config = _: {
    boot.kernel.sysctl = {
      # --- VM / Memory ---

      # Prefer evicting file cache over swapping anonymous pages
      "vm.swappiness" = 10;
      # Start async writeback at 3% dirty (smoother I/O, fewer stalls)
      "vm.dirty_background_ratio" = 3;
      # Force synchronous writeback at 10% dirty (default 20% is too much on high-RAM systems)
      "vm.dirty_ratio" = 10;
      # Wake writeback every 3s instead of 5s
      "vm.dirty_writeback_centisecs" = 300;
      # Write dirty pages after 15s instead of 30s — reduces data loss window
      "vm.dirty_expire_centisecs" = 1500;
      # Less aggressive dentry/inode eviction — benefits btree-heavy filesystems (bcachefs, ZFS)
      "vm.vfs_cache_pressure" = 50;
      # Keep 128MB free — breathing room for burst allocations and network buffers
      "vm.min_free_kbytes" = 131072;
      # Start kswapd reclaim earlier (0.5% vs 0.1% of zone) to avoid allocation stalls
      "vm.watermark_scale_factor" = 50;
      # Raise VMA limit for build tools, browsers, etc.
      "vm.max_map_count" = 1048576;

      # --- Filesystem / IPC ---

      # IDEs, file watchers, build systems, containers all eat inotify watches
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 1024;
      # Async I/O slots for databases and heavy I/O workloads
      "fs.aio-max-nr" = 1048576;

      # --- Kernel ---

      # Full magic sysrq for emergency recovery
      "kernel.sysrq" = 1;
      # Disable NMI watchdog — frees a perf counter, not useful outside kernel debugging
      "kernel.nmi_watchdog" = 0;
      # More PID headroom for containers and fork-heavy workloads
      "kernel.pid_max" = 131072;

      # --- Security hardening (mild, non-breaking) ---

      # Hide kernel pointers from non-root
      "kernel.kptr_restrict" = 1;
      # Restrict dmesg to root
      "kernel.dmesg_restrict" = 1;
      # Disable unprivileged BPF
      "kernel.unprivileged_bpf_disabled" = 1;
    };
  };
}
