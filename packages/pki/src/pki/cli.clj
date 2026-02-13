(ns pki.cli
  "CLI entrypoint for PKI management."
  (:require [babashka.cli :as cli]
            [pki.config :as config]
            [pki.state :as state]
            [pki.sign :as sign]
            [pki.ensure :as ensure]
            [pki.target :as target]
            [pki.migrate :as migrate]
            [pki.shell :as sh]
            [clojure.string :as str]))

(defn- die! [msg]
  (binding [*out* *err*]
    (println "error:" msg))
  (System/exit 1))

(defn- print-usage! []
  (println "Usage: pki <command> [options]

Commands:
  ensure <keyTypes> <id> [options]   Generate, sign, deploy, record
  check  <keyTypes> <id> [options]   Check key existence on target
  sign   <type> [options]            Sign pubkey from stdin (raw)
  revoke <serial...>                 Add serials to revocation list
  krl                                Generate KRL files
  status                             Show state summary
  migrate                            Migrate old state.json

Target options (ensure/check):
  --ssh USER@HOST    SSH target
  -J, --jump HOST    SSH jump host
  -p, --port PORT    SSH port
  --local            Local target (default when no --ssh)
  --root PATH        Filesystem root prefix

Ensure options:
  --rotate           Delete and regenerate keys
  --force            Don't prompt before overwriting files
  --var KEY=VAL      Template variable (repeatable)

Sign options:
  --principals LIST  Comma-separated principals (required)
  --identity STR     Certificate identity (required)
  --ca PATH          CA key path
  --ca-type TYPE     host or user (default: host)

CA keys (override with env vars):
  ~/.ssh/ca/host_ca      (or PKI_HOST_CA)
  ~/.ssh/ca/user_ca      (or PKI_USER_CA)
  ~/.ssh/ca/initrd_ca    (or PKI_INITRD_CA)"))

;; --- Helper: parse --var KEY=VAL into a map ---

(defn- parse-vars
  "Parse --var options into a map. Accepts a single string or vector of strings."
  [var-opt]
  (let [vars (cond
               (nil? var-opt) []
               (string? var-opt) [var-opt]
               (sequential? var-opt) var-opt
               :else [var-opt])]
    (reduce (fn [m v]
              (let [[k val] (str/split (str v) #"=" 2)]
                (when-not val
                  (throw (ex-info (str "Invalid --var format (expected KEY=VAL): " v)
                                  {:var v})))
                (assoc m (keyword k) val)))
            {}
            vars)))

;; --- Commands ---

(defn cmd-status [_opts _args]
  (let [st (state/read-state)
        id-count (count (:identities st))
        cert-count (count (:certs st))
        revoked-count (count (state/revoked-serials st))]
    (println "serial:     " (:serial st 0))
    (println "identities: " id-count)
    (println "certs:      " cert-count)
    (println "revoked:    " revoked-count)

    (when (pos? id-count)
      (println)
      (println "identities:")
      (doseq [[id-name id-data] (:identities st)]
        (let [key-types (keys id-data)
              summary (str/join ", " (map name key-types))]
          (println (str "  " (name id-name) ": " summary)))))

    (when (pos? revoked-count)
      (println)
      (println "revoked serials:")
      (doseq [s (state/revoked-serials st)]
        (println (str "  " s))))))

(defn cmd-ensure [opts args]
  (when (< (count args) 2)
    (die! "ensure requires <keyTypes> and <id>"))

  (let [key-types (first args)
        id (second args)
        vars (parse-vars (:var opts))
        tgt (target/make-target opts)]
    (ensure/ensure! {:key-types key-types
                     :id id
                     :vars vars
                     :target tgt
                     :rotate (:rotate opts)
                     :force (:force opts)
                     :root (:root opts)})))

(defn cmd-check [opts args]
  (when (< (count args) 2)
    (die! "check requires <keyTypes> and <id>"))

  (let [key-types (first args)
        id (second args)
        vars (parse-vars (:var opts))
        tgt (target/make-target opts)]
    (ensure/check! {:key-types key-types
                    :id id
                    :vars vars
                    :target tgt
                    :root (:root opts)})))

(defn cmd-sign [opts args]
  (when (empty? args)
    (die! "sign requires a type (host|user)"))

  (let [sign-type (keyword (first args))
        _ (when-not (#{:host :user} sign-type)
            (die! (str "Unknown sign type: " (first args) " (use host|user)")))
        principals (:principals opts)
        identity (:identity opts)
        _ (when-not principals (die! "--principals required"))
        _ (when-not identity (die! "--identity required"))
        pubkey (str/trim (slurp *in*))]

    (when (str/blank? pubkey)
      (die! "No public key provided on stdin"))

    (let [ca-path (or (:ca opts)
                      (config/resolve-ca-path (config/read-config)
                                              (name (or (:ca-type opts) sign-type))))
          serial (state/allocate-serial!)
          result (sign/sign-key!
                   {:ca-type sign-type
                    :ca-path ca-path
                    :principals principals
                    :identity identity
                    :serial serial
                    :pubkey pubkey})]

      ;; Record cert in state
      (state/record-cert! serial
                          {:id "manual"
                           :keyType (name sign-type)
                           :ca (name sign-type)
                           :identity identity
                           :principals principals
                           :issuedAt (.toString (java.time.Instant/now))})

      (println (:cert result))
      (binding [*out* *err*]
        (println (str "Signed with serial " serial))))))

(defn cmd-revoke [_opts args]
  (when (empty? args)
    (die! "revoke requires at least one serial number"))

  (let [serials (map parse-long args)]
    (state/revoke-serials! serials)
    (println (str "Revoked serials: " (str/join ", " serials)))))

(defn cmd-krl [_opts _args]
  (let [st (state/read-state)
        revoked (state/revoked-serials st)]
    (if (empty? revoked)
      (println "No revoked serials, nothing to do")
      (let [version (:serial st)
            pki-config (config/read-config)
            pki-dir config/*repo-root*]
        (doseq [ca-name (keys (:cas pki-config))]
          (let [ca-serials (->> (:certs st)
                                (filter (fn [[_ cert]] (= (name ca-name) (:ca cert))))
                                (map (fn [[s _]] (parse-long s)))
                                (filter (set revoked)))]
            (if (empty? ca-serials)
              (println (str "No revoked serials for " (name ca-name) " CA, skipping"))
              (let [ca-key (config/resolve-ca-path pki-config (name ca-name))
                    krl-path (str pki-dir "/krl-" (name ca-name) ".krl")
                    spec-content (str/join "\n" (map #(str "serial: " %) ca-serials))
                    spec-file (str (babashka.fs/create-temp-file) ".spec")]
                (spit spec-file spec-content)
                (sh/run! "ssh-keygen" "-k" "-f" krl-path "-s" ca-key "-z" (str version) spec-file)
                (babashka.fs/delete spec-file)
                (println (str "Wrote " krl-path " (version " version ")"))))))))))

(defn cmd-migrate [_opts _args]
  (migrate/migrate!))

;; --- Main ---

(def cli-spec
  {:principals {:alias :n :desc "Comma-separated principals"}
   :identity {:alias :i :desc "Certificate identity"}
   :ca {:desc "CA key path (overrides env var)"}
   :ca-type {:desc "Certificate type for sign (host or user)"}
   :rotate {:alias :r :coerce :boolean :desc "Rotate keys"}
   :force {:alias :f :coerce :boolean :desc "Don't prompt before overwriting"}
   :ssh {:desc "SSH target (USER@HOST)"}
   :jump {:alias :J :desc "SSH jump host"}
   :port {:alias :p :coerce :int :desc "SSH port"}
   :local {:coerce :boolean :desc "Local target (default)"}
   :root {:desc "Filesystem root prefix"}
   :var {:coerce [] :desc "Template variable (KEY=VAL, repeatable)"}
   :help {:coerce :boolean :desc "Show help"}})

(defn -main [& args]
  (let [{:keys [opts args]} (cli/parse-args args {:spec cli-spec})
        [cmd & cmd-args] args]

    ;; Initialize paths (finds repo root automatically)
    (config/init-paths!)
    (state/init-paths!)

    (when (or (:help opts) (nil? cmd))
      (print-usage!)
      (System/exit (if (:help opts) 0 1)))

    (case cmd
      "status" (cmd-status opts cmd-args)
      "ensure" (cmd-ensure opts cmd-args)
      "check" (cmd-check opts cmd-args)
      "sign" (cmd-sign opts cmd-args)
      "revoke" (cmd-revoke opts cmd-args)
      "krl" (cmd-krl opts cmd-args)
      "migrate" (cmd-migrate opts cmd-args)
      (die! (str "Unknown command: " cmd)))))

;; Entry point when run directly
(when (= *file* (System/getProperty "babashka.file"))
  (apply -main *command-line-args*))
