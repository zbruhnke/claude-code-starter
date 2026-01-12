# typed: false
# frozen_string_literal: true

class ClaudeCodeStarter < Formula
  desc "Production-ready Claude Code configuration"
  homepage "https://github.com/zbruhnke/claude-code-starter"
  url "https://github.com/zbruhnke/claude-code-starter/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "5ba8e84e506b6a0064e491b5456d0564f35e96c51efc8d71aa218341a14b64ac"
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

    # Create short alias
    bin.install_symlink "claude-code-starter" => "ccs"
  end

  def caveats
    <<~EOS
      To get started:
        ccs help          # or: claude-code-starter help
        ccs init          # or: claude-code-starter init

      Documentation:
        https://github.com/zbruhnke/claude-code-starter
    EOS
  end

  test do
    assert_match "claude-code-starter", shell_output("#{bin}/claude-code-starter version")
  end
end
