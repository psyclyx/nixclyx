(ns pki.cli
  "CLI entrypoint for PKI management."
  (:require [babashka.cli :as cli]
            [pki.core :as core]
            [pki.sign :as sign]
            [pki.provision :as provision]
            [clojure.string :as str]))

(defn- die! [msg]
  (binding [*out* *err*]
    (println "error:" msg))
  (System/exit 1))

(defn- print-usage! []
  (println "Usage: pki <command> [options]

Commands:
  provision [peer...]   Provision peers (all if none specified)
  check [peer...]       Check mode (no signing)
  add-peer <name>       Add a new peer interactively
  wg-quick <peer>       Generate wg-quick config for a peer
  sign <type>           Sign pubkey from stdin (type: host|user|initrd)
  enroll [options]      Enroll local workstation
  revoke <serial...>    Add serials to revocation list
  generate-krl          Generate KRL files from revoked serials
  status                Show current state summary

Global options:
  --pki PATH      PKI file (default: $REPO_ROOT/pki.json)

Provision options:
  -J, --jump HOST   SSH jump host (e.g. 'user@jumphost')
  -r, --rotate      Rotate keys before provisioning

wg-quick options:
  --gen-key         Generate new keypair (updates state.json with pubkey)
  --private-key K   Use existing private key
  (no key option)   Output with __PRIVATE_KEY__ placeholder for updates

Sign options:
  --principals LIST   Comma-separated principals (required)
  --identity STR      Certificate identity (required)
  --ca PATH           CA key path (overrides default)

Enroll options:
  --principal NAME    User certificate principal (default: current user)
  --identity STR      Certificate identity (default: user@hostname)
  --host              Also enroll local host key"))

;; --- Commands ---

(defn cmd-status [_opts _args]
  (let [state (core/read-state)
        serial (:serial state 0)
        peer-count (count (:peers state))
        cert-count (count (:certs state))
        revoked-count (count (:revoked_serials state))]
    (println "serial:  " serial)
    (println "peers:   " peer-count)
    (println "certs:   " cert-count)
    (println "revoked: " revoked-count)

    (when (pos? peer-count)
      (println)
      (println "peers:")
      (doseq [[name peer] (:peers state)]
        (println (str "  " (clojure.core/name name) ": "
                      (:ip4 peer) " (" (:fqdn peer) ")"))))

    (when (pos? revoked-count)
      (println)
      (println "revoked serials:")
      (doseq [s (:revoked_serials state)]
        (println (str "  " s))))))

(defn cmd-provision [opts args]
  (provision/provision-peers!
   {:peer-names args
    :check false
    :rotate (:rotate opts)
    :jump (:jump opts)}))

(defn cmd-check [opts args]
  (provision/provision-peers!
   {:peer-names args
    :check true
    :jump (:jump opts)}))

(defn cmd-add-peer [_opts args]
  (when (empty? args)
    (die! "add-peer requires a peer name"))

  (let [peer-name (first args)
        config (core/read-config)
        sites (keys (get-in config [:wireguard :sites]))]

    (println "Available sites:" (str/join ", " (map name sites)))
    (print "Site: ")
    (flush)
    (let [site (str/trim (read-line))]
      (when (str/blank? site)
        (die! "Site required"))
      (when-not ((set (map name sites)) site)
        (die! (str "Unknown site: " site)))

      (let [state (core/read-state)
            suffix (core/next-available-ip state site)
            ips (core/make-peer-ips site suffix)]

        (print (str "FQDN for " peer-name " (e.g., device.roam.psyclyx.net): "))
        (flush)
        (let [fqdn (str/trim (read-line))]
          (when (str/blank? fqdn)
            (die! "FQDN required"))

          (print "WireGuard public key (or empty to set later): ")
          (flush)
          (let [pubkey (str/trim (read-line))
                peer-data (merge ips
                                 {:site site
                                  :fqdn fqdn
                                  :publicKey (when-not (str/blank? pubkey) pubkey)
                                  :ssh_host nil
                                  :ssh_host_initrd nil
                                  :ssh_user_root nil})]
            (core/add-peer! peer-name peer-data)
            (println (str "Added peer " peer-name " to site " site ": " (:ip4 ips) " / " (:ip6 ips)))))))))

(defn cmd-sign [opts args]
  (when (empty? args)
    (die! "sign requires a type (host|user|initrd)"))

  (let [sign-type (keyword (first args))
        _ (when-not (#{:host :user :initrd} sign-type)
            (die! (str "Unknown sign type: " (first args) " (use host|user|initrd)")))
        principals (:principals opts)
        identity (:identity opts)
        _ (when-not principals (die! "--principals required"))
        _ (when-not identity (die! "--identity required"))
        pubkey (str/trim (slurp *in*))]

    (when (str/blank? pubkey)
      (die! "No public key provided on stdin"))

    (let [result (sign/sign-key!
                  {:ca-type sign-type
                   :ca-path (:ca opts)
                   :principals principals
                   :identity identity
                   :pubkey pubkey})]
      (println (:cert result))
      (binding [*out* *err*]
        (println (str "Signed with serial " (:serial result)))))))

(defn cmd-revoke [_opts args]
  (when (empty? args)
    (die! "revoke requires at least one serial number"))

  (let [serials (map parse-long args)]
    (core/revoke-serials! serials)
    (println (str "Revoked serials: " (str/join ", " serials)))))

(defn cmd-generate-krl [_opts _args]
  (let [state (core/read-state)
        revoked (core/revoked-serials state)]
    (if (empty? revoked)
      (println "No revoked serials, nothing to do")
      (let [config (core/read-config)
            version (:serial state)
            pki-dir core/*repo-root*]
        (doseq [ca-type [:host :initrd :user]]
          (let [ca-serials (->> (:certs state)
                                (filter (fn [[_ cert]] (= (name ca-type) (:ca cert))))
                                (map (fn [[s _]] (parse-long s)))
                                (filter (set revoked)))]
            (if (empty? ca-serials)
              (println (str "No revoked serials for " (name ca-type) " CA, skipping"))
              (let [ca-key (core/ca-path config ca-type)
                    krl-path (str pki-dir "/krl-" (name ca-type) ".krl")
                    spec-content (str/join "\n" (map #(str "serial: " %) ca-serials))
                    spec-file (str (babashka.fs/create-temp-file) ".spec")]
                (spit spec-file spec-content)
                (pki.shell/run! "ssh-keygen" "-k" "-f" krl-path "-s" ca-key "-z" (str version) spec-file)
                (babashka.fs/delete spec-file)
                (println (str "Wrote " krl-path " (version " version ")"))))))))))

(defn cmd-enroll [opts _args]
  (let [current-user (System/getenv "USER")
        current-hostname (str/trim (pki.shell/run-out! "hostname" "-s"))
        current-fqdn (str/trim (pki.shell/run-out! "hostname" "-f"))
        principal (or (:principal opts) current-user)
        identity (or (:identity opts) (str current-user "@" current-fqdn))
        config (core/read-config)]

    ;; Enroll user key
    (println "==> Ensuring user key")
    (let [user-pub (pki.shell/run-out! "ensure-key" "user" "--std" "self"
                                       "--comment" (str current-user "@" current-hostname))
          serial (core/allocate-serial!)]
      (println (str "==> Signing user key (serial " serial ")"))
      (let [result (sign/sign-key! {:ca-type :user
                                    :principals principal
                                    :identity identity
                                    :serial serial
                                    :pubkey user-pub})
            cert-path (str (System/getenv "HOME") "/.ssh/id_ed25519-cert.pub")]
        (spit cert-path (:cert result))
        (println (str "==> Wrote " cert-path))))

    ;; Optionally enroll host key
    (when (:host opts)
      (println "==> Ensuring host key")
      (let [host-pub (pki.shell/run-out! "ensure-key" "host" "--std" "sshd")
            serial (core/allocate-serial!)]
        (println (str "==> Signing host key (serial " serial ")"))
        (let [result (sign/sign-key! {:ca-type :host
                                      :principals (str current-hostname "," current-fqdn)
                                      :identity (str current-fqdn "-host")
                                      :serial serial
                                      :pubkey host-pub})
              cert-path "/etc/ssh/ssh_host_ed25519_key-cert.pub"]
          (spit cert-path (:cert result))
          (println (str "==> Wrote " cert-path)))))

    (println (str "==> Enroll complete (next serial: " (:serial (core/read-state)) ")"))))

(defn cmd-wg-quick [opts args]
  (when (empty? args)
    (die! "wg-quick requires a peer name"))

  (let [peer-name (first args)
        state (core/read-state)
        peer (core/get-peer state peer-name)
        _ (when-not peer (die! (str "Peer not found: " peer-name)))

        config (core/read-config)
        wg-config (:wireguard config)
        root-hub-name (:rootHub wg-config)
        root-hub (core/get-peer state root-hub-name)

        ;; Determine which hub this peer connects to
        peer-site (get-in wg-config [:sites (keyword (:site peer))])
        site-hub (:hub peer-site)
        hub-name (or site-hub root-hub-name)
        hub (core/get-peer state hub-name)

        ;; Get or generate private key, or use placeholder
        private-key (cond
                      (:private-key opts) (:private-key opts)
                      (:gen-key opts) (str/trim (pki.shell/run-out! "wg" "genkey"))
                      :else "__PRIVATE_KEY__")

        ;; Calculate public key and update state if generating
        _ (when (:gen-key opts)
            (let [public-key (str/trim (:out (pki.shell/run!
                                               {:in private-key}
                                               "wg" "pubkey")))]
              (core/update-peer! peer-name {:publicKey public-key})
              (binding [*out* *err*]
                (println "Updated" peer-name "publicKey in state.json"))))

        ;; Build AllowedIPs - all subnets
        all-subnets (->> (:sites wg-config)
                         vals
                         (mapcat (fn [s] [(:subnet4 s) (:subnet6 s)])))

        ;; Hub endpoint
        hub-endpoint (or (:endpoint hub)
                         (die! (str "Hub " hub-name " has no endpoint")))

        ;; Generate config
        wg-quick-conf (str "[Interface]\n"
                          "PrivateKey = " private-key "\n"
                          "Address = " (:ip4 peer) "/24, " (:ip6 peer) "/64\n"
                          "DNS = " (:ip4 root-hub) "\n"
                          "\n"
                          "[Peer]\n"
                          "PublicKey = " (or (:publicKey hub) "<HUB_PUBLIC_KEY>") "\n"
                          "AllowedIPs = " (str/join ", " all-subnets) "\n"
                          "Endpoint = " hub-endpoint ":" (:port wg-config) "\n"
                          "PersistentKeepalive = 25\n")]

    (println wg-quick-conf)

    ;; If using placeholder, print update instructions to stderr
    (when (= private-key "__PRIVATE_KEY__")
      (binding [*out* *err*]
        (println)
        (println "# Update existing config (preserves private key):")
        (println "# KEY=$(grep PrivateKey /etc/wireguard/wg0.conf | awk '{print $3}')")
        (println "# <above output> | sed \"s/__PRIVATE_KEY__/$KEY/\" > /etc/wireguard/wg0.conf")
        (println "# wg syncconf wg0 <(wg-quick strip /etc/wireguard/wg0.conf)")))))

;; --- Main ---

(def cli-spec
  {:pki {:alias :p :desc "PKI file path (default: $REPO_ROOT/pki.json)"}
   :principals {:alias :n :desc "Comma-separated principals"}
   :identity {:alias :i :desc "Certificate identity"}
   :ca {:desc "CA key path"}
   :principal {:desc "User principal for enroll"}
   :host {:alias :h :coerce :boolean :desc "Also enroll host key"}
   :rotate {:alias :r :coerce :boolean :desc "Rotate keys before provisioning"}
   :jump {:alias :J :desc "SSH jump host (passed to -J)"}
   :gen-key {:coerce :boolean :desc "Generate new WireGuard keypair"}
   :private-key {:desc "Existing WireGuard private key"}
   :help {:coerce :boolean :desc "Show help"}})

(defn -main [& args]
  (let [{:keys [opts args]} (cli/parse-args args {:spec cli-spec})
        [cmd & cmd-args] args]

    ;; Initialize paths
    (core/init-paths! {:pki (:pki opts)})

    (when (or (:help opts) (nil? cmd))
      (print-usage!)
      (System/exit (if (:help opts) 0 1)))

    (case cmd
      "status" (cmd-status opts cmd-args)
      "provision" (cmd-provision opts cmd-args)
      "check" (cmd-check opts cmd-args)
      "add-peer" (cmd-add-peer opts cmd-args)
      "sign" (cmd-sign opts cmd-args)
      "revoke" (cmd-revoke opts cmd-args)
      "generate-krl" (cmd-generate-krl opts cmd-args)
      "enroll" (cmd-enroll opts cmd-args)
      "wg-quick" (cmd-wg-quick opts cmd-args)
      (die! (str "Unknown command: " cmd)))))

;; Entry point when run directly
(when (= *file* (System/getProperty "babashka.file"))
  (apply -main *command-line-args*))
