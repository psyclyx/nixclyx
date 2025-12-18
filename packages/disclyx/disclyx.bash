#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=0

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warn: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

check_partitioned() {
  local disk=$1
  local p1_type p2_type p3_type

  p1_type=$(sgdisk -p "$disk" 2>/dev/null | awk '$1==1 {print $6}') || die "Cannot read: $disk"
  p2_type=$(sgdisk -p "$disk" 2>/dev/null | awk '$1==2 {print $6}')
  p3_type=$(sgdisk -p "$disk" 2>/dev/null | awk '$1==3 {print $6}')

  [[ $p1_type == EF00 || $p1_type == 8300 ]] || die "Partition 1 wrong type: $disk"
  [[ $p2_type == 8200 ]] || die "Partition 2 not swap: $disk"
  [[ $p3_type == 8300 ]] || die "Partition 3 not Linux: $disk"
}

get_p1_type() {
  sgdisk -p "$1" 2>/dev/null | awk '$1==1 {print $6}'
}

fastest_tier() {
  local has_nvme=0 has_ssd=0 has_hdd=0
  for t in "$@"; do
    case $t in
      nvme) has_nvme=1 ;;
      ssd)  has_ssd=1 ;;
      hdd)  has_hdd=1 ;;
    esac
  done
  if (( has_nvme )); then echo nvme
  elif (( has_ssd )); then echo ssd
  else echo hdd
  fi
}

slowest_tier() {
  local has_nvme=0 has_ssd=0 has_hdd=0
  for t in "$@"; do
    case $t in
      nvme) has_nvme=1 ;;
      ssd)  has_ssd=1 ;;
      hdd)  has_hdd=1 ;;
    esac
  done
  if (( has_hdd )); then echo hdd
  elif (( has_ssd )); then echo ssd
  else echo nvme
  fi
}

get_members() {
  local mountpoint=$1
  local src
  src=$(findmnt -n -o SOURCE "$mountpoint") || die "Not mounted: $mountpoint"
  tr ':' '\n' <<< "$src"
}

partition_to_disk() {
  local part=$1
  if [[ $part == *nvme* ]]; then
    echo "${part%p[0-9]*}"
  else
    echo "${part%%[0-9]*}"
  fi
}

classify_disk() {
  local disk=$1
  local dev=${disk##*/}
  dev=${dev%%[0-9]*}
  dev=${dev%p}

  if [[ $disk == *nvme* ]]; then
    echo nvme
  elif [[ -f /sys/block/$dev/queue/rotational ]] &&
       [[ $(< /sys/block/$dev/queue/rotational) == 0 ]]; then
    echo ssd
  else
    echo hdd
  fi
}

compute_targets() {
  local -a tiers=("$@")
  local fast slow

  fast=$(fastest_tier "${tiers[@]}")
  slow=$(slowest_tier "${tiers[@]}")

  echo "foreground_target=$fast"
  echo "promote_target=$fast"
  echo "metadata_target=$fast"
  echo "background_target=$slow"
}

get_current_targets() {
  local mountpoint=$1
  local device
  device=$(findmnt -n -o SOURCE "$mountpoint" | head -1 | cut -d: -f1) || die "Not mounted: $mountpoint"

  local super
  super=$(bcachefs show-super "$device" 2>/dev/null) || die "Cannot read superblock: $device"

  local fg pr md bg
  fg=$(grep -oP 'foreground_target:\s*\K\S+' <<< "$super" || echo "")
  pr=$(grep -oP 'promote_target:\s*\K\S+' <<< "$super" || echo "")
  md=$(grep -oP 'metadata_target:\s*\K\S+' <<< "$super" || echo "")
  bg=$(grep -oP 'background_target:\s*\K\S+' <<< "$super" || echo "")

  echo "foreground_target=$fg"
  echo "promote_target=$pr"
  echo "metadata_target=$md"
  echo "background_target=$bg"
}

cmd_partition() {
  local efi=1G swap=4G boot=0
  local -a disks=()

  while (( $# )); do
    case $1 in
      --efi=*) efi=${1#--efi=}; shift ;;
      --swap=*) swap=${1#--swap=}; shift ;;
      --boot) boot=1; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx partition [-n] [--efi=SIZE] [--swap=SIZE] [--boot] DISK...
  --efi=SIZE   EFI partition size (default: 1G)
  --swap=SIZE  Swap partition size (default: 4G)
  --boot       Mark first partition as EF00 (requires single disk)
EOF
        exit 0 ;;
      -*) die "partition: unknown option: $1" ;;
      *) disks+=("$1"); shift ;;
    esac
  done

  (( ${#disks[@]} )) || die "partition: no disks specified"
  (( boot && ${#disks[@]} > 1 )) && die "partition: --boot requires exactly one disk"

  for disk in "${disks[@]}"; do
    local type1=8300
    (( boot )) && type1=EF00

    run sgdisk "$disk" -W
    run sgdisk "$disk" --zap-all --align-end \
      --new=0:0:+"$efi" --typecode=0:"$type1" \
      --new=0:0:+"$swap" --typecode=0:8200 \
      --new=0:0:0 --typecode=0:8300
  done
}

cmd_swap() {
  local type=
  local -a disks=()

  while (( $# )); do
    case $1 in
      --type=*) type=${1#--type=}; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx swap [-n] --type=TYPE DISK...
  --type=TYPE  Required: ssd or hdd
EOF
        exit 0 ;;
      -*) die "swap: unknown option: $1" ;;
      *) disks+=("$1"); shift ;;
    esac
  done

  [[ -n $type ]] || die "swap: --type required"
  [[ $type == ssd || $type == hdd ]] || die "swap: type must be ssd or hdd"
  (( ${#disks[@]} )) || die "swap: no disks specified"

  local label="swap-$type"
  for disk in "${disks[@]}"; do
    run mkswap -L "$label" "${disk}2"
  done
}

cmd_boot_init() {
  local disk=

  while (( $# )); do
    case $1 in
      -h|--help)
        cat <<'EOF'
disclyx boot-init [-n] DISK
  Initialize boot on reserved partition
EOF
        exit 0 ;;
      -*) die "boot-init: unknown option: $1" ;;
      *) disk=$1; shift ;;
    esac
  done

  [[ -n $disk ]] || die "boot-init: disk required"

  local p1_type
  p1_type=$(get_p1_type "$disk")
  [[ -n $p1_type ]] || die "boot-init: partition 1 not found: $disk"
  [[ $p1_type == 8300 ]] || die "boot-init: partition 1 not reserved (is $p1_type): $disk"

  run sgdisk "$disk" --typecode=1:EF00
  run mkfs.vfat -F32 "${disk}1"
  run sgdisk "$disk" --change-name=1:boot
}

cmd_boot_migrate() {
  local from= to= mountpoint=

  while (( $# )); do
    case $1 in
      --from=*) from=${1#--from=}; shift ;;
      --to=*) to=${1#--to=}; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx boot-migrate [-n] --from=DISK --to=DISK MOUNTPOINT
  Migrate boot filesystem between disks
EOF
        exit 0 ;;
      -*) die "boot-migrate: unknown option: $1" ;;
      *) mountpoint=$1; shift ;;
    esac
  done

  [[ -n $from ]] || die "boot-migrate: --from required"
  [[ -n $to ]] || die "boot-migrate: --to required"
  [[ -n $mountpoint ]] || die "boot-migrate: mountpoint required"

  local from_type to_type
  from_type=$(get_p1_type "$from")
  to_type=$(get_p1_type "$to")

  [[ $from_type == EF00 ]] || die "boot-migrate: source partition 1 not EF00: $from"
  [[ -n $to_type ]] || die "boot-migrate: destination partition 1 not found: $to"
  mountpoint -q "$mountpoint/boot" || die "boot-migrate: $mountpoint/boot not mounted"

  run sgdisk "$to" --typecode=1:EF00
  run mkfs.vfat -F32 "${to}1"
  run sgdisk "$to" --change-name=1:boot

  local tmp
  tmp=$(mktemp -d)
  run mount "${to}1" "$tmp"
  run cp -a "$mountpoint/boot/." "$tmp/"
  run umount "$tmp"
  rmdir "$tmp"

  run umount "$mountpoint/boot"
  run sgdisk "$from" --typecode=1:8300
  run sgdisk "$from" --change-name=1:
  run wipefs -a "${from}1"
  run mount /dev/disk/by-partlabel/boot "$mountpoint/boot"

  warn "Update bootloader: efibootmgr / nixos-rebuild boot"
}

cmd_boot_wipe() {
  local disk=

  while (( $# )); do
    case $1 in
      -h|--help)
        cat <<'EOF'
disclyx boot-wipe [-n] DISK
  Demote boot partition to reserved
EOF
        exit 0 ;;
      -*) die "boot-wipe: unknown option: $1" ;;
      *) disk=$1; shift ;;
    esac
  done

  [[ -n $disk ]] || die "boot-wipe: disk required"

  local p1_type
  p1_type=$(get_p1_type "$disk")
  [[ $p1_type == EF00 ]] || die "boot-wipe: partition 1 not EF00: $disk"

  if findmnt -n "${disk}1" &>/dev/null; then
    die "boot-wipe: ${disk}1 is mounted"
  fi

  run sgdisk "$disk" --typecode=1:8300
  run sgdisk "$disk" --change-name=1:
  run wipefs -a "${disk}1"
}

cmd_classify() {
  local disk=

  while (( $# )); do
    case $1 in
      -h|--help)
        cat <<'EOF'
disclyx classify DISK
  Output: nvme, ssd, or hdd
EOF
        exit 0 ;;
      -*) die "classify: unknown option: $1" ;;
      *) disk=$1; shift ;;
    esac
  done

  [[ -n $disk ]] || die "classify: disk required"
  classify_disk "$disk"
}

cmd_targets() {
  local -a nvme=() ssd=() hdd=()
  local current= check= mountpoint=

  while (( $# )); do
    case $1 in
      --nvme=*) nvme+=("${1#--nvme=}"); shift ;;
      --ssd=*) ssd+=("${1#--ssd=}"); shift ;;
      --hdd=*) hdd+=("${1#--hdd=}"); shift ;;
      --current) current=1; shift ;;
      --check) check=1; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx targets [--nvme=DISK]... [--ssd=DISK]... [--hdd=DISK]...
disclyx targets --current MOUNTPOINT
disclyx targets --check MOUNTPOINT [--nvme=DISK]...
EOF
        exit 0 ;;
      -*) die "targets: unknown option: $1" ;;
      *) mountpoint=$1; shift ;;
    esac
  done

  if (( current )); then
    [[ -n $mountpoint ]] || die "targets: mountpoint required for --current"
    get_current_targets "$mountpoint"
    return
  fi

  local -a tiers=()
  (( ${#nvme[@]} )) && tiers+=(nvme)
  (( ${#ssd[@]} )) && tiers+=(ssd)
  (( ${#hdd[@]} )) && tiers+=(hdd)

  if (( check )); then
    [[ -n $mountpoint ]] || die "targets: mountpoint required for --check"

    if (( ${#tiers[@]} == 0 )); then
      local member
      while IFS= read -r member; do
        local disk tier
        disk=$(partition_to_disk "$member")
        tier=$(classify_disk "$disk")
        case $tier in
          nvme) nvme+=("$disk") ;;
          ssd) ssd+=("$disk") ;;
          hdd) hdd+=("$disk") ;;
        esac
      done < <(get_members "$mountpoint")

      (( ${#nvme[@]} )) && tiers+=(nvme)
      (( ${#ssd[@]} )) && tiers+=(ssd)
      (( ${#hdd[@]} )) && tiers+=(hdd)
    fi

    local optimal current_targets
    optimal=$(compute_targets "${tiers[@]}")
    current_targets=$(get_current_targets "$mountpoint")

    if [[ $optimal == "$current_targets" ]]; then
      info "OK"
      exit 0
    else
      info "--- current"
      info "$current_targets"
      info "+++ optimal"
      info "$optimal"
      exit 1
    fi
  fi

  (( ${#tiers[@]} )) || die "targets: no disks specified"
  compute_targets "${tiers[@]}"
}

cmd_format() {
  local -a nvme=() ssd=() hdd=()
  local include_boot=0

  while (( $# )); do
    case $1 in
      --nvme=*) nvme+=("${1#--nvme=}"); shift ;;
      --ssd=*) ssd+=("${1#--ssd=}"); shift ;;
      --hdd=*) hdd+=("${1#--hdd=}"); shift ;;
      --include-boot-disk) include_boot=1; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx format [-n] [--nvme=DISK]... [--ssd=DISK]... [--hdd=DISK]...
  --include-boot-disk  Allow formatting data partition on boot disk
EOF
        exit 0 ;;
      -*) die "format: unknown option: $1" ;;
      *) die "format: unexpected argument: $1" ;;
    esac
  done

  local -a all_disks=("${nvme[@]}" "${ssd[@]}" "${hdd[@]}")
  (( ${#all_disks[@]} )) || die "format: no disks specified"

  for disk in "${all_disks[@]}"; do
    check_partitioned "$disk"
    local p1_type
    p1_type=$(get_p1_type "$disk")
    if [[ $p1_type == EF00 ]] && (( ! include_boot )); then
      die "format: $disk has active boot partition (use --include-boot-disk)"
    fi
  done

  local -a tiers=()
  (( ${#nvme[@]} )) && tiers+=(nvme)
  (( ${#ssd[@]} )) && tiers+=(ssd)
  (( ${#hdd[@]} )) && tiers+=(hdd)

  local fast slow
  fast=$(fastest_tier "${tiers[@]}")
  slow=$(slowest_tier "${tiers[@]}")

  local -a cmd=(bcachefs format
    --compression=lz4 --background_compression=zstd
    --replicas=2 --label=bcachefs
    --foreground_target="$fast" --promote_target="$fast" --metadata_target="$fast"
  )

  [[ $fast != "$slow" ]] && cmd+=(--background_target="$slow")

  for disk in "${nvme[@]}"; do
    cmd+=(--discard --label=nvme "${disk}3")
  done
  for disk in "${ssd[@]}"; do
    cmd+=(--discard --label=ssd "${disk}3")
  done
  for disk in "${hdd[@]}"; do
    cmd+=(--label=hdd "${disk}3")
  done

  run "${cmd[@]}"
}

cmd_mount() {
  local boot=0 mountpoint=

  while (( $# )); do
    case $1 in
      --boot) boot=1; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx mount [-n] [--boot] MOUNTPOINT
  --boot  Also mount boot partition
EOF
        exit 0 ;;
      -*) die "mount: unknown option: $1" ;;
      *) mountpoint=$1; shift ;;
    esac
  done

  [[ -n $mountpoint ]] || die "mount: mountpoint required"

  run mkdir -p "$mountpoint"
  if ! mountpoint -q "$mountpoint"; then
    run mount -t bcachefs /dev/disk/by-label/bcachefs "$mountpoint"
  fi

  if (( boot )); then
    run mkdir -p "$mountpoint/boot"
    if ! mountpoint -q "$mountpoint/boot"; then
      run mount /dev/disk/by-partlabel/boot "$mountpoint/boot"
    fi
  fi
}

cmd_add() {
  local type= disk= mountpoint=

  while (( $# )); do
    case $1 in
      --type=*) type=${1#--type=}; shift ;;
      -h|--help)
        cat <<'EOF'
disclyx add [-n] --type=TYPE DISK MOUNTPOINT
  --type=TYPE  Required: nvme, ssd, or hdd
EOF
        exit 0 ;;
      -*) die "add: unknown option: $1" ;;
      *)
        if [[ -z $disk ]]; then
          disk=$1
        else
          mountpoint=$1
        fi
        shift ;;
    esac
  done

  [[ -n $type ]] || die "add: --type required"
  [[ $type =~ ^(nvme|ssd|hdd)$ ]] || die "add: type must be nvme, ssd, or hdd"
  [[ -n $disk ]] || die "add: disk required"
  [[ -n $mountpoint ]] || die "add: mountpoint required"

  check_partitioned "$disk"
  mountpoint -q "$mountpoint" || die "add: not mounted: $mountpoint"

  local -a cmd=(bcachefs device add --label="$type")
  [[ $type != hdd ]] && cmd+=(--discard)
  cmd+=("${disk}3" "$mountpoint")

  run "${cmd[@]}"

  local -a nvme=() ssd=() hdd=()
  local member
  while IFS= read -r member; do
    local d t
    d=$(partition_to_disk "$member")
    t=$(classify_disk "$d")
    case $t in
      nvme) nvme+=("$d") ;;
      ssd) ssd+=("$d") ;;
      hdd) hdd+=("$d") ;;
    esac
  done < <(get_members "$mountpoint")

  case $type in
    nvme) nvme+=("$disk") ;;
    ssd) ssd+=("$disk") ;;
    hdd) hdd+=("$disk") ;;
  esac

  local -a tiers=()
  (( ${#nvme[@]} )) && tiers+=(nvme)
  (( ${#ssd[@]} )) && tiers+=(ssd)
  (( ${#hdd[@]} )) && tiers+=(hdd)

  local optimal current_targets
  optimal=$(compute_targets "${tiers[@]}")
  current_targets=$(get_current_targets "$mountpoint")

  if [[ $optimal != "$current_targets" ]]; then
    warn "Targets now suboptimal. Run: disclyx targets --check $mountpoint"
  fi
}

cmd_remove() {
  local disk= mountpoint=

  while (( $# )); do
    case $1 in
      -h|--help)
        cat <<'EOF'
disclyx remove [-n] DISK MOUNTPOINT
EOF
        exit 0 ;;
      -*) die "remove: unknown option: $1" ;;
      *)
        if [[ -z $disk ]]; then
          disk=$1
        else
          mountpoint=$1
        fi
        shift ;;
    esac
  done

  [[ -n $disk ]] || die "remove: disk required"
  [[ -n $mountpoint ]] || die "remove: mountpoint required"

  local removing_tier
  removing_tier=$(classify_disk "$disk")

  local -a nvme=() ssd=() hdd=()
  local member
  while IFS= read -r member; do
    local d t
    d=$(partition_to_disk "$member")
    [[ $d == "$disk" ]] && continue
    t=$(classify_disk "$d")
    case $t in
      nvme) nvme+=("$d") ;;
      ssd) ssd+=("$d") ;;
      hdd) hdd+=("$d") ;;
    esac
  done < <(get_members "$mountpoint")

  local remaining_count=0
  case $removing_tier in
    nvme) remaining_count=${#nvme[@]} ;;
    ssd) remaining_count=${#ssd[@]} ;;
    hdd) remaining_count=${#hdd[@]} ;;
  esac

  if (( remaining_count == 0 )); then
    local current_targets
    current_targets=$(get_current_targets "$mountpoint")
    if grep -q "=$removing_tier" <<< "$current_targets"; then
      die "Cannot remove last $removing_tier disk: targets reference it. Update targets first."
    fi
  fi

  run bcachefs device evacuate "${disk}3"
  run bcachefs device remove "${disk}3" "$mountpoint"

  local -a tiers=()
  (( ${#nvme[@]} )) && tiers+=(nvme)
  (( ${#ssd[@]} )) && tiers+=(ssd)
  (( ${#hdd[@]} )) && tiers+=(hdd)

  if (( ${#tiers[@]} )); then
    local optimal current_targets
    optimal=$(compute_targets "${tiers[@]}")
    current_targets=$(get_current_targets "$mountpoint")
    if [[ $optimal != "$current_targets" ]]; then
      warn "Targets now suboptimal. Run: disclyx targets --check $mountpoint"
    fi
  fi
}

cmd_validate() {
  local mountpoint=

  while (( $# )); do
    case $1 in
      -h|--help)
        cat <<'EOF'
disclyx validate MOUNTPOINT
EOF
        exit 0 ;;
      -*) die "validate: unknown option: $1" ;;
      *) mountpoint=$1; shift ;;
    esac
  done

  [[ -n $mountpoint ]] || die "validate: mountpoint required"

  local exit_code=0
  local -a nvme=() ssd=() hdd=()
  local -a boot_disks=()

  local member
  while IFS= read -r member; do
    local disk
    disk=$(partition_to_disk "$member")
    local tier
    tier=$(classify_disk "$disk")
    case $tier in
      nvme) nvme+=("$disk") ;;
      ssd) ssd+=("$disk") ;;
      hdd) hdd+=("$disk") ;;
    esac

    local p1_type
    p1_type=$(get_p1_type "$disk")
    [[ $p1_type == EF00 ]] && boot_disks+=("$disk")
  done < <(get_members "$mountpoint")

  if (( ${#boot_disks[@]} == 1 )); then
    info "[PASS] boot: single boot disk (${boot_disks[0]})"
  elif (( ${#boot_disks[@]} == 0 )); then
    info "[FAIL] boot: no boot disk found"
    exit_code=1
  else
    info "[FAIL] boot: multiple boot disks (${boot_disks[*]})"
    exit_code=1
  fi

  if mountpoint -q "$mountpoint/boot"; then
    info "[PASS] boot: mounted at $mountpoint/boot"
  else
    info "[WARN] boot: not mounted at $mountpoint/boot"
    (( exit_code )) || exit_code=2
  fi

  local -a tiers=()
  (( ${#nvme[@]} )) && tiers+=(nvme)
  (( ${#ssd[@]} )) && tiers+=(ssd)
  (( ${#hdd[@]} )) && tiers+=(hdd)

  local optimal current_targets
  optimal=$(compute_targets "${tiers[@]}")
  current_targets=$(get_current_targets "$mountpoint")

  local bad_tier=0
  for target_line in $current_targets; do
    local val=${target_line#*=}
    if [[ -n $val ]] && ! printf '%s\n' "${tiers[@]}" | grep -qx "$val"; then
      info "[FAIL] targets: references nonexistent tier $val"
      exit_code=1
      bad_tier=1
    fi
  done

  if (( ! bad_tier )); then
    if [[ $optimal == "$current_targets" ]]; then
      info "[PASS] targets: optimal"
    else
      info "[WARN] targets: suboptimal"
      (( exit_code )) || exit_code=2
    fi
  fi

  local device replicas num_devices
  device=$(findmnt -n -o SOURCE "$mountpoint" | head -1 | cut -d: -f1)
  replicas=$(bcachefs show-super "$device" 2>/dev/null | grep -oP 'replicas:\s*\K\d+' || echo 0)
  num_devices=$(get_members "$mountpoint" | wc -l)

  if (( replicas <= num_devices )); then
    info "[PASS] replicas: $replicas replicas, $num_devices devices"
  else
    info "[WARN] replicas: $replicas replicas but only $num_devices devices"
    (( exit_code )) || exit_code=2
  fi

  exit "$exit_code"
}

usage() {
  cat <<'EOF'
disclyx - disk lifecycle management

Usage: disclyx [options] <command> [args...]

Options:
  -n, --dry-run    Print commands without executing
  -h, --help       Show this help

Commands:
  partition   Create partition table
  swap        Format swap partition
  boot-init   Initialize boot filesystem
  boot-migrate Migrate boot to another disk
  boot-wipe   Clear boot filesystem
  targets     Compute/check bcachefs targets
  format      Create bcachefs filesystem
  mount       Mount bcachefs and boot
  add         Add disk to bcachefs
  remove      Remove disk from bcachefs
  validate    Check configuration sanity
  classify    Detect disk type

Run 'disclyx <command> -h' for command help.
EOF
}

main() {
  local cmd=
  while (( $# )); do
    case $1 in
      -n|--dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option: $1" ;;
      *) cmd=$1; shift; break ;;
    esac
  done

  [[ -n $cmd ]] || { usage; exit 1; }

  case $cmd in
    partition)    cmd_partition "$@" ;;
    swap)         cmd_swap "$@" ;;
    boot-init)    cmd_boot_init "$@" ;;
    boot-migrate) cmd_boot_migrate "$@" ;;
    boot-wipe)    cmd_boot_wipe "$@" ;;
    targets)      cmd_targets "$@" ;;
    format)       cmd_format "$@" ;;
    mount)        cmd_mount "$@" ;;
    add)          cmd_add "$@" ;;
    remove)       cmd_remove "$@" ;;
    validate)     cmd_validate "$@" ;;
    classify)     cmd_classify "$@" ;;
    *)            die "unknown command: $cmd" ;;
  esac
}

main "$@"
