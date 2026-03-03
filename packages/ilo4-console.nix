{
  writeShellApplication,
  curl,
  adoptopenjdk-icedtea-web,
}:
writeShellApplication {
  name = "ilo4-console";
  runtimeInputs = [curl adoptopenjdk-icedtea-web];
  text = ''
    die() { echo "error: $*" >&2; exit 1; }

    : "''${ILO_HOST:?ILO_HOST must be set}"
    : "''${ILO_USER:?ILO_USER must be set}"
    : "''${ILO_PASSWORD:?ILO_PASSWORD must be set}"

    base="https://''${ILO_HOST}"

    echo "Authenticating to iLO 4 at ''${ILO_HOST}..."
    session_key=$(
      curl -fsS --insecure "''${base}/json/login_session" \
        --data "{\"method\":\"login\",\"user_login\":\"''${ILO_USER}\",\"password\":\"''${ILO_PASSWORD}\"}" |
        sed 's/.*"session_key":"\([a-f0-9]\{32\}\)".*/\1/'
    ) || die "authentication failed"

    [ -n "$session_key" ] || die "empty session key — wrong credentials or account locked?"

    jnlp=$(mktemp --suffix=.jnlp)
    security_override=$(mktemp --suffix=.security)
    trap 'rm -f "$jnlp" "$security_override"' EXIT

    # Re-enable legacy TLS for iLO 4 — Java 8u292+ blacklists TLSv1/TLSv1.1
    # in jdk.tls.disabledAlgorithms which overrides jdk.tls.client.protocols.
    cat >"$security_override" <<'SECPROPS'
    jdk.tls.disabledAlgorithms=SSLv3, RC4, DES, MD5withRSA, \
        DH keySize < 1024, EC keySize < 224, anon, NULL
    SECPROPS

    cat >"$jnlp" <<JNLP
    <?xml version="1.0" encoding="UTF-8"?>
    <jnlp spec="1.0+" codebase="''${base}/" href="">
      <information>
        <title>iLO 4 Integrated Remote Console</title>
        <vendor>HPE</vendor>
        <offline-allowed/>
      </information>
      <security><all-permissions/></security>
      <resources>
        <j2se version="1.5+"/>
        <jar href="''${base}/html/intgapp4_231.jar" main="false"/>
      </resources>
      <applet-desc main-class="com.hp.ilo2.intgapp.intgapp"
                   name="iLOJIRC"
                   documentbase="''${base}/html/java_irc.html"
                   width="1" height="1">
        <param name="RCINFO1" value="''${session_key}"/>
        <param name="RCINFOLANG" value="en"/>
        <param name="INFO0" value="7AC3BDEBC9AC64E85734454B53BB73CE"/>
        <param name="INFO1" value="17988"/>
        <param name="INFO2" value="composite"/>
      </applet-desc>
    </jnlp>
    JNLP

    echo "Launching remote console..."
    javaws -Xnofork \
      -J-Djava.security.properties="$security_override" \
      -J-Djdk.tls.client.protocols=TLSv1,TLSv1.1,TLSv1.2 \
      "$jnlp"
  '';
}
