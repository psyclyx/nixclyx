lib: {
  keepLast ? 3,
  hourly ? 6,
  daily ? 7,
  weekly ? 4,
  monthly ? 6,
}: {
  keepLast = lib.mkOption {
    type = lib.types.int;
    default = keepLast;
    description = "Always keep at least this many snapshots regardless of age.";
  };
  hourly = lib.mkOption {
    type = lib.types.int;
    default = hourly;
    description = "Number of hourly snapshots to keep.";
  };
  daily = lib.mkOption {
    type = lib.types.int;
    default = daily;
    description = "Number of daily snapshots to keep.";
  };
  weekly = lib.mkOption {
    type = lib.types.int;
    default = weekly;
    description = "Number of weekly snapshots to keep.";
  };
  monthly = lib.mkOption {
    type = lib.types.int;
    default = monthly;
    description = "Number of monthly snapshots to keep.";
  };
}
