# typed: false
# frozen_string_literal: true

class Sharmory < Formula
  desc "Single-file Zsh and PowerShell library of developer shell functions"
  homepage "https://github.com/hariharen9/sharmory"
  url "https://github.com/hariharen9/sharmory/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "47b19f1edc2f2b8b81eb36c5df76732132f6f06c365d928d92e66eb7bc30b0ae"
  license "MIT"
  head "https://github.com/hariharen9/sharmory.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "zsh"

  def install
    prefix.install "functions.zsh"
    prefix.install "functions.ps1"
    prefix.install "LICENSE"
  end

  def caveats
    <<~EOS
      Sharmory is a sourced library, not a standalone binary.

      Add this line to your ~/.zshrc:

        source #{opt_prefix}/functions.zsh

      Then restart your shell or run: source ~/.zshrc
    EOS
  end

  test do
    assert_predicate prefix/"functions.zsh", :exist?
    output = shell_output("zsh -c 'source #{prefix}/functions.zsh && sharmory list' 2>&1")
    assert_match "git", output
  end
end
