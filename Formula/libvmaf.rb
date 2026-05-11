class Libvmaf < Formula
  desc "Perceptual video quality assessment (Lusoris fork — GPU + tiny-AI extras)"
  homepage "https://github.com/lusoris/vmaf"
  license "BSD-3-Clause-Patent"
  head "https://github.com/lusoris/vmaf.git", branch: "master"

  # Stable URL/SHA will be uncommented once release-please cuts the first
  # v3.x.y-lusoris.N release on lusoris/vmaf. Until then, this formula is
  # HEAD-only; `brew install lusoris/tap/libvmaf` and
  # `brew install --HEAD lusoris/tap/libvmaf` behave the same.
  #
  # url "https://github.com/lusoris/vmaf/archive/refs/tags/v3.0.0-lusoris.0.tar.gz"
  # sha256 "REPLACE_ME"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build
  depends_on "xxd" => :build

  on_macos do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  on_linux do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  conflicts_with "libvmaf",
    because: "both install vmaf binaries and libvmaf headers; unlink homebrew-core's libvmaf first"

  def install
    args = %w[
      -Denable_tests=false
      -Denable_docs=false
      -Denable_cuda=false
      -Denable_sycl=false
      -Dbuilt_in_models=true
    ]

    system "meson", "setup", "build", "libvmaf", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    # Smoke test: --help exits 0 and mentions VMAF.
    assert_match(/VMAF|vmaf/, shell_output("#{bin}/vmaf --help 2>&1", 0))
  end
end
