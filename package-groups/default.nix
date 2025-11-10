{ pkgs }:
{
  core = rec {
    all = base;

    base = ;
  };

  files = rec {
    all = base ++ transfer ++ archive;

    base = [
    ];

    transfer = [
    ];

    archive = [
    ];
  };

  monitor = rec {
    all = base;

    base = [
      pkgs.btop
      pkgs.iotop
      pkgs.lsof
      pkgs.nmon
      pkgs.psmisc
    ];
  };

  system = rec {
    all = network ++ hardware ++ storage ++ trace;

    network = [
    ];

    hardware = [
      pkgs.pciutils
      pkgs.usbutils
      pkgs.lm_sensors
      pkgs.dmidecode
      pkgs.lshw
      pkgs.hwinfo
      pkgs.inxi
      pkgs.cpuid
      pkgs.cpufrequtils
      pkgs.turbostat
    ];

    storage = [
      pkgs.smartmontools
      pkgs.parted
      pkgs.lsblk
      pkgs.hdparm
      pkgs.sdparm
      pkgs.nvme-cli
      pkgs.mdadm
      pkgs.lvm2
    ];

    trace = [
      pkgs.sysdig
      pkgs.perf-tools
      pkgs.bpftrace
      pkgs.bcc
    ];

  };

  benchmark = rec {
    all = base;

    base = [
      pkgs.sysbench
      pkgs.stress-ng
      pkgs.fio
      pkgs.iozone
      pkgs.bonnie
      pkgs.phoronix-test-suite
      pkgs.geekbench
    ];
  };

  dev = rec {
    all = base ++ debug ++ lang.all;

    base = [
      pkgs.binutils
      pkgs.binwalk
      pkgs.git
      pkgs.github-cli
      pkgs.gnumake
      pkgs.helix
      pkgs.hexdump
      pkgs.pkg-config
      pkgs.jq
      pkgs.yq
      pkgs.jet
      pkgs.vim
      pkgs.xxd
      pkgs.docker-compose
      pkgs.dive
      pkgs.meson
      pkgs.autoconf
      pkgs.automake
      pkgs.libtool
    ];

    debug = [
      pkgs.gdb
      pkgs.strace
      pkgs.ltrace
      pkgs.lldb
      pkgs.rr
      pkgs.valgrind
    ];

    lang = rec {
      all = c ++ clojure ++ python ++ rust ++ shell;

      c = [
        pkgs.gcc
        pkgs.clang
        pkgs.llvm
      ];

      clojure = [
        pkgs.clojure
        pkgs.clojure-lsp
        pkgs.temurin-bin-25
        pkgs.leiningen
        pkgs.neil
        pkgs.babashka
        pkgs.jet
      ];

      python = [
        pkgs.python3
        pkgs.poetry
        pkgs.uv
        pkgs.pipx
        pkgs.virtualenv
      ];

      rust = [
        pkgs.rustc
        pkgs.cargo
        pkgs.rustfmt
        pkgs.clippy
        pkgs.rust-analyzer
        pkgs.cargo-watch
        pkgs.cargo-edit
      ];

      shell = [
        pkgs.shellcheck
        pkgs.shfmt
      ];

    };
  };

  security = rec {
    all = base ++ forensics;
pc
    base = [
      pkgs.age
      pkgs.gnupg
      pkgs.openssl
      pkgs.sops
    ];

    forensics = [
      pkgs.ddrescue
      pkgs.hashcat
      pkgs.john
      pkgs.photorec
      pkgs.testdisk
    ];
  };

  media = {
    playback = [
      pkgs.mpv
      pkgs.vlc
      pkgs.mplayer
      pkgs.pavucontrol
    ];

    tools = [
    ];
  };
}
