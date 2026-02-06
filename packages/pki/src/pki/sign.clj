(ns pki.sign
  "Certificate signing operations."
  (:require [pki.core :as core]
            [pki.shell :as sh]
            [babashka.fs :as fs]
            [clojure.string :as str]))

(defn sign-key!
  "Sign a public key with the specified CA.
   Options:
     :ca-type    - :host, :user, or :initrd
     :ca-path    - explicit CA path (overrides ca-type)
     :principals - comma-separated principals (required)
     :identity   - certificate identity (required)
     :serial     - serial number (optional, will allocate if not provided)
     :pubkey     - public key string (required)
   Returns {:cert <cert-string> :serial <serial>}"
  [{:keys [ca-type ca-path principals identity serial pubkey]}]
  (when-not principals
    (throw (ex-info "Principals required for signing" {})))
  (when-not identity
    (throw (ex-info "Identity required for signing" {})))
  (when-not pubkey
    (throw (ex-info "Public key required for signing" {})))

  (let [config (core/read-config)
        ca (or ca-path (core/ca-path config (or ca-type :host)))
        serial (or serial (core/allocate-serial!))
        sign-type (if (= ca-type :user) "user" "host")

        ;; Write pubkey to temp file
        tmpdir (str (fs/create-temp-dir))
        pubkey-file (str tmpdir "/key.pub")
        _ (spit pubkey-file pubkey)

        ;; Build sign-key args
        args ["sign-key" sign-type
              "--ca" ca
              "--principals" principals
              "--identity" identity
              "--serial" (str serial)
              pubkey-file]

        result (apply sh/run! args)
        cert (str/trim (:out result))]

    ;; Cleanup
    (fs/delete-tree tmpdir)

    ;; Record cert
    (core/record-cert! serial
                       {:identity identity
                        :ca (name (or ca-type :host))})

    {:cert cert :serial serial}))

(defn sign-host-key!
  "Sign a host key. Returns {:cert :serial}."
  [{:keys [hostname fqdn pubkey serial ca-path]}]
  (sign-key! {:ca-type :host
              :ca-path ca-path
              :principals (str hostname "," fqdn)
              :identity (str fqdn "-host")
              :serial serial
              :pubkey pubkey}))

(defn sign-initrd-key!
  "Sign an initrd host key. Returns {:cert :serial}."
  [{:keys [hostname fqdn pubkey serial ca-path]}]
  (sign-key! {:ca-type :initrd
              :ca-path ca-path
              :principals (str hostname "," fqdn)
              :identity (str fqdn "-initrd")
              :serial serial
              :pubkey pubkey}))

(defn sign-user-key!
  "Sign a user key. Returns {:cert :serial}."
  [{:keys [principal identity pubkey serial ca-path]}]
  (sign-key! {:ca-type :user
              :ca-path ca-path
              :principals principal
              :identity identity
              :serial serial
              :pubkey pubkey}))
