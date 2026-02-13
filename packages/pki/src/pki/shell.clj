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
