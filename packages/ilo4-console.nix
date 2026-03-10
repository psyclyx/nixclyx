{
  writeShellApplication,
  curl,
  gnugrep,
  mitmproxy,
  socat,
  openjdk8,
}:
writeShellApplication {
  name = "ilo4-console";
  runtimeInputs = [curl gnugrep mitmproxy socat openjdk8];
  text = ''
    die() { echo "error: $*" >&2; exit 1; }

    : "''${ILO_HOST:?ILO_HOST must be set}"
    : "''${ILO_USER:?ILO_USER must be set}"
    : "''${ILO_PASSWORD:?ILO_PASSWORD must be set}"

    base="https://''${ILO_HOST}"
    proxy_port=9443

    # Start a reverse proxy to terminate the iLO's legacy TLS and re-serve
    # over modern TLS on localhost. This avoids all Java TLS compatibility
    # issues with iLO 4's old ciphers/protocols.
    mitmdump --ssl-insecure -p "$proxy_port" --mode "reverse:''${base}/" -q &

    # Forward KVM (17990) and virtual media (17988) ports from localhost
    # to the real iLO, since the applet derives the host from the codebase.
    socat TCP4-LISTEN:17990,fork,reuseaddr,bind=127.0.0.1 "TCP4:''${ILO_HOST}:17990" &
    socat TCP4-LISTEN:17988,fork,reuseaddr,bind=127.0.0.1 "TCP4:''${ILO_HOST}:17988" &

    cleanup() { kill 0 2>/dev/null; wait 2>/dev/null; }
    trap cleanup EXIT

    sleep 1

    proxy="https://127.0.0.1:''${proxy_port}"

    echo "Authenticating to iLO 4 at ''${ILO_HOST}..."
    session_key=$(
      curl -fsS --insecure \
        "''${proxy}/json/login_session" \
        --data "{\"method\":\"login\",\"user_login\":\"''${ILO_USER}\",\"password\":\"''${ILO_PASSWORD}\"}" |
        sed 's/.*"session_key":"\([a-f0-9]\{32\}\)".*/\1/'
    ) || die "authentication failed"

    [ -n "$session_key" ] || die "empty session key — wrong credentials or account locked?"

    # Discover the actual applet JAR name from the iLO (it varies by firmware).
    jar_name=$(
      curl -fsS --insecure \
        -H "Cookie: sessionKey=''${session_key}" \
        "''${proxy}/html/java_irc.html" |
        grep -oP 'intgapp4_\d+\.jar' | head -1
    ) || die "failed to detect applet JAR name"
    [ -n "$jar_name" ] || die "could not find applet JAR name in java_irc.html"

    tmpdir=$(mktemp -d)
    truststore="''${tmpdir}/truststore.jks"
    trap 'cleanup; rm -rf "$tmpdir"' EXIT

    # Import mitmproxy's CA cert into a temporary Java truststore so the
    # applet JVM trusts the proxied connections.
    keytool -importcert -noprompt -alias mitmproxy \
      -file "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" \
      -keystore "$truststore" -storepass changeit 2>/dev/null \
      || die "failed to create truststore (has mitmproxy been run before?)"

    # Pre-download the applet JAR.
    echo "Downloading ''${jar_name}..."
    curl -fsS --insecure \
      -o "''${tmpdir}/''${jar_name}" \
      "''${proxy}/html/''${jar_name}" \
      || die "failed to download applet JAR"

    # Minimal AppletStub that lets us run the iLO applet directly in an
    # AWT Frame, bypassing IcedTea-Web's broken rendering.
    cat >"''${tmpdir}/ILOLauncher.java" <<'JAVA'
    import java.applet.*;
    import java.awt.*;
    import java.awt.event.*;
    import java.net.*;
    import java.util.*;

    public class ILOLauncher extends Frame implements AppletStub, AppletContext {
        private URL codebase, documentbase;
        private Map<String, String> params = new HashMap<>();

        ILOLauncher(URL codebase, URL documentbase, Map<String, String> params) {
            this.codebase = codebase;
            this.documentbase = documentbase;
            this.params = params;
        }

        public boolean isActive() { return true; }
        public URL getDocumentBase() { return documentbase; }
        public URL getCodeBase() { return codebase; }
        public String getParameter(String name) { return params.get(name); }
        public AppletContext getAppletContext() { return this; }
        public void appletResize(int w, int h) {}

        public AudioClip getAudioClip(URL u) { return null; }
        public Image getImage(URL u) { return Toolkit.getDefaultToolkit().getImage(u); }
        public Applet getApplet(String n) { return null; }
        public Enumeration<Applet> getApplets() {
            return Collections.enumeration(Collections.emptyList());
        }
        public void showDocument(URL u) {}
        public void showDocument(URL u, String t) {}
        public void showStatus(String s) {}
        public void setStream(String k, java.io.InputStream v) {}
        public java.io.InputStream getStream(String k) { return null; }
        public Iterator<String> getStreamKeys() { return Collections.emptyIterator(); }

        public static void main(String[] args) throws Exception {
            URL codebase = new URL(System.getProperty("ilo.codebase"));
            URL docbase = new URL(System.getProperty("ilo.documentbase"));

            Map<String, String> params = new HashMap<>();
            for (String arg : args) {
                int eq = arg.indexOf('=');
                if (eq > 0) params.put(arg.substring(0, eq), arg.substring(eq + 1));
            }

            Class<?> cls = Class.forName("com.hp.ilo2.intgapp.intgapp");
            Applet applet = (Applet) cls.newInstance();

            ILOLauncher frame = new ILOLauncher(codebase, docbase, params);
            applet.setStub(frame);

            // The applet creates its own JFrame for the console, so our
            // stub frame can stay hidden.
            frame.setUndecorated(true);
            frame.setSize(0, 0);
            frame.add(applet);
            frame.setVisible(true);
            frame.addWindowListener(new WindowAdapter() {
                public void windowClosing(WindowEvent e) { System.exit(0); }
            });

            applet.init();
            applet.start();
        }
    }
    JAVA

    javac -cp "''${tmpdir}/''${jar_name}" "''${tmpdir}/ILOLauncher.java" \
      || die "failed to compile launcher"

    echo "Launching remote console (proxied via localhost:''${proxy_port})..."
    _JAVA_AWT_WM_NONREPARENTING=1 \
    java -cp "''${tmpdir}:''${tmpdir}/''${jar_name}" \
      -Djavax.net.ssl.trustStore="$truststore" \
      -Djavax.net.ssl.trustStorePassword=changeit \
      -Dilo.codebase="''${proxy}/" \
      -Dilo.documentbase="''${proxy}/html/java_irc.html" \
      ILOLauncher \
      "RCINFO1=''${session_key}" \
      "RCINFOLANG=en" \
      "INFO0=7AC3BDEBC9AC64E85734454B53BB73CE" \
      "INFO1=17988" \
      "INFO2=composite"
  '';
}
