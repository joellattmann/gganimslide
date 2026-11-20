# gganimslide 0.2.0

## New features

* `categorical = TRUE` in `ggppt()` and `ggtex()`: reveal each group (bar, box, colour group) of a step on its own.
* Negative numbers in `animate` remove a step again (exit animations in PowerPoint).
* `ggppt()`: `width`, `height`, `left`, `top` to size and place the plot.
* `ggtex()`: `verbose = FALSE` stops the LaTeX code from being printed.

## Breaking changes

* Component order is no longer recorded automatically. For `scope = "all"` / `"all_but_theme"`, make the plot with `steps()` or write the plot code directly into the call. The default `scope = "layers"` is unaffected.
* `ggtex()`: `file` no longer has a default and must be given.

## Bug fixes

* `ggppt()`: the panel border is drawn unclipped, so all four sides show in PowerPoint.

# gganimslide 0.1.0 (beta)

First public release.

* `ggppt()`: animated PowerPoint slides with one editable vector shape per step and native entrance animations (`appear`, `fade`, `wipe_*`; on click, after or with the previous step).
* `ggtex()`: animated beamer slides (multi-page PDF + `\only<>` overlay code).
* `animate = c(3, 4, 5)`: layers before 3 are static, the last number also reveals everything after it.
* `scope = "layers"` / `"all"` / `"all_but_theme"`: reveal only geoms, or every `+` component (labs, scales, coords, facets, themes).
* Component order is recorded automatically while gganimslide is loaded; `steps()` as fallback; `plot_components()` shows the numbering.
* 16:9 slides by default; `ppt_deck()` for decks with several plots.