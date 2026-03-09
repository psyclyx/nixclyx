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
      curl -fsS --insecure \
        --tls-max 1.2 --tlsv1 \
        "''${base}/json/login_session" \
        --data "{\"method\":\"login\",\"user_login\":\"''${ILO_USER}\",\"password\":\"''${ILO_PASSWORD}\"}" |
        sed 's/.*"session_key":"\([a-f0-9]\{32\}\)".*/\1/'
    ) || die "authentication failed"

    [ -n "$session_key" ] || die "empty session key — wrong credentials or account locked?"

    jnlp=$(mktemp --suffix=.jnlp)
    security_override=$(mktemp --suffix=.security)
    trap 'rm -f "$jnlp" "$security_override"' EXIT

    # Re-enable legacy TLS + ciphers for iLO 4.
    # OpenJDK 8u292+ disables TLSv1/TLSv1.1; 8u351+ disables 3DES_EDE_CBC;
    # 8u401+ disables ECDH. iLO4 needs some combination of these.
    # Also re-enable MD5 JAR signatures — iLO4 applet JARs use MD5.
    cat >"$security_override" <<'SECPROPS'
    jdk.tls.disabledAlgorithms=SSLv3, RC4, DES, MD5withRSA, \
        DH keySize < 1024, EC keySize < 224, anon, NULL
    jdk.jar.disabledAlgorithms=MD2
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
      -J-Dhttps.protocols=TLSv1,TLSv1.1,TLSv1.2 \
      "$jnlp"
  '';
}
