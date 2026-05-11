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

  # Vulkan-via-MoltenVK is the active GPU path on macOS until the native
  # Metal backend's T8-1b runtime + T8-1c first kernel PRs land
  # (tracked at https://github.com/lusoris/vmaf/issues — see the
  # "metal-runtime" milestone). Once Metal-native ships, this formula
  # flips to `-Denable_metal=enabled` and these MoltenVK dependencies
  # become a `--with-vulkan` opt-in instead of the default.
  depends_on "molten-vk"
  depends_on "vulkan-headers" => :build
  depends_on "vulkan-loader"

  on_macos do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  on_linux do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  conflicts_with "libvmaf",
    because: "both install vmaf binaries and libvmaf headers; unlink homebrew-core's libvmaf first"

  def install
    # Backend selection (see ADR-0338, ADR-0264, README of this tap):
    #
    #   macOS:
    #     - Vulkan-via-MoltenVK is ENABLED — the working GPU path today.
    #       SPIR-V kernels run on Apple Silicon via MoltenVK's Vulkan
    #       → Metal translation. Bound by MoltenVK's translation cost
    #       and a couple of extension gaps (atomicInt64, external memory),
    #       but every libvmaf compute kernel in tree runs.
    #     - Metal native is DISABLED — every runtime entry point in the
    #       T8-1 scaffold returns -ENOSYS (T8-1b runtime PR not landed).
    #       Building the scaffold would register feature extractors that
    #       error at init(); cleaner to not advertise it.
    #     - CPU+NEON is the always-available fallback if the user has
    #       no Vulkan device or `--backend cpu` is passed explicitly.
    #
    #   Linux:
    #     - Vulkan via vendor ICDs (mesa, nvidia, amdvlk) is enabled.
    #     - CUDA / SYCL / HIP are off here; install meson + the toolchain
    #       and build from source if you want those (Homebrew can't bottle
    #       a CUDA-linked build).
    #
    # Endgame: native Metal replaces MoltenVK on macOS once T8-1b + T8-1c
    # land. The MoltenVK path stays available behind a future
    # `--with-moltenvk` switch for users who want to A/B-compare.
    args = %w[
      -Denable_tests=false
      -Denable_docs=false
      -Denable_cuda=false
      -Denable_sycl=false
      -Denable_hip=false
      -Denable_metal=disabled
      -Denable_vulkan=enabled
      -Dbuilt_in_models=true
    ]

    # MoltenVK ICD must be findable at runtime. The ICD file ships in
    # `molten-vk`'s share dir; we don't override `VK_ICD_FILENAMES` at
    # install time (that's a user-runtime concern), but the formula's
    # caveats remind users to set it if vkEnumerateInstanceExtensionProperties
    # can't see MoltenVK.
    if OS.mac?
      ENV.append "CPPFLAGS", "-I#{Formula["vulkan-headers"].opt_include}"
      ENV.append "LDFLAGS",  "-L#{Formula["vulkan-loader"].opt_lib}"
    end

    system "meson", "setup", "build", "libvmaf", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  def caveats
    <<~EOS
      GPU acceleration on macOS goes through MoltenVK (Vulkan → Metal)
      until the native Metal backend's runtime PR lands.

      If `vmaf --backend vulkan ...` reports no device found, point the
      Vulkan loader at MoltenVK's ICD:

          export VK_ICD_FILENAMES=#{Formula["molten-vk"].opt_share}/vulkan/icd.d/MoltenVK_icd.json

      Add it to your shell rc for permanence. On Apple Silicon the
      MoltenVK GPU path is ~2-4x faster than CPU+NEON for the
      compute-bound kernels (SSIM, ANSNR); for everything else NEON
      is roughly even because the M-series unified memory removes the
      bandwidth bottleneck GPU acceleration usually exploits.

      Native Metal will replace MoltenVK once T8-1b / T8-1c land
      (track: https://github.com/lusoris/vmaf/issues).
    EOS
  end

  test do
    # Smoke test: --help exits 0 and mentions VMAF.
    assert_match(/VMAF|vmaf/, shell_output("#{bin}/vmaf --help 2>&1", 0))
  end
end
