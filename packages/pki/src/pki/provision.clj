(ns pki.provision
  "Remote host provisioning: key generation, signing, deployment."
  (:require [pki.core :as core]
            [pki.sign :as sign]
            [pki.shell :as sh]
            [clojure.string :as str]))

(defn- get-ensure-key-path
  "Get the path to ensure-key in the nix store."
  []
  (sh/run-out! "which" "ensure-key"))

(defn- get-ensure-key-store-path
  "Get the nix store path for ensure-key (for nix-copy-closure)."
  []
  (let [bin-path (get-ensure-key-path)]
    ;; /nix/store/xxx-ensure-key/bin/ensure-key -> /nix/store/xxx-ensure-key
    (-> bin-path
        (str/split #"/")
        butlast
        butlast
        (#(str/join "/" %)))))

(defn- remote-ensure-key!
  "Run ensure-key on remote host, return pubkey."
  [dest ensure-key-path key-type std-name & {:keys [comment check rotate]}]
  (let [args (cond-> [ensure-key-path key-type "--std" std-name]
               comment (concat ["--comment" comment])
               check   (conj "--check")
               rotate  (conj "--rotate"))
        result (apply sh/ssh! dest (concat args [{:continue true}]))]
    (when (and (not check) (not (zero? (:exit result))))
      (throw (ex-info "Failed to ensure key on remote"
                      {:dest dest :type key-type :std std-name :err (:err result)})))
    (str/trim (:out result))))

(defn- push-cert!
  "Push certificate content to remote host."
  [dest cert remote-path]
  (sh/pipe-to-ssh! cert dest (str "cat > " remote-path)))

(defn provision-peer!
  "Provision a peer: generate keys, sign, deploy certs.
   Options:
     :peer-name - peer name (required)
     :check     - check only, don't generate or sign
     :rotate    - rotate all keys before generating
   Returns map of provisioned data."
  [{:keys [peer-name check rotate]}]
  (let [state (core/read-state)
        peer (core/get-peer state peer-name)
        _ (when-not peer
            (throw (ex-info "Peer not found" {:peer peer-name})))

        fqdn (:fqdn peer)
        endpoint (:endpoint peer)

        ;; Determine SSH destination
        dest (if endpoint
               (str "root@" endpoint)
               (str "root@" fqdn))

        ensure-key-path (get-ensure-key-path)
        _ (when-not check
            (println "Copying ensure-key to" dest)
            (sh/nix-copy-closure! dest (get-ensure-key-store-path)))

        _ (println (if check "Checking" "Generating") "keys on" dest)

        ;; Get/generate keys on remote
        host-pub (remote-ensure-key! dest ensure-key-path "host" "sshd"
                                     :check check :rotate rotate)
        initrd-pub (remote-ensure-key! dest ensure-key-path "host" "initrd"
                                       :check check :rotate rotate)
        root-pub (remote-ensure-key! dest ensure-key-path "user" "root"
                                     :comment (str "root@" peer-name)
                                     :check check :rotate rotate)
        wg-pub (remote-ensure-key! dest ensure-key-path "wg" "wg"
                                   :check check :rotate rotate)]

    (if check
      ;; Check mode: just return pubkeys
      {:peer peer-name
       :fqdn fqdn
       :pubkeys {:ssh_host host-pub
                 :ssh_host_initrd initrd-pub
                 :ssh_user_root root-pub
                 :wireguard wg-pub}}

      ;; Full provision: sign and deploy
      (let [config (core/read-config)
            [s1 s2 s3] (core/allocate-serials! 3)

            _ (println "Signing keys (serials" s1 s2 s3 ")")

            host-cert (sign/sign-host-key!
                       {:hostname peer-name :fqdn fqdn :pubkey host-pub
                        :serial s1 :ca-path (core/ca-path config :host)})

            initrd-cert (sign/sign-initrd-key!
                         {:hostname peer-name :fqdn fqdn :pubkey initrd-pub
                          :serial s2 :ca-path (core/ca-path config :initrd)})

            user-cert (sign/sign-user-key!
                       {:principal "root" :identity (str "root@" fqdn)
                        :pubkey root-pub :serial s3
                        :ca-path (core/ca-path config :user)})

            _ (println "Deploying certs to" dest)
            _ (push-cert! dest (:cert host-cert)
                          "/etc/ssh/ssh_host_ed25519_key-cert.pub")
            _ (push-cert! dest (:cert initrd-cert)
                          "/etc/secrets/initrd/ssh_host_ed25519_key-cert.pub")
            _ (push-cert! dest (:cert user-cert)
                          "/root/.ssh/id_ed25519-cert.pub")

            ;; Update peer in state
            _ (core/update-peer! peer-name
                                 {:publicKey wg-pub
                                  :ssh_host host-pub
                                  :ssh_host_initrd initrd-pub
                                  :ssh_user_root root-pub})]

        (println "Done. Next serial:" (:serial (core/read-state)))

        {:peer peer-name
         :fqdn fqdn
         :pubkeys {:ssh_host host-pub
                   :ssh_host_initrd initrd-pub
                   :ssh_user_root root-pub
                   :wireguard wg-pub}
         :serials {:ssh_host s1
                   :ssh_host_initrd s2
                   :ssh_user_root s3}}))))

(defn provision-peers!
  "Provision multiple peers. If peer-names is empty, provision all."
  [{:keys [peer-names check rotate]}]
  (let [state (core/read-state)
        names (if (seq peer-names)
                peer-names
                (map name (core/peer-names state)))]
    (doseq [peer-name names]
      (println "==>" (if check "Checking" "Provisioning") peer-name)
      (try
        (provision-peer! {:peer-name peer-name :check check :rotate rotate})
        (catch Exception e
          (println "Error provisioning" peer-name ":" (ex-message e)))))))
