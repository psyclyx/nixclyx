(ns pki.core
  "State management for PKI: reading/writing network config and state."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:dynamic *repo-root* nil)
(def ^:dynamic *network-path* nil)
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
  ([{:keys [network state]}]
   (let [root (find-repo-root)]
     (alter-var-root #'*repo-root* (constantly root))
     (alter-var-root #'*network-path* (constantly (or network (str root "/network.json"))))
     (alter-var-root #'*state-path* (constantly (or state (str root "/state.json")))))))

;; --- Network config (read-only from CLI perspective) ---

(def empty-network
  {:port 51820
   :rootHub nil
   :sites {}
   :peers {}})

(defn read-network
  "Read network config."
  []
  (if (fs/exists? *network-path*)
    (json/parse-string (slurp *network-path*) true)
    empty-network))

(defn write-network!
  "Write network config atomically."
  [data]
  (let [tmp (str *network-path* ".tmp")]
    (spit tmp (json/generate-string data {:pretty true}))
    (fs/move tmp *network-path* {:replace-existing true})))

(defn update-network!
  "Read network, apply function, write back."
  [f & args]
  (let [old-data (read-network)
        new-data (apply f old-data args)]
    (write-network! new-data)
    new-data))

;; --- State (credentials, serials, certs) ---

(def empty-state
  {:serial 0
   :peers {}
   :certs {}
   :revoked_serials []})

(defn read-state
  "Read state, returning empty state if file doesn't exist."
  []
  (if (fs/exists? *state-path*)
    (json/parse-string (slurp *state-path*) true)
    empty-state))

(defn write-state!
  "Write state atomically."
  [data]
  (let [tmp (str *state-path* ".tmp")]
    (spit tmp (json/generate-string data {:pretty true}))
    (fs/move tmp *state-path* {:replace-existing true})))

(defn update-state!
  "Read state, apply function, write back."
  [f & args]
  (let [old-data (read-state)
        new-data (apply f old-data args)]
    (write-state! new-data)
    new-data))

;; --- Merged view (config + state) ---

(defn read-merged
  "Read network config with state merged into peers."
  []
  (let [network (read-network)
        state (read-state)
        peers (reduce-kv
               (fn [acc name peer]
                 (assoc acc name (merge peer (get-in state [:peers name] {}))))
               {}
               (:peers network))]
    (assoc network :peers peers :state state)))

;; Backwards compatibility aliases
(def read-config read-network)

;; --- CA paths (from environment with defaults) ---

(defn ca-path
  "Get CA key path for a given type (:host, :user, :initrd).
   Reads from PKI_HOST_CA, PKI_USER_CA, PKI_INITRD_CA environment variables.
   Defaults to ~/.ssh/ca/{host,user,initrd}_ca if not set."
  [ca-type]
  (let [home (System/getenv "HOME")
        [env-var default-path] (case (keyword ca-type)
                                 :host ["PKI_HOST_CA" (str home "/.ssh/ca/host_ca")]
                                 :user ["PKI_USER_CA" (str home "/.ssh/ca/user_ca")]
                                 :initrd ["PKI_INITRD_CA" (str home "/.ssh/ca/initrd_ca")]
                                 (throw (ex-info "Unknown CA type" {:type ca-type})))
        path (or (System/getenv env-var) default-path)]
    (str/replace path #"^~" home)))

;; --- Serial management (state) ---

(defn current-serial
  "Get current serial number from state."
  [state]
  (:serial state 0))

(defn allocate-serial!
  "Allocate and return the next serial number, updating state.json."
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
  "Get peer config by name (from network.json), or nil if not found."
  [peer-name]
  (get-in (read-network) [:peers (keyword peer-name)]))

(defn get-peer-with-state
  "Get peer config merged with state."
  [peer-name]
  (let [network (read-network)
        state (read-state)
        peer (get-in network [:peers (keyword peer-name)])]
    (when peer
      (merge peer (get-in state [:peers (keyword peer-name)] {})))))

(defn peer-names
  "Get list of all peer names (from network.json)."
  []
  (keys (:peers (read-network))))

(defn add-peer!
  "Add a new peer to network.json (config only, no credentials)."
  [peer-name peer-data]
  (update-network!
   (fn [n]
     (if (get-in n [:peers (keyword peer-name)])
       (throw (ex-info "Peer already exists" {:peer peer-name}))
       (assoc-in n [:peers (keyword peer-name)] peer-data)))))

(defn update-peer-state!
  "Update peer credentials in state.json."
  [peer-name updates]
  (update-state!
   (fn [s]
     (update-in s [:peers (keyword peer-name)] merge updates))))

;; --- Certificate tracking (state) ---

(defn record-cert!
  "Record a certificate in state.json."
  [serial cert-info]
  (update-state!
   (fn [s]
     (assoc-in s [:certs (str serial)] cert-info))))

;; --- Revocation (state) ---

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

(defn- parse-subnet-base
  "Extract base from subnet like '10.100.10.0/24' -> '10.100.10'"
  [subnet]
  (-> subnet
      (str/replace #"/\d+$" "")
      (str/replace #"\.\d+$" "")))

(defn- parse-subnet6-base
  "Extract base from IPv6 subnet like 'fd10:100:10::/64' -> 'fd10:100:10'"
  [subnet]
  (-> subnet
      (str/replace #"::/\d+$" "")))

(defn next-available-ip
  "Find next available IP suffix for a site."
  [site-name]
  (let [network (read-network)
        site (get-in network [:sites (keyword site-name)])
        subnet-base (parse-subnet-base (:subnet4 site))
        site-peers (->> (:peers network)
                        (filter (fn [[_ p]] (= (:site p) site-name)))
                        vals)
        suffixes (->> site-peers
                      (map :ip4)
                      (keep #(when % (last (str/split % #"\."))))
                      (map parse-long))]
    (if (empty? suffixes)
      1
      (inc (apply max suffixes)))))

(defn make-peer-ips
  "Generate IP addresses for a new peer in a site."
  [site-name suffix]
  (let [network (read-network)
        site (get-in network [:sites (keyword site-name)])
        base4 (parse-subnet-base (:subnet4 site))
        base6 (parse-subnet6-base (:subnet6 site))]
    {:ip4 (str base4 "." suffix)
     :ip6 (str base6 "::" (format "%x" suffix))}))
