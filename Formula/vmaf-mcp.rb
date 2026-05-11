class VmafMcp < Formula
  include Language::Python::Virtualenv

  desc "MCP (Model Context Protocol) server exposing libvmaf to AI agents"
  homepage "https://github.com/lusoris/vmaf/tree/master/mcp-server/vmaf-mcp"
  license "BSD-3-Clause-Patent"
  head "https://github.com/lusoris/vmaf.git", branch: "master"

  depends_on "lusoris/tap/libvmaf"
  depends_on "python@3.13"
  # See libvmaf.rb — repo tracks `model/tiny/*.onnx` via Git LFS; without
  # git-lfs on Homebrew's sandbox PATH the clone fails during checkout.
  depends_on "git-lfs" => :build

  # As with `vmaf-tune`, dependencies (mcp, pydantic, anyio, fastapi-style
  # transports) come from `mcp-server/vmaf-mcp/pyproject.toml`. The list is
  # mostly stable but the MCP SDK churns; bottle audits will run
  # `homebrew-pypi-poet` against a known-good venv before each tap release.

  def install
    venv = virtualenv_create(libexec, "python3.13")
    cd "mcp-server/vmaf-mcp" do
      venv.pip_install_and_link buildpath/"mcp-server/vmaf-mcp"
    end
  end

  test do
    # `--help` exits 0 once the MCP transport has parsed its arg list.
    system bin/"vmaf-mcp", "--help"
  end
end
