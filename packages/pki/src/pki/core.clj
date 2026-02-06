(ns pki.core
  "State management for PKI: reading/writing JSON, serial tracking, peer registry."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:dynamic *repo-root* nil)
(def ^:dynamic *config-path* nil)
(def ^:dynamic *state-path* nil)

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
  ([{:keys [config state]}]
   (let [root (find-repo-root)]
     (alter-var-root #'*repo-root* (constantly root))
     (alter-var-root #'*config-path* (constantly (or config (str root "/pki/config.json"))))
     (alter-var-root #'*state-path* (constantly (or state (str root "/pki/state.json")))))))

;; --- Config (read-only) ---

(defn read-config
  "Read the PKI config file."
  []
  (when-not (fs/exists? *config-path*)
    (throw (ex-info "Config file not found" {:path *config-path*})))
  (json/parse-string (slurp *config-path*) true))

(defn ca-path
  "Get CA key path for a given type (:host, :user, :initrd)."
  [config ca-type]
  (let [path (get-in config [:ca (keyword ca-type)])]
    (when-not path
      (throw (ex-info "Unknown CA type" {:type ca-type})))
    (str/replace path #"^~" (System/getenv "HOME"))))

;; --- State (read-write) ---

(def empty-state
  {:serial 0
   :peers {}
   :certs {}
   :revoked_serials []})

(defn read-state
  "Read the PKI state file, creating if it doesn't exist."
  []
  (if (fs/exists? *state-path*)
    (json/parse-string (slurp *state-path*) true)
    empty-state))

(defn write-state!
  "Write state to file atomically."
  [state]
  (let [tmp (str *state-path* ".tmp")]
    (spit tmp (json/generate-string state {:pretty true}))
    (fs/move tmp *state-path* {:replace-existing true})))

(defn update-state!
  "Read state, apply function, write back. Returns new state."
  [f & args]
  (let [old-state (read-state)
        new-state (apply f old-state args)]
    (write-state! new-state)
    new-state))

;; --- Serial management ---

(defn current-serial
  "Get current serial number from state."
  [state]
  (:serial state 0))

(defn allocate-serial!
  "Allocate and return the next serial number, updating state."
  []
  (let [state (update-state! (fn [s] (update s :serial inc)))]
    (dec (:serial state))))

(defn allocate-serials!
  "Allocate n serial numbers, returning vector of serials."
  [n]
  (let [start (:serial (read-state))
        serials (vec (range start (+ start n)))]
    (update-state! (fn [s] (update s :serial + n)))
    serials))

;; --- Peer management ---

(defn get-peer
  "Get peer by name, or nil if not found."
  [state peer-name]
  (get-in state [:peers (keyword peer-name)]))

(defn peer-names
  "Get list of all peer names."
  [state]
  (keys (:peers state)))

(defn add-peer!
  "Add a new peer to state."
  [peer-name peer-data]
  (update-state!
   (fn [s]
     (if (get-in s [:peers (keyword peer-name)])
       (throw (ex-info "Peer already exists" {:peer peer-name}))
       (assoc-in s [:peers (keyword peer-name)] peer-data)))))

(defn update-peer!
  "Update an existing peer."
  [peer-name updates]
  (update-state!
   (fn [s]
     (if-not (get-in s [:peers (keyword peer-name)])
       (throw (ex-info "Peer not found" {:peer peer-name}))
       (update-in s [:peers (keyword peer-name)] merge updates)))))

;; --- Certificate tracking ---

(defn record-cert!
  "Record a certificate in state."
  [serial cert-info]
  (update-state!
   (fn [s]
     (assoc-in s [:certs (str serial)] cert-info))))

;; --- Revocation ---

(defn revoke-serials!
  "Add serials to revocation list."
  [serials]
  (update-state!
   (fn [s]
     (update s :revoked_serials
             (fn [rs]
               (->> (concat rs serials)
                    (map #(if (string? %) (parse-long %) %))
                    distinct
                    sort
                    vec))))))

(defn revoked-serials
  "Get list of revoked serials."
  [state]
  (:revoked_serials state []))

;; --- IP allocation ---

(defn next-available-ip
  "Find next available IP suffix in a subnet."
  [state]
  (let [suffixes (->> (:peers state)
                      vals
                      (map :ip4)
                      (keep #(when % (last (str/split % #"\."))))
                      (map parse-long))]
    (if (empty? suffixes)
      1
      (inc (apply max suffixes)))))

(defn make-peer-ips
  "Generate IP addresses for a new peer."
  [suffix]
  {:ip4 (str "10.100.0." suffix)
   :ip6 (str "fd10:100::" (format "%x" suffix))})
