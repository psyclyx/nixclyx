(ns pki.config
  "Read pki-config.json, template interpolation, CA path resolution."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:dynamic *repo-root* nil)
(def ^:dynamic *config-path* nil)

(defn find-repo-root
  "Find git repository root, or current directory if not in a repo."
  []
  (let [{:keys [exit out]} (babashka.process/shell
                            {:out :string :err :string :continue true}
                            "git" "rev-parse" "--show-toplevel")]
    (if (zero? exit)
      (str/trim out)
      ".")))

(defn init-paths!
  "Initialize paths based on repo root. Call once at startup."
  ([]
   (init-paths! {}))
  ([{:keys [config]}]
   (let [root (find-repo-root)]
     (alter-var-root #'*repo-root* (constantly root))
     (alter-var-root #'*config-path* (constantly (or config (str root "/pki-config.json")))))))

;; --- Config reading ---

(defn read-config
  "Read pki-config.json."
  []
  (if (fs/exists? *config-path*)
    (json/parse-string (slurp *config-path*) true)
    (throw (ex-info "pki-config.json not found" {:path *config-path*}))))

(defn get-key-type
  "Get a key type definition by name, or throw if not found."
  [config key-type-name]
  (let [kt (get-in config [:keyTypes (keyword key-type-name)])]
    (when-not kt
      (throw (ex-info (str "Unknown key type: " key-type-name)
                      {:keyType key-type-name
                       :available (keys (:keyTypes config))})))
    kt))

(defn get-ca-config
  "Get CA config by name."
  [config ca-name]
  (let [ca (get-in config [:cas (keyword ca-name)])]
    (when-not ca
      (throw (ex-info (str "Unknown CA: " ca-name)
                      {:ca ca-name
                       :available (keys (:cas config))})))
    ca))

;; --- Template interpolation ---

(defn interpolate
  "Interpolate template variables in a string.
   Variables are {name} patterns. vars is a map of name->value.
   Throws if any unresolved variables remain."
  [template vars]
  (when template
    (let [result (reduce-kv
                  (fn [s k v]
                    (str/replace s (str "{" (name k) "}") (str v)))
                  template
                  vars)
          unresolved (re-seq #"\{[^}]+\}" result)]
      (when (seq unresolved)
        (throw (ex-info (str "Unresolved template variables: " (str/join ", " unresolved))
                        {:template template
                         :vars vars
                         :unresolved unresolved})))
      result)))

(defn resolve-key-type
  "Resolve a key type definition with template variables.
   Returns the key type config with all templates interpolated."
  [config key-type-name vars]
  (let [kt (get-key-type config key-type-name)
        resolve #(interpolate % vars)]
    (cond-> {:name key-type-name
             :method (:method kt)
             :path (resolve (:path kt))}
      (:comment kt) (assoc :comment (resolve (:comment kt)))
      (:owner kt)   (assoc :owner (resolve (:owner kt)))
      (:sign kt)    (assoc :sign
                           (let [sign (:sign kt)]
                             {:certType (:certType sign)
                              :ca (:ca sign)
                              :certPath (resolve (:certPath sign))
                              :principals (resolve (:principals sign))
                              :identity (resolve (:identity sign))})))))

;; --- CA path resolution ---

(defn resolve-ca-path
  "Resolve a CA key path from config.
   Checks environment variable first, then uses default.
   Expands ~ to home directory."
  [config ca-name]
  (let [ca-cfg (get-ca-config config ca-name)
        home (System/getenv "HOME")
        path (or (System/getenv (:env ca-cfg))
                 (:default ca-cfg))]
    (str/replace path #"^~" home)))
