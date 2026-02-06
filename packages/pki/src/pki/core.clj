(ns pki.core
  "State management for PKI: reading/writing JSON, serial tracking, peer registry."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:dynamic *repo-root* nil)
(def ^:dynamic *pki-path* nil)

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
  ([{:keys [pki]}]
   (let [root (find-repo-root)]
     (alter-var-root #'*repo-root* (constantly root))
     (alter-var-root #'*pki-path* (constantly (or pki (str root "/pki.json")))))))

;; --- PKI data (single file) ---

(def empty-pki
  {:ca {}
   :wireguard {}
   :dns {}
   :serial 0
   :peers {}
   :certs {}
   :revoked_serials []})

(defn read-pki
  "Read the PKI file, creating if it doesn't exist."
  []
  (if (fs/exists? *pki-path*)
    (json/parse-string (slurp *pki-path*) true)
    empty-pki))

(defn write-pki!
  "Write PKI data to file atomically."
  [data]
  (let [tmp (str *pki-path* ".tmp")]
    (spit tmp (json/generate-string data {:pretty true}))
    (fs/move tmp *pki-path* {:replace-existing true})))

(defn update-pki!
  "Read PKI, apply function, write back. Returns new data."
  [f & args]
  (let [old-data (read-pki)
        new-data (apply f old-data args)]
    (write-pki! new-data)
    new-data))

;; Aliases for backwards compatibility
(def read-config read-pki)
(def read-state read-pki)

(defn ca-path
  "Get CA key path for a given type (:host, :user, :initrd)."
  [pki ca-type]
  (let [path (get-in pki [:ca (keyword ca-type)])]
    (when-not path
      (throw (ex-info "Unknown CA type" {:type ca-type})))
    (str/replace path #"^~" (System/getenv "HOME"))))

;; --- Serial management ---

(defn current-serial
  "Get current serial number from state."
  [state]
  (:serial state 0))

(defn allocate-serial!
  "Allocate and return the next serial number, updating pki.json."
  []
  (let [pki (update-pki! (fn [s] (update s :serial inc)))]
    (dec (:serial pki))))

(defn allocate-serials!
  "Allocate n serial numbers, returning vector of serials."
  [n]
  (let [start (:serial (read-pki))
        serials (vec (range start (+ start n)))]
    (update-pki! (fn [s] (update s :serial + n)))
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
  "Add a new peer to pki.json."
  [peer-name peer-data]
  (update-pki!
   (fn [s]
     (if (get-in s [:peers (keyword peer-name)])
       (throw (ex-info "Peer already exists" {:peer peer-name}))
       (assoc-in s [:peers (keyword peer-name)] peer-data)))))

(defn update-peer!
  "Update an existing peer."
  [peer-name updates]
  (update-pki!
   (fn [s]
     (if-not (get-in s [:peers (keyword peer-name)])
       (throw (ex-info "Peer not found" {:peer peer-name}))
       (update-in s [:peers (keyword peer-name)] merge updates)))))

;; --- Certificate tracking ---

(defn record-cert!
  "Record a certificate in pki.json."
  [serial cert-info]
  (update-pki!
   (fn [s]
     (assoc-in s [:certs (str serial)] cert-info))))

;; --- Revocation ---

(defn revoke-serials!
  "Add serials to revocation list."
  [serials]
  (update-pki!
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
  [state site-name]
  (let [config (read-config)
        site (get-in config [:wireguard :sites (keyword site-name)])
        subnet-base (parse-subnet-base (:subnet4 site))
        site-peers (->> (:peers state)
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
  (let [config (read-config)
        site (get-in config [:wireguard :sites (keyword site-name)])
        base4 (parse-subnet-base (:subnet4 site))
        base6 (parse-subnet6-base (:subnet6 site))]
    {:ip4 (str base4 "." suffix)
     :ip6 (str base6 "::" (format "%x" suffix))}))
