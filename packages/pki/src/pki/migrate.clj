(ns pki.migrate
  "Migration from old state.json to pki-state.json format."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [pki.config :as config]
            [pki.state :as state]
            [clojure.string :as str]))

(defn- read-old-state
  "Read the old state.json file."
  []
  (let [path (str config/*repo-root* "/state.json")]
    (if (fs/exists? path)
      (json/parse-string (slurp path) true)
      (throw (ex-info "state.json not found" {:path path})))))

(defn- infer-cert-key-type
  "Try to infer key type from cert identity string."
  [cert]
  (let [identity (:identity cert "")]
    (cond
      (str/ends-with? identity "-host")   "sshHost"
      (str/ends-with? identity "-initrd") "sshInitrd"
      (str/starts-with? identity "root@") "sshUserRoot"
      :else nil)))

(defn- infer-cert-id
  "Try to infer identity id from cert identity string."
  [cert]
  (let [identity (:identity cert "")]
    (cond
      ;; "fqdn-host" -> extract hostname from fqdn
      (str/ends-with? identity "-host")
      (let [fqdn (subs identity 0 (- (count identity) 5))]
        (first (str/split fqdn #"\.")))

      ;; "fqdn-initrd" -> extract hostname from fqdn
      (str/ends-with? identity "-initrd")
      (let [fqdn (subs identity 0 (- (count identity) 7))]
        (first (str/split fqdn #"\.")))

      ;; "root@fqdn" -> extract hostname
      (str/starts-with? identity "root@")
      (let [fqdn (subs identity 5)]
        (first (str/split fqdn #"\.")))

      :else nil)))

(defn- migrate-peers
  "Migrate old state.peers to new identities format."
  [old-peers]
  (reduce-kv
   (fn [acc peer-name peer-data]
     (let [identity-data
           (cond-> {}
             (:publicKey peer-data)
             (assoc :wireguard {:publicKey (:publicKey peer-data)})

             (:ssh_host peer-data)
             (assoc :sshHost {:publicKey (:ssh_host peer-data)})

             (:ssh_host_initrd peer-data)
             (assoc :sshInitrd {:publicKey (:ssh_host_initrd peer-data)})

             (:ssh_user_root peer-data)
             (assoc :sshUserRoot {:publicKey (:ssh_user_root peer-data)}))]
       (if (seq identity-data)
         (assoc acc peer-name identity-data)
         acc)))
   {}
   old-peers))

(defn- migrate-certs
  "Migrate old certs, adding keyType and id fields where inferrable."
  [old-certs]
  (reduce-kv
   (fn [acc serial cert]
     (let [key-type (infer-cert-key-type cert)
           id (infer-cert-id cert)]
       (assoc acc serial
              (cond-> cert
                key-type (assoc :keyType key-type)
                id (assoc :id id)))))
   {}
   old-certs))

(defn migrate!
  "Migrate old state.json to pki-state.json.
   Also writes pki-config.json if it doesn't exist."
  []
  (let [old-state (read-old-state)
        new-state {:serial (:serial old-state 0)
                   :identities (migrate-peers (:peers old-state {}))
                   :certs (migrate-certs (:certs old-state {}))
                   :revokedSerials (vec (:revoked_serials old-state []))}]

    ;; Write pki-state.json
    (state/write-state! new-state)
    (println (str "Wrote " state/*state-path*))
    (println (str "  serial: " (:serial new-state)))
    (println (str "  identities: " (count (:identities new-state))))
    (println (str "  certs: " (count (:certs new-state))))
    (println (str "  revokedSerials: " (count (:revokedSerials new-state))))

    ;; Write pki-config.json if it doesn't exist
    (when-not (fs/exists? config/*config-path*)
      (let [default-config {:cas {:host {:env "PKI_HOST_CA"
                                         :default "~/.ssh/ca/host_ca"}
                                  :initrd {:env "PKI_INITRD_CA"
                                           :default "~/.ssh/ca/initrd_ca"}
                                  :user {:env "PKI_USER_CA"
                                         :default "~/.ssh/ca/user_ca"}}
                            :keyTypes {:sshHost {:method "host"
                                                 :path "/etc/ssh/ssh_host_ed25519_key"
                                                 :sign {:certType "host"
                                                        :ca "host"
                                                        :certPath "/etc/ssh/ssh_host_ed25519_key-cert.pub"
                                                        :principals "{id},{fqdn}"
                                                        :identity "{fqdn}-host"}}
                                       :sshInitrd {:method "host"
                                                   :path "/etc/secrets/initrd/ssh_host_ed25519_key"
                                                   :sign {:certType "host"
                                                          :ca "initrd"
                                                          :certPath "/etc/secrets/initrd/ssh_host_ed25519_key-cert.pub"
                                                          :principals "{id},{fqdn}"
                                                          :identity "{fqdn}-initrd"}}
                                       :sshUserRoot {:method "user"
                                                     :path "/root/.ssh/id_ed25519"
                                                     :comment "root@{id}"
                                                     :sign {:certType "user"
                                                            :ca "user"
                                                            :certPath "/root/.ssh/id_ed25519-cert.pub"
                                                            :principals "root"
                                                            :identity "root@{fqdn}"}}
                                       :wireguard {:method "wg"
                                                   :path "/etc/secrets/wireguard/private.key"}
                                       :wireguardPsk {:method "wg-psk"
                                                      :path "/etc/secrets/wireguard/psk/{peerId}.key"}}}]
        (spit config/*config-path* (json/generate-string default-config {:pretty true}))
        (println (str "Wrote " config/*config-path*))))

    (println)
    (println "Migration complete. state.json left in place (not modified).")))
