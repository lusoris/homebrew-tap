# lusoris Homebrew tap

Homebrew formulae for the [lusoris/vmaf](https://github.com/lusoris/vmaf) fork
of [Netflix/vmaf](https://github.com/Netflix/vmaf) — perceptual video quality
assessment, with extra GPU backends (CUDA, SYCL, Vulkan), wider SIMD coverage,
a full-precision CLI flag, an ONNX-Runtime tiny-AI surface, and an MCP server.

## Quick start

```bash
brew tap lusoris/tap
brew install lusoris/tap/libvmaf
```

To build against `master` (latest fork-local fixes — recommended until the
first `vN.N.N-lusoris.N` release cuts):

```bash
brew install --HEAD lusoris/tap/libvmaf
```

## Available formulae

| Formula | What it ships |
|---|---|
| `libvmaf` | The `libvmaf` C library + `vmaf` CLI. Default-on: CPU-only with all SIMD paths (AVX2, AVX-512 on capable hosts; NEON on arm64). GPU backends are opt-in (see "Mac backend selection" below). |
| `ffmpeg` | FFmpeg `n8.1` with the fork's [ffmpeg-patches](https://github.com/lusoris/vmaf/tree/master/ffmpeg-patches) series applied. Enables `-vf libvmaf` against this tap's `libvmaf`, plus the fork-local `--enable-libvmaf-cuda` / `--enable-libvmaf-vulkan` / `--enable-libvmaf-sycl` options. |
| `vmaf-tune` | The `vmaf-tune` Python CLI for per-shot encoding tuning (shot detection via TransNet V2, per-shot CRF predicates, codec adapters for x264/x265/SVT-AV1/libaom-av1/VVenC/NVENC/AMF/QSV). |
| `vmaf-mcp` | The `vmaf-mcp` MCP (Model Context Protocol) server — exposes libvmaf scoring + tiny-AI feature surfaces to AI agents over JSON-RPC. |

## Why a fork tap

The fork is BSD-3-Clause-Plus-Patent (same as Netflix upstream) but diverges
fast enough that Homebrew-core's `libvmaf` formula doesn't track our:

- Tiny-AI surface (ONNX Runtime + saliency / quality-prediction models).
- GPU backends (CUDA, SYCL, Vulkan compute) with feature-level dispatch.
- `--precision` CLI flag (default `%.17g`, IEEE-754 round-trip lossless).
- Full FFmpeg patch series (NVENC/HIP/Vulkan libvmaf consumers).
- The `vmaf-tune` per-shot CRF planner and `vmaf-mcp` MCP server.

If you only need stock VMAF scoring against a local file, Homebrew-core's
`libvmaf` is fine. If you're using any of the above, this tap is for you.

## Mac backend selection

On macOS the right answer is **CPU + NEON SIMD** (the default). Here's why
the alternatives don't pay their cost today:

| Backend | Status on Mac | Verdict |
|---|---|---|
| **CPU + NEON SIMD** | Production. AVX2 / AVX-512 on Intel; NEON on Apple Silicon. Already the hot-path for every feature extractor. | **Use this.** |
| **Metal** | Scaffold only (ADR-0338 / T8-1). The Meson option is `enable_metal=auto`, so it would auto-enable on macOS — but every runtime entry point returns `-ENOSYS` until the T8-1b runtime PR lands. The build advertises an acceleration path that nothing actually uses. The `libvmaf.rb` formula forces `enable_metal=disabled` to avoid the false advertising. | **Don't enable** until the T8-1b runtime PR ships. |
| **Vulkan via MoltenVK** | Works, but everything goes through the Vulkan → Metal translation layer. Requires `brew install molten-vk` + the keg-only `vulkan-headers`. The gains over NEON on Apple Silicon are marginal for libvmaf's hot-paths (the integer feature extractors are bound by memory bandwidth, not by FLOPs the GPU could win on). | **Skip** unless you have a specific reason. |
| **CUDA / SYCL / HIP** | Not applicable. | — |

If you do want to experiment with Vulkan-on-MoltenVK anyway, build from
source with overrides:

```bash
brew install molten-vk
brew install --HEAD --build-from-source \
  -s lusoris/tap/libvmaf  # then patch the formula's args to flip
                          # -Denable_vulkan=disabled to =enabled
```

The runtime probe at `libvmaf/src/vulkan/runtime.c` falls back to CPU if
no Vulkan-capable device is enumerated, so a misconfigured MoltenVK
install fails gracefully rather than crashing.

## Caveats

- **HEAD-only until v3.x.y-lusoris.N is cut.** All formulae default to `head`.
  Once release-please cuts the first lusoris-suffixed release, the `url` /
  `sha256` blocks will be uncommented and `brew install lusoris/tap/libvmaf`
  will pin to the latest release.
- **`ffmpeg` formula conflicts with Homebrew-core's `ffmpeg`.** It's a full
  build, not a side-by-side. Use `brew unlink ffmpeg && brew link
  lusoris/tap/ffmpeg` to swap.
- **CUDA / SYCL / Vulkan optionals.** These are off by default because
  Homebrew can't bottle CUDA-linked builds. Pass `--with-cuda` etc. to enable;
  you'll need the corresponding SDK installed system-wide (`/opt/cuda`,
  oneAPI, Vulkan SDK).

## Reporting issues

File bugs against [lusoris/vmaf](https://github.com/lusoris/vmaf/issues),
not this tap repo, unless the issue is specifically in formula plumbing
(install steps, dependencies, brew commands). Tap-repo issues are fine for
formula-only problems.

## License

The formulae here are MIT (the Homebrew convention for tap repos). The
underlying software ([lusoris/vmaf](https://github.com/lusoris/vmaf)) is
BSD-3-Clause-Plus-Patent.
