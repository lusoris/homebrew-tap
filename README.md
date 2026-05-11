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

The native Metal backend is **scaffold-only today** (ADR-0338 / T8-1):
every runtime entry point returns `-ENOSYS` until the T8-1b runtime PR
+ T8-1c first-kernel PR land. Endgame is native Metal, but until then:

| Backend | Status on Mac | Verdict |
|---|---|---|
| **Vulkan via MoltenVK** | **The working GPU path today.** SPIR-V kernels run on Apple Silicon through MoltenVK's Vulkan → Metal translation. ~2–4× faster than NEON on compute-bound kernels (SSIM, ANSNR); roughly even on memory-bandwidth-bound kernels. Enabled by default in `libvmaf.rb`. | **Default. GPU acceleration available now.** |
| **CPU + NEON SIMD** | Production. NEON on Apple Silicon hand-tuned across every feature extractor. Always available as a fallback (`vmaf --backend cpu …`). | Fallback / explicit opt-out. |
| **Metal (native)** | Scaffold landed (T8-1, ADR-0361, ~1,950 LOC, all `-ENOSYS`). Runtime PR (T8-1b) and first real kernel (T8-1c) in flight — see [issue tracker](https://github.com/lusoris/vmaf/issues). Estimated 2–3 weeks of focused work, then 7 follow-up kernels. | **Coming**. Tap formula will flip from `enable_vulkan` to `enable_metal` once T8-1c ships. |
| **CUDA / SYCL / HIP** | Not applicable on Mac. | — |

### Runtime: pointing the Vulkan loader at MoltenVK

If `vmaf --backend vulkan …` reports *"no Vulkan device found"*, the
Vulkan loader can't see MoltenVK's ICD. Fix with:

```bash
export VK_ICD_FILENAMES="$(brew --prefix molten-vk)/share/vulkan/icd.d/MoltenVK_icd.json"
```

Add it to your `~/.zshrc` / `~/.bashrc` for permanence. The formula's
`brew info lusoris/tap/libvmaf` caveats repeat this so it's not
lost-to-history information.

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
