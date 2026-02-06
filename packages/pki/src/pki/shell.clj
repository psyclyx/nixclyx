(ns pki.shell
  "Shell command helpers for running external tools."
  (:require [babashka.process :as p]
            [clojure.string :as str]))

(defn run!
  "Run a shell command, returning {:out :err :exit}.
   Options map (if any) should be first argument.
   Throws on non-zero exit unless :continue true."
  [& args]
  (let [opts (if (map? (first args))
               (first args)
               {})
        cmd (if (map? (first args))
              (rest args)
              args)
        result (apply p/shell
                      (merge {:out :string :err :string :continue true} opts)
                      cmd)]
    (when (and (not (:continue opts)) (not (zero? (:exit result))))
      (throw (ex-info (str "Command failed: " (str/join " " cmd) "\n" (:err result))
                      {:cmd cmd :exit (:exit result) :err (:err result)})))
    result))

(defn run-out!
  "Run command and return stdout (trimmed). Throws on failure."
  [& args]
  (-> (apply run! args)
      :out
      str/trim))

(defn ssh!
  "Run command on remote host via SSH.
   Options map (if any) should be first argument.
   dest can be a string or a map with :host and optional :jump/:port
   :jump is passed directly to -J (e.g. 'user@host' or just 'host')
   :port is passed directly to -p"
  [& args]
  (let [opts (when (map? (first args)) (first args))
        [dest & cmd] (if opts (rest args) args)
        [dest-str ssh-opts] (if (map? dest)
                               [(str "root@" (:host dest))
                                (concat
                                 (when-let [j (:jump dest)] ["-J" j])
                                 (when-let [p (:port dest)] ["-p" (str p)]))]
                               [dest nil])
        cmd-args (concat ["ssh"] ssh-opts [dest-str] (map str cmd))]
    (if opts
      (apply run! opts cmd-args)
      (apply run! cmd-args))))

(defn ssh-out!
  "Run command on remote host, return stdout."
  [dest & cmd]
  (-> (apply ssh! {:continue false} dest cmd)
      :out
      str/trim))

(defn scp!
  "Copy file to remote host."
  [local-path dest remote-path]
  (run! "scp" local-path (str dest ":" remote-path)))

(defn pipe-to-ssh!
  "Pipe string content to a command on remote host."
  [content dest remote-cmd]
  (let [[dest-str ssh-opts] (if (map? dest)
                               [(str "root@" (:host dest))
                                (concat
                                 (when-let [j (:jump dest)] ["-J" j])
                                 (when-let [p (:port dest)] ["-p" (str p)]))]
                               [dest nil])
        args (concat ["ssh"] ssh-opts [dest-str remote-cmd])]
    (apply p/shell {:in content :out :string :err :string} args)))

(defn nix-copy-closure!
  "Copy nix store path to remote host.
   dest can be a string or map with :host/:jump/:port"
  [dest store-path]
  (let [dest-str (if (map? dest)
                   (str "root@" (:host dest))
                   dest)
        ;; nix-copy-closure uses NIX_SSHOPTS for ssh options
        ssh-opts (when (map? dest)
                   (str/join " "
                             (concat
                              (when-let [j (:jump dest)] ["-J" j])
                              (when-let [p (:port dest)] ["-p" (str p)]))))
        env (when (and ssh-opts (not (str/blank? ssh-opts)))
              {"NIX_SSHOPTS" ssh-opts})]
    (run! {:extra-env env} "nix-copy-closure" "--to" dest-str store-path)))
