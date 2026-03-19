# bcachefs-prune.nix — Generates a shell script fragment for timeline-based
# snapshot pruning. Used by both the root impermanence rollback (initrd) and
# periodic home snapshot services.
#
# Snapshots are expected to be named as ISO 8601 timestamps (YYYY-MM-DDTHH:MM:SS)
# either as direct children (for root old snapshots: @2026-03-07T10:30:00) or
# bare (for home snapshots in @snapshots/: 2026-03-07T10:30:00).
#
# Retention policy (snapper-style timeline):
#   - keepLast: always keep at least N newest snapshots
#   - hourly:   keep N snapshots, one per hour bucket
#   - daily:    keep N snapshots, one per day bucket
#   - weekly:   keep N snapshots, one per week bucket
#   - monthly:  keep N snapshots, one per month bucket
#
# A snapshot is kept if ANY bucket claims it. The algorithm walks newest→oldest,
# assigning each snapshot to the finest-grained bucket that still has capacity.
{
  dir,
  glob,
  keepLast ? 3,
  hourly ? 6,
  daily ? 7,
  weekly ? 4,
  monthly ? 6,
}: ''
  # --- snapshot pruning (timeline backoff) ---
  _prune_dir=${dir}
  _prune_keep_last=${toString keepLast}
  _prune_hourly=${toString hourly}
  _prune_daily=${toString daily}
  _prune_weekly=${toString weekly}
  _prune_monthly=${toString monthly}

  # Collect all timestamp-named snapshots, sorted newest first
  _snaps=()
  for s in $(ls -1d "$_prune_dir"/${glob} 2>/dev/null | sort -r); do
    _snaps+=("$s")
  done

  if [ ''${#_snaps[@]} -gt 0 ]; then
    # Track bucket counts
    _kept_last=0
    _kept_hourly=0
    _kept_daily=0
    _kept_weekly=0
    _kept_monthly=0
    # Track which buckets we've seen (to keep one per bucket)
    declare -A _seen_hours _seen_days _seen_weeks _seen_months

    for snap in "''${_snaps[@]}"; do
      _keep=false
      _base=$(basename "$snap")
      # Strip leading @ if present (root snapshots are @2026-...)
      _ts="''${_base#@}"

      # keepLast — always keep the N newest
      if [ "$_kept_last" -lt "$_prune_keep_last" ]; then
        _keep=true
        _kept_last=$((_kept_last + 1))
      fi

      # Parse timestamp components: YYYY-MM-DDTHH:MM:SS
      _hour="''${_ts:0:13}"   # YYYY-MM-DDTHH
      _day="''${_ts:0:10}"    # YYYY-MM-DD
      # Week bucket: use date to get ISO week
      _week=$(date -d "''${_ts:0:10}" +%G-W%V 2>/dev/null || echo "unknown")
      _month="''${_ts:0:7}"   # YYYY-MM

      # Hourly bucket
      if [ "$_keep" != "true" ] && [ "$_kept_hourly" -lt "$_prune_hourly" ] && [ -z "''${_seen_hours[$_hour]:-}" ]; then
        _keep=true
        _kept_hourly=$((_kept_hourly + 1))
      fi
      _seen_hours[$_hour]=1

      # Daily bucket
      if [ "$_keep" != "true" ] && [ "$_kept_daily" -lt "$_prune_daily" ] && [ -z "''${_seen_days[$_day]:-}" ]; then
        _keep=true
        _kept_daily=$((_kept_daily + 1))
      fi
      _seen_days[$_day]=1

      # Weekly bucket
      if [ "$_keep" != "true" ] && [ "$_kept_weekly" -lt "$_prune_weekly" ] && [ -z "''${_seen_weeks[$_week]:-}" ]; then
        _keep=true
        _kept_weekly=$((_kept_weekly + 1))
      fi
      _seen_weeks[$_week]=1

      # Monthly bucket
      if [ "$_keep" != "true" ] && [ "$_kept_monthly" -lt "$_prune_monthly" ] && [ -z "''${_seen_months[$_month]:-}" ]; then
        _keep=true
        _kept_monthly=$((_kept_monthly + 1))
      fi
      _seen_months[$_month]=1

      if [ "$_keep" != "true" ]; then
        echo "Pruning snapshot: $snap"
        bcachefs subvolume delete "$snap"
      fi
    done
  fi
  # --- end snapshot pruning ---
''
