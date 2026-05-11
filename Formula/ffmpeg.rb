require_relative "libvmaf"

class Ffmpeg < Formula
  desc "FFmpeg n8.1 with the Lusoris fork's libvmaf patch series applied"
  homepage "https://github.com/lusoris/vmaf/tree/master/ffmpeg-patches"
  url "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n8.1.tar.gz"
  sha256 "dd308201bb1239a1b73185f80c6b4121f4efdfa424a009ce544fd00bf736bb2e"
  license "GPL-2.0-or-later"

  # Source of the patch series. We git-clone the fork at install time
  # (`HEAD` until release-please cuts a tagged release) and apply
  # `ffmpeg-patches/*.patch` in `series.txt` order before `./configure`.
  resource "vmaf-patches" do
    url "https://github.com/lusoris/vmaf.git",
        branch: "master",
        using:  LusorisGitNoLfsDownloadStrategy
  end

  depends_on "lusoris/tap/libvmaf"
  depends_on "nasm" => :build
  depends_on "pkg-config" => :build
  # The `vmaf-patches` resource clones lusoris/vmaf which tracks
  # `model/tiny/*.onnx` via Git LFS; without git-lfs on Homebrew's
  # sandbox PATH the resource fetch fails during checkout with
  # "git-lfs filter-process: git-lfs: command not found".
  depends_on "git-lfs" => :build

  # Codec / muxer dependencies. This is the "full" build the tap promises
  # (per Lawrence: he installs `ffmpeg-full` and wants our libvmaf wired
  # in). Trimmed to what's available in homebrew-core; extras like
  # `librav1e`, `libxavs`, etc. can be added via formula options later.
  depends_on "aom"
  depends_on "dav1d"
  depends_on "fdk-aac" => :optional
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "frei0r"
  depends_on "gnutls"
  depends_on "lame"
  depends_on "libass"
  depends_on "libbluray"
  depends_on "libplacebo"
  depends_on "librist"
  # libdovi (Dolby Vision metadata) is not in homebrew-core — it's a
  # Rust crate, available only via third-party taps. Users who want
  # DV metadata can install libdovi via their own tap and override
  # the formula's configure args with `--enable-libdovi`. Not adding
  # a hard dep here to avoid forcing every tonemap user to set up a
  # second tap.
  depends_on "libsoxr"
  depends_on "libvidstab"
  depends_on "libvorbis"
  depends_on "libvpx"
  depends_on "opencore-amr"
  depends_on "openh264"
  depends_on "openjpeg"
  depends_on "opus"
  depends_on "rav1e" => :optional
  depends_on "rubberband"
  depends_on "sdl2"
  depends_on "snappy"
  depends_on "speex"
  depends_on "srt"
  depends_on "svt-av1"
  depends_on "tesseract"
  depends_on "theora"
  depends_on "webp"
  depends_on "x264"
  depends_on "x265"
  depends_on "xvid"
  depends_on "xz"
  depends_on "zeromq"
  depends_on "zimg"

  # Vulkan — enables FFmpeg's native Vulkan hwaccel (hwcontext_vulkan)
  # and the fork-local `-vf libvmaf_vulkan` zero-copy filter. Without
  # these, hardware paths like `-hwaccel vulkan` for HEVC decode fail
  # with `Unable to open the libvulkan library!` at runtime — the
  # loader is dlopen()ed, not linked.
  #
  # `vulkan-headers` is build-time only. `vulkan-loader` provides
  # `libvulkan.dylib` / `libvulkan.so.1` — the Khronos loader that
  # FFmpeg dlopen()s. On macOS, `molten-vk` provides the actual ICD
  # (`libMoltenVK.dylib` + `MoltenVK_icd.json`) that the loader
  # delegates to; users still need to point the loader at the ICD via
  # `VK_ICD_FILENAMES` at runtime (see caveats).
  depends_on "vulkan-headers" => :build
  depends_on "vulkan-loader"

  on_macos do
    depends_on "openssl@3"
    depends_on "molten-vk"
  end

  on_linux do
    depends_on "alsa-lib"
    depends_on "openssl@3"
    depends_on "pulseaudio"
  end

  conflicts_with "ffmpeg",
    because: "both install ffmpeg / ffprobe / ffplay binaries"

  def install
    # Stage the fork repo so we can read ffmpeg-patches/series.txt + the
    # actual .patch files. Resource arrives in `buildpath/vmaf-patches/`.
    resource("vmaf-patches").stage do
      patch_dir = Pathname.pwd/"ffmpeg-patches"
      series    = (patch_dir/"series.txt").read.lines.map(&:strip).reject(&:empty?)
      series.each do |patch_file|
        next if patch_file.start_with?("#")
        ohai "Applying ffmpeg-patches/#{patch_file}"
        system "git", "-C", buildpath, "apply", "--3way", (patch_dir/patch_file).to_s
      end
    end

    args = %W[
      --prefix=#{prefix}
      --enable-shared
      --enable-pthreads
      --enable-version3
      --cc=#{ENV.cc}
      --host-cflags=#{ENV.cflags}
      --host-ldflags=#{ENV.ldflags}
      --enable-ffplay
      --enable-gnutls
      --enable-gpl
      --enable-libaom
      --enable-libass
      --enable-libbluray
      --enable-libdav1d
      --enable-libfreetype
      --enable-libmp3lame
      --enable-libopencore-amrnb
      --enable-libopencore-amrwb
      --enable-libopenjpeg
      --enable-libplacebo
      --enable-librist
      --enable-librubberband
      --enable-libsnappy
      --enable-libsrt
      --enable-libssh
      --enable-libsvtav1
      --enable-libtesseract
      --enable-libtheora
      --enable-libvidstab
      --enable-libvmaf
      --enable-libvorbis
      --enable-libvpx
      --enable-libwebp
      --enable-libx264
      --enable-libx265
      --enable-libxml2
      --enable-libxvid
      --enable-libzimg
      --enable-libzmq
      --enable-lzma
      --enable-libfontconfig
      --enable-libfreetype
      --enable-frei0r
      --enable-libsoxr
      --enable-libspeex
      --enable-openssl
      --enable-vulkan
      --disable-htmlpages
    ]
    args << "--enable-libfdk-aac" if build.with?("fdk-aac")
    args << "--enable-librav1e"   if build.with?("rav1e")

    on_macos do
      args << "--enable-videotoolbox"
      args << "--enable-audiotoolbox"
    end

    on_linux do
      args << "--disable-indev=jack"
      args << "--enable-libpulse"
      args << "--enable-libxcb"
    end

    system "./configure", *args
    system "make", "install"
  end

  def caveats
    s = <<~EOS
      FFmpeg was built with Vulkan hwaccel support (`--enable-vulkan`).
      The Khronos Vulkan loader (`vulkan-loader`) is dlopen()ed at runtime;
      it locates GPU drivers ('ICDs') via the `VK_ICD_FILENAMES` env var
      or the standard search paths.
    EOS
    if OS.mac?
      s += <<~EOS

        On macOS the only Vulkan ICD is MoltenVK (Vulkan → Metal
        translation). Point the loader at it before running ffmpeg with
        `-hwaccel vulkan` or `-vf libvmaf_vulkan`:

          export VK_ICD_FILENAMES="$(brew --prefix molten-vk)/share/vulkan/icd.d/MoltenVK_icd.json"

        Add it to your shell rc for permanence. Verify with:

          vulkaninfo --summary   # (brew install vulkan-tools)
      EOS
    end
    s
  end

  test do
    out = shell_output("#{bin}/ffmpeg -hide_banner -version 2>&1", 0)
    assert_match(/ffmpeg version/, out)
    # Confirm libvmaf was linked in.
    cfg = shell_output("#{bin}/ffmpeg -hide_banner -buildconf 2>&1", 0)
    assert_match(/--enable-libvmaf/, cfg)
    # Confirm Vulkan hwaccel was built in.
    assert_match(/--enable-vulkan/, cfg)
  end
end
