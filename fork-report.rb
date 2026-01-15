# frozen_string_literal: true

class ForkReport < Formula
  desc "Generate beautiful Markdown reports of Git repos and forks"
  homepage "https://github.com/Evoke4350/homebrew-fork-tools"
  url "https://github.com/Evoke4350/homebrew-fork-tools/archive/refs/tags/v1.0.0.tar.gz"
  sha256 :no_check
  license "MIT"

  def install
    bin.install "fork-report.sh" => "fork-report"
    bin.install "fork-check.sh" => "fork-check"
    bin.install "fork-watcher.sh" => "fork-watcher"
  end

  test do
    (testpath/"test.sh").write <<~EOS
      #!/bin/bash
      export GITHUB_USERNAMES="test"
      #{bin}/fork-report --version
    EOS
    system "bash", "test.sh"
  end
end
