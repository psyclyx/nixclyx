(ns pki.shell
  "Shell command helpers for running external tools."
  (:require [babashka.process :as p]
            [clojure.string :as str]))

(defn run!
  "Run a shell command, returning {:out :err :exit}.
   Throws on non-zero exit unless :continue true."
  [& args]
  (let [opts (if (map? (last args))
               (last args)
               {})
        cmd (if (map? (last args))
              (butlast args)
              args)
        result (apply p/shell
                      (merge {:out :string :err :string :continue true} opts)
                      cmd)]
    (when (and (not (:continue opts)) (not (zero? (:exit result))))
      (throw (ex-info (str "Command failed: " (str/join " " cmd))
                      {:cmd cmd :exit (:exit result) :err (:err result)})))
    result))

(defn run-out!
  "Run command and return stdout (trimmed). Throws on failure."
  [& args]
  (-> (apply run! args)
      :out
      str/trim))

(defn ssh!
  "Run command on remote host via SSH."
  [dest & cmd]
  (apply run! "ssh" dest (map str cmd)))

(defn ssh-out!
  "Run command on remote host, return stdout."
  [dest & cmd]
  (-> (apply ssh! (concat [dest] cmd [{:continue false}]))
      :out
      str/trim))

(defn scp!
  "Copy file to remote host."
  [local-path dest remote-path]
  (run! "scp" local-path (str dest ":" remote-path)))

(defn pipe-to-ssh!
  "Pipe string content to a command on remote host."
  [content dest remote-cmd]
  (p/shell {:in content :out :string :err :string}
           "ssh" dest remote-cmd))

(defn nix-copy-closure!
  "Copy nix store path to remote host."
  [dest store-path]
  (run! "nix-copy-closure" "--to" dest store-path))
