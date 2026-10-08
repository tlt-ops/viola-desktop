# 0.2.30 build 31：右大腿与袜口修正

**状态：已按用户要求撤回。** 当前安装版本已恢复为 0.2.29 build 30。0.2.30 的 artwork、构建和验收记录均保留；回退核验见 [`build/rollback-thigh-v0.2.30/verification.json`](../build/rollback-thigh-v0.2.30/verification.json)。

0.2.30 lowers the black stocking top on the picture-right thigh to expose more skin. It retains the `reference-v0.2.29` rig profile, animation code and character coordinates. Only local texture assets and manifest filenames changed. The 0.2.29 source, app and full profile remain archived at `cache/preserved-v0.2.29-before-thigh-correction`.

## Pixel changes

- Six sprites were patched in RGB across 11,061 source pixels within `[514,601,663,721]`; 336 leftover seated-stock pixels were recolored. Friend-derived backing changed by 0 pixels.
- The final seam fix softened alpha on 1,002 pixels within the opaque same-thigh region at source `[515,678,662,685]`. RGB and pixels outside that internal blend are unchanged; the outer silhouette remains intact. Alpha is therefore not wholly unchanged. Geometry, coordinates and anchors were not changed.
- Strict/deep signature verification passed. The 25 active sprite hashes match across source, app bundle and profile manifest; installation preserved `config.json` and `keyboard-stats.json` byte-for-byte. App: `Viola 新版.app`.

## Verification

Texture/render checks covered 16 poses and 170 quick-crawl frames; friend isolation passed with `minDet=0.5926399126`. Native display review with the desk hidden showed the exposed picture-right thigh and lowered stocking top. Evidence: `build/thigh-v0.2.30/final-verification.json`, archived pre-seam-fix review `pre-seam-v4-verification.json`, `build/thigh-v0.2.30/seam-audit/alpha-adjustment.json`, `final-body-preview.png`, `final-before-after-render.png`, `install-verification.json`, `native-acceptance.json`, and `native-diagnostics.json`.

This local texture release did not rerun the earlier 0.2.29 core, 82-key or 964-frame suites. Input Monitoring remains off; no real keyboard-input acceptance is claimed.
