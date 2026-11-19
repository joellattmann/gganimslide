#' Animated beamer slide from a ggplot
#'
#' Writes a multi-page PDF in which page 1 shows the static layers (and axes,
#' legend, titles) and page *k + 1* adds the first *k* animation steps, and returns the beamer code that shows one page
#' per overlay (`\\only<k>{...}`). Every page is cut from the same rendered plot,
#' so nothing moves between steps.
#'
#' @param p A saved ggplot object.
#' @param file Path of the PDF to write (e.g. `"figures/turnout.pdf"`).
#' @param animate Layers at which a new step starts. Layers before the first
#'   entry are always shown; the last entry also reveals all later layers.
#'   `animate = c(3, 4, 5)` shows layers 1-2, then adds 3, then 4, then 5 and
#'   everything after it. `NULL` (default) reveals every layer on its own.
#'   A negative number removes a step again: `-3` makes the step that started
#'   at layer 3 disappear (with the given `effect` as exit animation in
#'   PowerPoint), e.g. `animate = c(3, 4, 5, -3)`. Entries play in the order
#'   given, and `effect`, `trigger` and `duration` count removals as steps.
#' @param scope What the numbers in `animate` count. `"layers"` (default):
#'   only geoms, stats and annotations; axes, titles, legend and theme are
#'   always shown. `"all"`: every `+` component of the plot in the order it was
#'   written (geoms, `labs()`, scales, coords, facets, `theme_*()`, `theme()`).
#'   `"all_but_theme"`: like `"all"`, but `theme()` and `theme_*()` calls are
#'   not counted and always applied. For these two, the plot must have been
#'   created while gganimslide was loaded (its components are then recorded
#'   automatically), or made with [steps()], or written directly into the call.
#' @param width,height Size of the PDF in inches. Use the size the plot will
#'   have on the slide so text sizes match (a full 16:9 beamer frame is about
#'   5.5 x 3).
#' @param title Frame title. `NULL` for no title.
#' @param tex Optional path of a `.tex` file to write the code to.
#' @param standalone If `TRUE`, the code is a complete, compilable beamer
#'   document instead of a single frame.
#' @param graphics_path How `file` is referred to in the LaTeX code. Defaults to
#'   `file`, or to its path relative to `tex` if `tex` is given.
#' @param include_width Width passed to `\\includegraphics`.
#' @param start First overlay number, if the frame has other overlays before
#'   the plot.
#' @param device PDF device; `grDevices::cairo_pdf` (if available) handles
#'   Unicode and system fonts, `grDevices::pdf` is the fallback.
#' @return The LaTeX code (invisibly); it is also printed.
#' @examples
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(colour = "grey70") +
#'   geom_smooth(method = "lm", formula = y ~ x) +
#'   geom_point(data = subset(mtcars, mpg > 30), colour = "red")
#' out <- tempfile(fileext = ".pdf")
#' ggtex(p, out, animate = c(2, 3), title = "Fuel use")
#' @export
ggtex <- function(p, file = "plot.pdf", animate = NULL,
                  scope = c("layers", "all", "all_but_theme"), width = 5.5, height = 3,
                  title = NULL, tex = NULL, standalone = FALSE,
                  graphics_path = NULL, include_width = "\\linewidth",
                  start = 1, device = NULL) {
  scope <- match.arg(scope)
  if (scope == "layers") {
    gt <- plot_gtable(p)
    st <- animation_steps(gt$n_layers, animate)
    # Page 1: static part; then one page per entry of the sequence.
    pages <- lapply(shown_after_each(st), function(l) frame_with_layers(gt, l))
    info <- c(if (length(st$static)) paste("static", paste(st$static, collapse = ",")) else "axes",
              seq_labels(p, st))
  } else {
    comp <- resolve_components(substitute(p), parent.frame(), p, required = TRUE)
    cf <- component_frames(comp, animate, scope)
    pages <- lapply(cf$frames, ggplot2::ggplotGrob)
    info <- c(cf$static_label, cf$labels)
  }

  if (is.null(device)) {
    device <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else grDevices::pdf
  }
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  args <- list(file, width = width, height = height, onefile = TRUE)
  if (identical(device, grDevices::pdf)) args$useDingbats <- FALSE
  do.call(device, args)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (pg in pages) {
    grid::grid.newpage()
    grid::grid.draw(pg)
  }
  grDevices::dev.off()
  on.exit()

  if (is.null(graphics_path)) {
    graphics_path <- if (is.null(tex)) file else relative_path(file, dirname(tex))
  }
  graphics_path <- gsub("\\\\", "/", graphics_path)

  n <- length(pages)
  overlays <- seq.int(start, length.out = n)
  lines <- sprintf("  \\only<%d%s>{\\includegraphics[width=%s,page=%d]{%s}}%%",
                   overlays, ifelse(seq_len(n) == n, "-", ""), include_width,
                   seq_len(n), graphics_path)
  frame <- c(
    if (is.null(title)) "\\begin{frame}" else sprintf("\\begin{frame}{%s}", title),
    "  \\centering",
    sprintf("  %% gganimslide: %s", paste(info, collapse = " | ")),
    lines,
    "\\end{frame}"
  )
  code <- if (standalone) {
    c("\\documentclass[aspectratio=169]{beamer}",
      "\\usepackage{graphicx}",
      "\\begin{document}", "", frame, "", "\\end{document}")
  } else frame
  code <- paste(code, collapse = "\n")

  if (!is.null(tex)) {
    dir.create(dirname(tex), showWarnings = FALSE, recursive = TRUE)
    writeLines(code, tex)
  }
  cat(code, "\n")
  invisible(code)
}

relative_path <- function(path, from) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  from <- normalizePath(from, winslash = "/", mustWork = FALSE)
  p <- strsplit(path, "/")[[1]]
  f <- strsplit(from, "/")[[1]]
  i <- 0
  while (i < min(length(p), length(f)) && p[i + 1] == f[i + 1]) i <- i + 1
  rel <- c(rep("..", length(f) - i), p[-seq_len(i)])
  paste(rel, collapse = "/")
}
