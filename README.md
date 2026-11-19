# gganimslide <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![Status: beta](https://img.shields.io/badge/status-beta-F2FF00.svg)](https://github.com/joellattmann/gganimslide)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![GitHub release](https://img.shields.io/github/v/release/joellattmann/gganimslide?color=002FA7)](https://github.com/joellattmann/gganimslide/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-002FA7.svg)](LICENSE)
<!-- badges: end -->

Reveal the layers of a saved ggplot step by step, in **PowerPoint** or **LaTeX beamer**.

The following code creates a PowerPoint presentation in your working directory that animates the layers (e.g., geoms) of a `ggplot2` object (*p*). Positive numbers in `animate` mark the layer at which a step *animates in* (each step runs up to the next number); negative numbers *animate out* the step that started at that layer. Except for the plot and the file name, all arguments can be left blank, using the defaults: every layer of the plot *appears* on *click*, while axes, titles and legend are shown from the start.
```r
ggppt(p, "savings.pptx",
      animate  = c(1, 2, 3, 5, 6, 8, -8),
      effect   = c("wipe_up", "wipe_left", "fade", "wipe_left", "fade", "fade", "fade"),
      trigger  = c("click", "click", "after", "click", "after", "click", "click"),
      duration = c(1, 2.5, 0.5, 2.5, 0.5, 0.6, 0.6))
```



https://github.com/user-attachments/assets/966ea13b-3aa7-42e7-884b-91388e662129




```r
p <- ggplot(df, aes(x, y)) +
  geom_hline(yintercept = 0) +     # 1
  geom_vline(xintercept = 0) +     # 2
  geom_point(aes(colour = g)) +    # 3
  geom_smooth(method = "lm") +     # 4
  annotate("text", 2, -1.5, label = "beta = 0.6") +  # 5
  geom_rug()                       # 6

ggppt(p, "plot.pptx", animate = c(3, 4, 5), title = "My plot")
ggtex(p, "fig/plot.pdf", animate = c(3, 4, 5), title = "My plot", tex = "plot_frame.tex")
```

`animate` lists the layers at which a new step starts. Everything before the first number is shown from the start, and the last number also brings everything after it. For the plot above, `animate = c(3, 4, 5)` gives:

| PowerPoint | beamer | shown |
|---|---|---|
| slide opens | overlay 1 | axes, legend, layers 1–2 |
| click 1 | overlay 2 | + layer 3 |
| click 2 | overlay 3 | + layer 4 |
| click 3 | overlay 4 | + layer 5 **and everything after it** (here: 6) |

`animate = NULL` (default) reveals every layer on its own.

**Removing a step again:** a negative number makes the step that started at that layer disappear, e.g., `animate = c(3, 4, 5, -3)` shows 3, 4, 5+ and then removes layer 3 again. In PowerPoint the `effect` for that entry is used as the exit animation (`"fade"` fades it out, `"wipe_left"` wipes it away); in beamer the layer is simply gone on the next overlay. `effect`, `trigger` and `duration` count removals as steps too.

## Functions

| function | what it's for |
|---|---|
| `ggppt()` | animated PowerPoint slide |
| `ggtex()` | animated beamer slide (multi-page PDF + LaTeX code) |
| `ppt_deck()` | new 16:9 deck to collect several plots with `ggppt(doc = ...)` |
| `plot_components()` | shows which number each part of a plot has under each `scope` |
| `animation_steps()` | previews how an `animate` vector is split into steps, e.g., `animation_steps(6, c(3, 4, 5))` |
| `steps()` | fallback: stores the component order for plots made without gganimslide loaded |

## Install

```r
# install.packages("remotes")
remotes::install_github("joellattmann/gganimslide")
```

All dependencies (ggplot2, officer, rvg, xml2) are installed automatically.

## scope: what the numbers count

By default (`scope = "layers"`) the numbers only count geoms, stats and `annotate()`; axes, titles, legend and theme are always shown. Two more options let you reveal *any* `+` component:

| `scope` | numbers count |
|---|---|
| `"layers"` (default) | geoms / stats / annotations |
| `"all"` | every `+` component in the order written: geoms, `labs()`, scales, coords, facets, `theme_*()`, `theme()` |
| `"all_but_theme"` | the same, but `theme()` / `theme_*()` are not counted and always applied |

A finished ggplot normally forgets the order of its components, so while gganimslide is loaded it **records them automatically** for every plot you create. Nothing to wrap, and the order survives `saveRDS()` / `readRDS()`:

```r
library(gganimslide)
p <- ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +                    # 1
  labs(title = "Fuel use") +        # 2
  theme_minimal() +                 # 3
  geom_smooth(method = "lm")        # 4
plot_components(p)                  # shows the numbering for each scope
ggppt(p, "fuel.pptx", animate = c(2, 3, 4), scope = "all")
```

Only plots created *before* `library(gganimslide)` (or with `options(gganimslide.record = FALSE)`) have no recorded order. For those, re-run the plot code, wrap it in `steps(...)`, or write the code directly into the `ggppt()`/`ggtex()` call.

In these modes each step is a full redraw (titles or themes can change the layout), so in PowerPoint every step covers the previous one; set `bg` to your slide background if it isn't white.

## ggppt(): PowerPoint

* The plot becomes a stack of **editable vector shapes** at the same position: one base shape (axes, grid, legend, titles, static layers) plus one transparent shape per step.
* **Native PowerPoint animations** are written into the slide, so there is nothing to set up by hand. The shapes are named in the Selection Pane (e.g., `step 2: layer 4 geom_smooth`), and you can still change the effects in PowerPoint's Animation Pane.
* `effect`: `"appear"` (default), `"fade"`, `"wipe_left"`, `"wipe_right"`, `"wipe_up"`, `"wipe_down"`. Give one value, or one per step.
* `size`: `"16:9"` (default) or `"4:3"` for new decks; a `template` keeps its own size.
* `width`, `height`, `left`, `top`: size and position of the plot in inches (default: the area below the title; the plot is centred unless `left`/`top` are given). **Set the size here, not by dragging in PowerPoint:** dragging doesn't scale the text, and resizing a single step's shape misaligns it with the others.
* `trigger`: `"click"` (default), `"after"`, `"with"`. Give one value, or one per step.
* Build a deck with several plots:

```r
doc <- ppt_deck()          # 16:9; or ppt_deck(template = "my_template.pptx")
doc <- ggppt(p1, doc = doc, animate = c(3, 4), title = "First")
doc <- ggppt(p2, doc = doc, effect = "fade", title = "Second")
print(doc, target = "talk.pptx")
```

## ggtex(): beamer

* Writes a multi-page PDF: page 1 = static part, page k+1 = static part + first k steps. All pages are cut from **one** rendered plot, so nothing shifts between overlays.
* Prints (and with `tex =` writes) the frame code:

```latex
\begin{frame}{My plot}
  \centering
  \only<1>{\includegraphics[width=\linewidth,page=1]{fig/plot.pdf}}%
  \only<2>{\includegraphics[width=\linewidth,page=2]{fig/plot.pdf}}%
  \only<3>{\includegraphics[width=\linewidth,page=3]{fig/plot.pdf}}%
  \only<4->{\includegraphics[width=\linewidth,page=4]{fig/plot.pdf}}%
\end{frame}
```

* Use it in your deck with `\input{plot_frame.tex}`. `standalone = TRUE` gives a complete compilable document instead.
* Set `width`/`height` (inches) to the size the plot has on the slide so font sizes match. The default 5.5 × 3 fits a 16:9 beamer frame.

## Limitations

* Supports standard ggplot2 panels (any geom, `facet_wrap`/`facet_grid`, `coord_cartesian`/`coord_flip`). Exotic extensions that change the panel structure give a clear error.
* The legend belongs to the static part, so it is visible from the start.

## Citation

If you use gganimslide in your work, please cite it:

```r
citation("gganimslide")
```

> Lattmann, J. F. (2026). *gganimslide: Reveal ggplot2 Layers Step by Step in PowerPoint and Beamer Slides*. R package version 0.1.0. https://github.com/joellattmann/gganimslide
