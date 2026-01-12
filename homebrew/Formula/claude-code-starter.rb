# typed: false
# frozen_string_literal: true

class ClaudeCodeStarter < Formula
  desc "Production-ready Claude Code configuration"
  homepage "https://github.com/zbruhnke/claude-code-starter"
  url "https://github.com/zbruhnke/claude-code-starter/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "fdb9bfef6718474e9792edd9c72409ebd01181d130b09797f9c375a09839f62d"
  license "MIT"

  def install
    # Install everything to libexec to keep it self-contained
    libexec.install Dir["*"]
    libexec.install Dir[".*"].reject { |f| f =~ /^\.\.?$/ }

    # Make scripts executable
    chmod 0755, libexec/"bin/claude-code-starter"
    chmod 0755, libexec/"setup.sh"
    chmod 0755, libexec/"adopt.sh"
    chmod 0755, libexec/"install.sh"

    # Create wrapper script that sets up the environment
    (bin/"claude-code-starter").write <<~EOS
      #!/bin/bash
      export CLAUDE_CODE_STARTER_HOME="#{libexec}"
      exec "#{libexec}/bin/claude-code-starter" "$@"
    EOS
  end

  def caveats
    <<~EOS
      To get started:
        claude-code-starter help
        claude-code-starter init

      Documentation:
        https://github.com/zbruhnke/claude-code-starter
    EOS
  end

  test do
    assert_match "claude-code-starter", shell_output("#{bin}/claude-code-starter version")
  end
end
