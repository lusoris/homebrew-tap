class VmafTune < Formula
  include Language::Python::Virtualenv

  desc "Per-shot encoding tuning CLI on top of libvmaf (Lusoris fork)"
  homepage "https://github.com/lusoris/vmaf/tree/master/tools/vmaf-tune"
  license "BSD-3-Clause-Patent"
  head "https://github.com/lusoris/vmaf.git", branch: "master"

  depends_on "lusoris/tap/libvmaf"
  depends_on "ffmpeg"
  depends_on "python@3.13"
  # Repo tracks `model/tiny/*.onnx` via Git LFS; without git-lfs on
  # Homebrew's sandbox PATH the clone fails with "git-lfs: command not
  # found" during `git checkout`. Putting it on the build PATH fixes it
  # even if the user already has git-lfs installed system-wide.
  depends_on "git-lfs" => :build

  # Python deps are resolved by the upstream `tools/vmaf-tune/pyproject.toml`.
  # We let `pip` pull them into the virtualenv at install time rather than
  # vendoring `resource "..."` blocks here — vmaf-tune's dependency tree
  # (numpy, pandas, onnxruntime, pyyaml, etc.) is large and changes often.
  # If a future Homebrew audit requires the explicit resource list, generate
  # via `homebrew-pypi-poet vmaf-tune` against an installed venv.

  def install
    # `pip` from the project subdir; pyproject.toml at tools/vmaf-tune/.
    venv = virtualenv_create(libexec, "python3.13")
    cd "tools/vmaf-tune" do
      venv.pip_install_and_link buildpath/"tools/vmaf-tune"
    end
  end

  test do
    system bin/"vmaf-tune", "--help"
  end
end
