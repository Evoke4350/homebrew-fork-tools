# frozen_string_literal: true

class ForkReport < Formula
  desc "Generate beautiful Markdown reports of Git repos and forks"
  homepage "https://github.com/Evoke4350/homebrew-fork-tools"
  url "https://github.com/Evoke4350/homebrew-fork-tools/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "1a4ab15d21603f54622029fd73a15a1c31e657b33a24c48880d62b59f051fa31"
  license "MIT"

  def install
    bin.install "fork-report.sh" => "fork-report"
    bin.install "fork-check.sh" => "fork-check"
    bin.install "fork-watcher.sh" => "fork-watcher"
  end

  test do
    # Smoke-test each command's --version / --help surface.
    assert_match "fork-report.sh v", shell_output("#{bin}/fork-report --version")
    assert_match "USAGE:",            shell_output("#{bin}/fork-report --help")

    # fork-check exits 1 when it has nothing to check; that's expected.
    output = shell_output("REPOS= FORK_SEARCH_DIRS=#{testpath}/empty #{bin}/fork-check 2>&1", 1)
    assert_match "no forks to check", output
  end
end
