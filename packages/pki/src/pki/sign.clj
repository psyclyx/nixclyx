(ns pki.sign
  "Certificate signing operations."
  (:require [pki.shell :as sh]
            [babashka.fs :as fs]
            [clojure.string :as str]))

(defn sign-key!
  "Sign a public key with the specified CA.
   Options:
     :ca-type    - :host or :user (controls -h flag)
     :ca-path    - explicit CA path (required)
     :principals - comma-separated principals (required)
     :identity   - certificate identity (required)
     :serial     - serial number (required)
     :pubkey     - public key string (required)
   Returns {:cert <cert-string> :serial <serial>}"
  [{:keys [ca-type ca-path principals identity serial pubkey]}]
  (when-not ca-path
    (throw (ex-info "CA path required for signing" {})))
  (when-not principals
    (throw (ex-info "Principals required for signing" {})))
  (when-not identity
    (throw (ex-info "Identity required for signing" {})))
  (when-not serial
    (throw (ex-info "Serial required for signing" {})))
  (when-not pubkey
    (throw (ex-info "Public key required for signing" {})))

  (let [sign-type (if (= ca-type :user) "user" "host")

        ;; Write pubkey to temp file
        tmpdir (str (fs/create-temp-dir))
        pubkey-file (str tmpdir "/key.pub")
        _ (spit pubkey-file pubkey)

        ;; Build sign-key args
        args ["sign-key" sign-type
              "--ca" ca-path
              "--principals" principals
              "--identity" identity
              "--serial" (str serial)
              pubkey-file]

        result (apply sh/run! {:continue false} args)
        cert (str/trim (:out result))]

    ;; Cleanup
    (fs/delete-tree tmpdir)

    {:cert cert :serial serial}))
