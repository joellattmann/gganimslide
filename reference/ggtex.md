# Animated beamer slide from a ggplot

Writes a multi-page PDF in which page 1 shows the static layers (and
axes, legend, titles) and page \*k + 1\* adds the first \*k\* animation
steps, and returns the beamer code that shows one page per overlay (with
beamer's \`\only\` command). Every page is cut from the same rendered
plot, so nothing moves between steps.

## Usage

``` r
ggtex(
  p,
  file,
  animate = NULL,
  scope = c("layers", "all", "all_but_theme"),
  width = 5.5,
  height = 3,
  title = NULL,
  tex = NULL,
  standalone = FALSE,
  graphics_path = NULL,
  include_width = "\\linewidth",
  start = 1,
  device = NULL,
  categorical = FALSE,
  verbose = TRUE
)
```

## Arguments

- p:

  A saved ggplot object.

- file:

  Path of the PDF to write (e.g. \`"figures/turnout.pdf"\`). Required.

- animate:

  Layers at which a new step starts. Layers before the first entry are
  always shown; the last entry also reveals all later layers. \`animate
  = c(3, 4, 5)\` shows layers 1-2, then adds 3, then 4, then 5 and
  everything after it. \`NULL\` (default) reveals every layer on its
  own. A negative number removes a step again: \`-3\` makes the step
  that started at layer 3 disappear (with the given \`effect\` as exit
  animation in PowerPoint), e.g. \`animate = c(3, 4, 5, -3)\`. Entries
  play in the order given, and \`effect\`, \`trigger\` and \`duration\`
  count removals as steps.

- scope:

  What the numbers in \`animate\` count. \`"layers"\` (default): only
  geoms, stats and annotations; axes, titles, legend and theme are
  always shown. \`"all"\`: every \`+\` component of the plot in the
  order it was written (geoms, \`labs()\`, scales, coords, facets,
  \`theme\_\*()\`, \`theme()\`). \`"all_but_theme"\`: like \`"all"\`,
  but \`theme()\` and \`theme\_\*()\` calls are not counted and always
  applied. For these two, the plot must be made with \[steps()\], or its
  code written directly into the call.

- width, height:

  Size of the PDF in inches. Use the size the plot will have on the
  slide so text sizes match (a full 16:9 beamer frame is about 5.5 x 3).

- title:

  Frame title. \`NULL\` for no title.

- tex:

  Optional path of a \`.tex\` file to write the code to.

- standalone:

  If \`TRUE\`, the code is a complete, compilable beamer document
  instead of a single frame.

- graphics_path:

  How \`file\` is referred to in the LaTeX code. Defaults to \`file\`,
  or to its path relative to \`tex\` if \`tex\` is given.

- include_width:

  Width passed to \`\includegraphics\`.

- start:

  First overlay number, if the frame has other overlays before the plot.

- device:

  PDF device; \`grDevices::cairo_pdf\` (if available) handles Unicode
  and system fonts, \`grDevices::pdf\` is the fallback.

- categorical:

  If \`TRUE\`, every group within a step (each bar, box, colour group,
  ...) gets its own overlay, in group order. See \[ggppt()\].

- verbose:

  If \`TRUE\` (default), the LaTeX code is printed to the console.

## Value

The LaTeX code (invisibly); it is also printed if \`verbose = TRUE\`.

## Examples

``` r
library(ggplot2)
p <- ggplot(mtcars, aes(wt, mpg)) +
  geom_point(colour = "grey70") +
  geom_smooth(method = "lm", formula = y ~ x) +
  geom_point(data = subset(mtcars, mpg > 30), colour = "red")
out <- tempfile(fileext = ".pdf")
ggtex(p, out, animate = c(2, 3), title = "Fuel use")
#> \begin{frame}{Fuel use}
#>   \centering
#>   % gganimslide: static 1 | 2 geom_smooth | 3 geom_point
#>   \only<1>{\includegraphics[width=\linewidth,page=1]{/tmp/RtmpIRxLoG/file190b6ff0bdd0.pdf}}%
#>   \only<2>{\includegraphics[width=\linewidth,page=2]{/tmp/RtmpIRxLoG/file190b6ff0bdd0.pdf}}%
#>   \only<3->{\includegraphics[width=\linewidth,page=3]{/tmp/RtmpIRxLoG/file190b6ff0bdd0.pdf}}%
#> \end{frame} 
```
