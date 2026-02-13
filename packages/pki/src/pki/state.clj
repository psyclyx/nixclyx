(ns pki.state
  "Read/write pki-state.json, serial allocation, cert/revocation tracking."
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [pki.config :as config]))

(def ^:dynamic *state-path* nil)

(defn init-paths!
  "Initialize state path. Call after config/init-paths!."
  ([]
   (init-paths! {}))
  ([{:keys [state]}]
   (alter-var-root #'*state-path*
                   (constantly (or state (str config/*repo-root* "/pki-state.json"))))))

;; --- State reading/writing ---

(def empty-state
  {:serial 0
   :identities {}
   :certs {}
   :revokedSerials []})

(defn read-state
  "Read pki-state.json, returning empty state if file doesn't exist."
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
  "Read state, apply function, write back. Returns new state."
  [f & args]
  (let [old-data (read-state)
        new-data (apply f old-data args)]
    (write-state! new-data)
    new-data))

;; --- Serial management ---

(defn allocate-serial!
  "Allocate and return the next serial number, updating state."
  []
  (let [state (update-state! (fn [s] (update s :serial inc)))]
    (dec (:serial state))))

;; --- Identity management ---

(defn get-identity
  "Get identity entry by id, or nil."
  [state id]
  (get-in state [:identities (keyword id)]))

(defn record-key!
  "Record a public key for an identity and key type."
  [id key-type-name public-key]
  (update-state!
   (fn [s]
     (assoc-in s [:identities (keyword id) (keyword key-type-name) :publicKey]
               public-key))))

(defn record-cert-serial!
  "Record a cert serial for an identity and key type."
  [id key-type-name serial]
  (update-state!
   (fn [s]
     (assoc-in s [:identities (keyword id) (keyword key-type-name) :certSerial]
               serial))))

;; --- Certificate tracking ---

(defn record-cert!
  "Record a certificate in the certs map."
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
     (update s :revokedSerials
             (fn [rs]
               (->> (concat (or rs []) serials)
                    (map #(if (string? %) (parse-long %) %))
                    distinct
                    sort
                    vec))))))

(defn revoked-serials
  "Get list of revoked serials from state."
  [state]
  (:revokedSerials state []))
