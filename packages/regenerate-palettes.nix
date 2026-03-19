{ writeShellApplication, base24-gen }:

writeShellApplication {
  name = "regenerate-palettes";
  runtimeInputs = [ base24-gen ];
  text = ''
    root="$(git rev-parse --show-toplevel)"
    if [ -d "$root/assets/wallpapers" ]; then
      cd "$root"
    elif [ -d "$root/nixclyx/assets/wallpapers" ]; then
      cd "$root/nixclyx"
    else
      echo "error: cannot find assets/wallpapers from git root" >&2
      exit 1
    fi

    palette_dir=assets/palettes
    mkdir -p "$palette_dir"

    # remove stale palettes whose wallpaper no longer exists
    for palette in "$palette_dir"/*.yaml; do
      [ -f "$palette" ] || continue
      name="$(basename "$palette" .yaml)"
      found=0
      for wp in assets/wallpapers/*; do
        wp_name="$(basename "''${wp%.*}")"
        if [ "$wp_name" = "$name" ]; then
          found=1
          break
        fi
      done
      if [ "$found" = 0 ]; then
        echo "removing stale palette: $palette"
        rm "$palette"
      fi
    done

    # generate palettes for each wallpaper
    for wallpaper in assets/wallpapers/*; do
      name="$(basename "$wallpaper")"
      stem="''${name%.*}"
      out="$palette_dir/$stem.yaml"
      echo "generating $out"
      base24-gen --mode dark "$wallpaper" 2>&1 | grep -v '^info(' > "$out"
    done

    echo "done"
  '';
}
