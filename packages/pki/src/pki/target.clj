(ns pki.target
  "Target abstraction: local and SSH targets for running commands and writing files."
  (:require [babashka.process :as p]
            [babashka.fs :as fs]
            [clojure.string :as str]
            [pki.shell :as sh]))

;; A target is a map with:
;;   :label    - string for user-facing output
;;   :run-cmd! - (fn [opts & args] -> {:out :err :exit})
;;   :write!   - (fn [path content] -> nil)

;; --- Local target ---

(defn local-target
  "Create a local target. Commands run locally, files written directly.
   Options:
     :root - filesystem root prefix (prepended to paths)"
  [{:keys [root]}]
  (let [prefix (or root "")]
    {:label (if (seq root)
              (str "local:" root)
              "local")
     :run-cmd! (fn [opts & args]
                 (apply sh/run! opts args))
     :write! (fn [path content]
               (let [full-path (str prefix path)]
                 (fs/create-dirs (fs/parent full-path))
                 (spit full-path content)))}))

;; --- SSH target ---

(defn- ssh-opts
  "Build SSH option args from jump/port."
  [{:keys [jump port]}]
  (concat
   (when jump ["-J" jump])
   (when port ["-p" (str port)])))

(defn- ensure-key-pushed!
  "Lazily push ensure-key to remote on first call. Returns the remote path."
  [dest opts pushed-atom]
  (when-not @pushed-atom
    (let [bin-path (str/trim (:out (sh/run! "which" "ensure-key")))
          store-path (-> bin-path
                         (str/split #"/")
                         butlast
                         butlast
                         (#(str/join "/" %)))
          dest-str (str (:user opts "root") "@" dest)
          ssh-opt-str (str/join " " (ssh-opts opts))
          env (when (seq ssh-opt-str) {"NIX_SSHOPTS" ssh-opt-str})]
      (sh/run! {:extra-env env} "nix-copy-closure" "--to" dest-str store-path)
      (reset! pushed-atom bin-path)))
  @pushed-atom)

(defn ssh-target
  "Create an SSH target.
   Options:
     :host - SSH host (required)
     :user - SSH user (default: root)
     :jump - jump host for -J
     :port - SSH port for -p
     :root - filesystem root prefix on remote"
  [{:keys [host user jump port root] :or {user "root"}}]
  (let [dest host
        conn-opts {:jump jump :port port :user user}
        prefix (or root "")
        pushed-atom (atom nil)
        dest-str (str user "@" host)]
    {:label (str "ssh:" dest-str)
     :run-cmd! (fn [opts & args]
                 ;; If the command is ensure-key, push it and rewrite to full path
                 (let [args (if (= (first args) "ensure-key")
                              (let [bin-path (ensure-key-pushed! host conn-opts pushed-atom)]
                                (cons bin-path (rest args)))
                              args)
                       ssh-args (concat ["ssh"] (ssh-opts conn-opts) [dest-str]
                                        (map str args))]
                   (apply sh/run! opts ssh-args)))
     :write! (fn [path content]
               (let [full-path (str prefix path)
                     ssh-args (concat ["ssh"] (ssh-opts conn-opts)
                                      [dest-str
                                       (str "mkdir -p \"$(dirname '" full-path "')\" && cat > '" full-path "'")])]
                 (apply p/shell {:in content :out :string :err :string} ssh-args)))}))

;; --- Target construction from CLI opts ---

(defn make-target
  "Construct a target from CLI options.
   Options:
     :ssh   - USER@HOST string for SSH target
     :jump  - SSH jump host
     :port  - SSH port
     :root  - filesystem root prefix
     :local - force local target (default when no --ssh)"
  [{:keys [ssh jump port root]}]
  (if ssh
    (let [[user host] (if (str/includes? ssh "@")
                        (str/split ssh #"@" 2)
                        ["root" ssh])]
      (ssh-target {:host host :user user :jump jump :port port :root root}))
    (local-target {:root root})))

;; --- Target operations ---

(defn run-cmd!
  "Run a command on target. Returns {:out :err :exit}."
  [target opts & args]
  (apply (:run-cmd! target) opts args))

(defn write-file!
  "Write content to a path on target."
  [target path content]
  ((:write! target) path content))

(defn file-exists?
  "Check if a file exists on target."
  [target path]
  (let [result (run-cmd! target {:continue true} "test" "-f" path)]
    (zero? (:exit result))))
