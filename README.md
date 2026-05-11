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
| `libvmaf` | The `libvmaf` C library + `vmaf` CLI. Default-on: CPU-only with all SIMD paths (AVX2, AVX-512 on capable hosts; NEON on arm64). Optional: `--with-cuda` (requires CUDA toolkit), `--with-vulkan` (requires the Vulkan SDK). SYCL is opt-in via `--with-sycl` and needs Intel oneAPI installed locally. |
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
