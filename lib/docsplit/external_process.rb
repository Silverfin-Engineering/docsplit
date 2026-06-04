require 'shellwords'
require 'open3_safe'

module Docsplit
  module ExternalProcess
    extend self

    # Seconds to wait after SIGTERM before escalating to SIGKILL.
    KILL_AFTER = 5

    # Default RSS byte cap applied when no max_rss is supplied (or nil is passed) — 512 MiB.
    DEFAULT_MAX_RSS = 512 * 1024 * 1024

    # Run an external process and raise an exception if it fails.
    #
    # command  - shell command string (may include 2>&1, which is stripped)
    # env      - Hash of extra environment variables (default: {})
    # timeout  - seconds before the process is sent SIGTERM (nil = no timeout)
    # max_rss: - RSS byte threshold; defaults to DEFAULT_MAX_RSS
    def run(command, env = {}, timeout = nil, max_rss: DEFAULT_MAX_RSS)
      # Strip 2>&1 redirects — stderr is captured separately by Open3Safe.
      cmd = Shellwords.split(command.gsub(/\s*2>&1\s*/, ' ').strip)

      opts = { signal: :TERM, kill_after: KILL_AFTER, max_rss: max_rss }
      opts[:timeout] = timeout if timeout

      args = env.empty? ? [*cmd, opts] : [env, *cmd, opts]
      result = Open3Safe.capture3_safe(*args)

      # Combine stdout+stderr (previously unified via 2>&1 in callers), then filter blank
      # lines and consecutive duplicates.
      output = (result[:stdout] + result[:stderr])
                 .lines
                 .reject { |l| l.chomp.empty? }
                 .each_with_object([]) { |l, acc| acc << l unless acc.last == l }
                 .join
                 .chomp

      raise TimeoutError, command if result[:timeout] || result[:oom_killed]
      raise ExtractionFailed, output if result[:status].exitstatus != 0

      output
    end
  end
end
