require "download_strategy"

# Custom Git strategy that bypasses Git LFS filters entirely during
# the clone + checkout. The lusoris/vmaf repo tracks `model/tiny/*.onnx`
# via Git LFS for the tiny-AI runtime, but none of the formulae in this
# tap need the actual ONNX payloads to build — they're only consumed
# at runtime by the opt-in `--enable-dnn` path.
#
# Why a custom strategy rather than `depends_on "git-lfs" => :build`:
# build deps are only put on PATH for the install phase. The clone +
# checkout happens earlier, in the fetch phase, where build-dep PATH
# is not active. Users with /opt/homebrew/bin/git-lfs installed still
# hit:
#     git-lfs filter-process: git-lfs: command not found
#     fatal: the remote end hung up unexpectedly
# because the fetch-phase env doesn't include /opt/homebrew/bin (only
# the system PATH). Setting GIT_LFS_SKIP_SMUDGE alone is not enough —
# git still invokes `git-lfs filter-process` for the smudge filter
# defined in .gitattributes; the env var only short-circuits the
# *download* of LFS content, not the filter itself.
#
# Strategy: override the per-clone git config so the LFS filter is a
# no-op (`git config filter.lfs.smudge ""` + .clean + required=false).
# After this, git treats LFS pointer files as plain text content (which
# is fine — that's what they are on disk). Combined with
# GIT_LFS_SKIP_SMUDGE=1 for belt-and-braces, the clone succeeds even
# on hosts that have never installed git-lfs.
class LusorisGitNoLfsDownloadStrategy < GitDownloadStrategy
  # Forward all positional + keyword args to `super` rather than pinning
  # a specific signature — Homebrew's GitDownloadStrategy has shipped at
  # least three different `fetch` / `update` signatures across versions
  # (`fetch(timeout:)`, `fetch(timeout: nil, **)`, `fetch(args)`), and
  # any mismatch crashes with `wrong number of arguments (given N,
  # expected M)` before the formula's def install ever runs. `*args,
  # **kwargs` is the version-proof shape.
  def fetch(*args, **kwargs)
    with_env(GIT_LFS_SKIP_SMUDGE: "1") { super }
  end

  def update(*args, **kwargs)
    with_env(GIT_LFS_SKIP_SMUDGE: "1") do
      disable_lfs_filters!
      super
    end
  end

  def clone_repo(*args, **kwargs)
    with_env(GIT_LFS_SKIP_SMUDGE: "1") do
      super
      disable_lfs_filters!
    end
  end

  private

  def disable_lfs_filters!
    return unless cached_location.directory?

    %w[smudge clean].each do |op|
      system_command "git",
                     args:    ["-C", cached_location.to_s,
                               "config", "--local", "filter.lfs.#{op}", "/bin/true"],
                     verbose: false
    end
    system_command "git",
                   args:    ["-C", cached_location.to_s,
                             "config", "--local", "filter.lfs.required", "false"],
                   verbose: false
  end
end

class Libvmaf < Formula
  desc "Perceptual video quality assessment (Lusoris fork — GPU + tiny-AI extras)"
  homepage "https://github.com/lusoris/vmaf"
  license "BSD-3-Clause-Patent"
  head "https://github.com/lusoris/vmaf.git",
       branch: "master",
       using:  LusorisGitNoLfsDownloadStrategy

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
  # `xxd` is not a standalone Homebrew formula — it ships inside `vim`
  # on Homebrew-core. macOS already provides `/usr/bin/xxd` from Apple's
  # vim install, so this is technically a no-op there, but we depend on
  # it explicitly so Linuxbrew users (and macOS systems where
  # `/usr/bin/xxd` has been removed) get a working build.
  depends_on "vim" => :build
  # The fork tracks `model/tiny/*.onnx` via Git LFS (tiny-AI weights).
  # Without git-lfs the `git clone` Homebrew issues for `head` /
  # release-tarball downloads fails with:
  #   Error: git-lfs filter-process: git-lfs: command not found
  #   fatal: the remote end hung up unexpectedly
  # The LFS payload is small (~few MB of int8 ONNX) and the formula
  # doesn't link against it directly, but the clone has to succeed
  # before the build starts.
  depends_on "git-lfs" => :build

  # Native Metal is now the default GPU path on macOS (ADR-0420 runtime
  # + ADR-0421 first kernel — `integer_motion_v2` lands T8-1c bit-exact
  # against the scalar reference per ADR-0214). Apple-Family-7 / M1+
  # hosts get real `MTLDevice` + `MTLCommandQueue` from the libvmaf
  # runtime; Intel Macs surface as -ENODEV and fall through to CPU+NEON.
  #
  # MoltenVK is no longer a dependency. Users who want to A/B-compare
  # Vulkan-via-MoltenVK against native Metal can build from source
  # with `-Denable_vulkan=enabled` and install `molten-vk` +
  # `vulkan-headers` + `vulkan-loader` manually. The `--with-moltenvk`
  # formula option is reserved for a future minor revision.

  on_macos do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  on_linux do
    depends_on "nasm" => :build if Hardware::CPU.intel?
  end

  conflicts_with "libvmaf",
    because: "both install vmaf binaries and libvmaf headers; unlink homebrew-core's libvmaf first"

  def install
    # Backend selection (see ADR-0420, ADR-0421, README of this tap):
    #
    #   macOS:
    #     - Native Metal is ENABLED — the default GPU path as of ADR-0420
    #       (T8-1b runtime) + ADR-0421 (first kernel). Apple-Family-7 / M1+
    #       hosts get real MTLDevice + MTLCommandQueue; Intel Macs surface
    #       as -ENODEV and fall through to CPU+NEON automatically.
    #     - Vulkan / MoltenVK is DISABLED. Users who want to A/B-compare
    #       can build from source with `-Denable_vulkan=enabled` and
    #       install `molten-vk` + `vulkan-headers` + `vulkan-loader`
    #       manually.
    #     - CPU+NEON is the always-available fallback if the Metal device
    #       is not found or `--backend cpu` is passed explicitly.
    #
    #   Linux:
    #     - Vulkan via vendor ICDs (mesa, nvidia, amdvlk) remains enabled.
    #     - CUDA / SYCL / HIP are off here; install meson + the toolchain
    #       and build from source if you want those (Homebrew can't bottle
    #       a CUDA-linked build).
    args = %w[
      -Denable_tests=false
      -Denable_docs=false
      -Denable_cuda=false
      -Denable_sycl=false
      -Denable_hip=false
      -Denable_metal=enabled
      -Denable_vulkan=disabled
      -Dbuilt_in_models=true
    ]

    system "meson", "setup", "build", "libvmaf", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  def caveats
    <<~EOS
      GPU acceleration on macOS uses the native Metal backend (ADR-0420).
      Apple-Family-7 / M1+ hosts are accelerated automatically; Intel Macs
      fall back to CPU+NEON transparently.

      To force CPU-only mode:
          vmaf --backend cpu ...

      To A/B-compare against Vulkan-via-MoltenVK, build from source:
          meson setup build libvmaf -Denable_metal=disabled -Denable_vulkan=enabled
      (requires molten-vk + vulkan-headers + vulkan-loader installed manually).
    EOS
  end

  test do
    # Smoke test: --help exits 0 and mentions VMAF.
    assert_match(/VMAF|vmaf/, shell_output("#{bin}/vmaf --help 2>&1", 0))
  end
end
