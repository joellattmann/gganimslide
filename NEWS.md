# gganimslide 0.1.0 (beta)

First public release.

* `ggppt()`: animated PowerPoint slides with one editable vector shape per step and native entrance animations (`appear`, `fade`, `wipe_*`; on click, after or with the previous step).
* `ggtex()`: animated beamer slides (multi-page PDF + `\only<>` overlay code).
* `animate = c(3, 4, 5)`: layers before 3 are static, the last number also reveals everything after it.
* `scope = "layers"` / `"all"` / `"all_but_theme"`: reveal only geoms, or every `+` component (labs, scales, coords, facets, themes).
* Component order is recorded automatically while gganimslide is loaded; `steps()` as fallback; `plot_components()` shows the numbering.
* 16:9 slides by default; `ppt_deck()` for decks with several plots.
