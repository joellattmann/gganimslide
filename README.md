# gganimslide

Reveal the layers of a saved ggplot step by step, in **PowerPoint** or **LaTeX beamer**.

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

`animate` lists the layers at which a new step starts:

| overlay / click | shown |
|---|---|
| start | axes, legend, layers 1–2 |
| 1 | + layer 3 |
| 2 | + layer 4 |
| 3 | + layer 5 **and everything after it** (6) |

`animate = NULL` (default) reveals every layer on its own.

## Functions

| function | what it's for |
|---|---|
| `ggppt()` | animated PowerPoint slide |
| `ggtex()` | animated beamer slide (multi-page PDF + LaTeX code) |
| `ppt_deck()` | new 16:9 deck to collect several plots with `ggppt(doc = ...)` |
| `plot_components()` | shows which number each part of a plot has under each `scope` |
| `animation_steps()` | previews how an `animate` vector is split into steps, e.g. `animation_steps(6, c(3, 4, 5))` |
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
* **Native PowerPoint animations** are written into the slide, so there is nothing to set up by hand. The shapes are named in the Selection Pane (e.g. `step 2: layer 4 geom_smooth`), and you can still change the effects in PowerPoint's Animation Pane.
* `effect`: `"appear"` (default), `"fade"`, `"wipe_left"`, `"wipe_right"`, `"wipe_up"`, `"wipe_down"`. Give one value, or one per step.
* `size`: `"16:9"` (default) or `"4:3"` for new decks; a `template` keeps its own size.
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