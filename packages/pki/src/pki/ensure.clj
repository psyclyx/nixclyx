(ns pki.ensure
  "The ensure operation: generate keys, sign certs, deploy, record state."
  (:require [pki.config :as config]
            [pki.state :as state]
            [pki.sign :as sign]
            [pki.target :as target]
            [clojure.string :as str]))

(defn- print-step
  "Print a step indicator."
  ([label msg]
   (println (str "==> " label ": " msg)))
  ([target-label label msg]
   (println (str "==> [" target-label "] " label ": " msg))))

(defn- ensure-key-on-target!
  "Run ensure-key on target to generate or check a key.
   Returns the public key string."
  [target resolved-kt {:keys [check rotate root]}]
  (let [method (:method resolved-kt)
        path (:path resolved-kt)
        args (cond-> ["ensure-key" method "--path" path]
               root    (concat ["--root" root])
               (:comment resolved-kt) (concat ["--comment" (:comment resolved-kt)])
               check   (concat ["--check"])
               rotate  (concat ["--rotate"]))
        result (apply target/run-cmd! target {:continue true} args)]
    (when (and (not check) (not (zero? (:exit result))))
      (throw (ex-info (str "Failed to ensure key: " method " at " path)
                      {:method method :path path :exit (:exit result)
                       :err (:err result)})))
    (str/trim (:out result))))

(defn- prompt-overwrite
  "Prompt user before overwriting a file. Returns true if should proceed."
  [path force]
  (if force
    true
    (do
      (print (str "    file exists. overwrite? [y/N] "))
      (flush)
      (let [answer (str/trim (or (read-line) ""))]
        (= (str/lower-case answer) "y")))))

(defn- record-and-print!
  "Record cert in state and print confirmation."
  [id kt-name serial sign-cfg]
  (state/record-cert-serial! id kt-name serial)
  (state/record-cert! serial
                      {:id id
                       :keyType kt-name
                       :ca (:ca sign-cfg)
                       :identity (:identity sign-cfg)
                       :principals (:principals sign-cfg)
                       :issuedAt (.toString (java.time.Instant/now))})
  (println (str "==> " kt-name ": recorded in pki-state.json")))

(defn- chown-key-files!
  "Chown key files and parent directory to the specified owner on target."
  [target resolved-kt root]
  (when-let [owner (:owner resolved-kt)]
    (let [prefix (or root "")
          key-path (str prefix (:path resolved-kt))
          dir (str key-path "/..")]
      (print-step (:label target) (:name resolved-kt)
                  (str "chown " owner " " key-path " (and related files)"))
      (target/run-cmd! target {:continue true}
                        "sh" "-c"
                        (str "chown " owner " "
                             "'" key-path "' "
                             "'" key-path ".pub' "
                             "'" key-path "-cert.pub' "
                             "2>/dev/null; "
                             "chown " owner " "
                             "\"$(dirname '" key-path "')\"")))))

(defn ensure-key-type!
  "Ensure a single key type for an identity on a target.
   Options:
     :check   - check only, don't generate or sign
     :rotate  - delete and regenerate keys
     :force   - don't prompt before overwriting cert files
     :root    - filesystem root prefix
   Returns {:publicKey <key> :certSerial <serial>} or {:publicKey <key>}."
  [pki-config target resolved-kt id {:keys [check rotate force root]}]
  (let [kt-name (:name resolved-kt)
        target-label (:label target)]

    ;; Step 1: ensure key exists on target
    (print-step target-label kt-name
                (str (if check "checking " "ensuring ") (:path resolved-kt)))
    (let [pubkey (ensure-key-on-target! target resolved-kt
                                        {:check check :rotate rotate :root root})]

      (when (seq pubkey)
        (println (str "    key " (if check "exists" "ok") ": "
                      (if (> (count pubkey) 60)
                        (str (subs pubkey 0 57) "...")
                        pubkey))))

      (if check
        ;; Check mode: just return what we found
        (when (seq pubkey) {:publicKey pubkey})

        ;; Full ensure: sign and deploy
        (let [result {:publicKey pubkey}]
          ;; Record public key in state
          (when (seq pubkey)
            (state/record-key! id kt-name pubkey))

          ;; Sign if sign config is present
          (let [final-result
                (if-let [sign-cfg (:sign resolved-kt)]
                  (let [serial (state/allocate-serial!)
                        ca-path (config/resolve-ca-path pki-config (:ca sign-cfg))

                        _ (print-step kt-name
                                      (str "signing certificate (serial " serial ", ca: " (:ca sign-cfg) ")"))
                        _ (println (str "    principals: " (:principals sign-cfg)))
                        _ (println (str "    identity: " (:identity sign-cfg)))

                        cert-result (sign/sign-key!
                                     {:ca-type (keyword (:certType sign-cfg))
                                      :ca-path ca-path
                                      :principals (:principals sign-cfg)
                                      :identity (:identity sign-cfg)
                                      :serial serial
                                      :pubkey pubkey})
                        cert (:cert cert-result)
                        cert-path (:certPath sign-cfg)]

                    ;; Check if cert exists on target and prompt
                    (print-step target-label kt-name
                                (str "deploying cert to " cert-path))
                    (let [exists (target/file-exists? target cert-path)
                          should-deploy (or (not exists) (prompt-overwrite cert-path force))]

                      (if should-deploy
                        ;; Deploy cert
                        (target/write-file! target cert-path cert)
                        ;; Skipped
                        (println "    skipped."))

                      ;; Record cert regardless of whether we deployed
                      (record-and-print! id kt-name serial sign-cfg)
                      (assoc result :certSerial serial)))

                  ;; No sign config, just record key
                  (do
                    (println (str "==> " kt-name ": recorded in pki-state.json"))
                    result))]

            ;; Fix ownership if owner is specified
            (chown-key-files! target resolved-kt root)

            final-result))))))

(defn ensure!
  "Ensure multiple key types for an identity.
   Options:
     :key-types - comma-separated key type names
     :id        - identity ID
     :vars      - template variables map
     :target    - target map
     :check     - check only mode
     :rotate    - rotate keys
     :force     - don't prompt
     :root      - filesystem root prefix"
  [{:keys [key-types id vars target check rotate force root]}]
  (let [pki-config (config/read-config)
        kt-names (str/split key-types #",")
        ;; Merge id into vars
        all-vars (assoc vars :id id)]

    ;; Validate and resolve all key types first (fail early)
    (let [resolved-kts (mapv #(config/resolve-key-type pki-config % all-vars) kt-names)]

      ;; Process each key type sequentially
      (doseq [resolved-kt resolved-kts]
        (ensure-key-type! pki-config target resolved-kt id
                          {:check check :rotate rotate :force force :root root})))))

(defn check!
  "Check key types for an identity (alias for ensure with :check true)."
  [opts]
  (ensure! (assoc opts :check true)))
