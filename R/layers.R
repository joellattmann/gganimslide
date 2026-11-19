# Cutting one rendered ggplot into aligned pieces.
#
# The plot is built once with ggplotGrob(). A ggplot panel is a gTree whose
# children are: coord background (grid), facet background, one grob per
# layer, facet foreground, coord foreground (panel.border). Every piece below is a copy of the same
# gtable with some of those children (or the non-panel grobs) replaced by
# zeroGrob(). The layout (axis widths, legend size, panel area) is fixed when
# the gtable is built, so all pieces line up exactly when stacked.

#' Work out the animation steps from `animate`
#'
#' Positive numbers in `animate` are the layers at which a new step starts.
#' Layers before the first positive number are static. Each step shows its
#' layer and every following layer up to the next positive number; the last
#' one also shows all layers after it. A negative number `-k` removes the step
#' that started at layer `k` again (it fades out, or disappears). The entries
#' are played in the order given.
#'
#' @param n_layers Number of layers in the plot.
#' @param animate `NULL` (every layer is its own step) or an integer vector.
#' @return A list with `static` (layers always shown), `steps` (list of layer
#'   vectors, one per step that appears) and `sequence` (data frame with one
#'   row per entry: `action` `"in"` or `"out"`, and the `step` it refers to).
#' @examples
#' # Six layers, animate = c(3, 4, 5):
#' # layers 1-2 static, then 3, then 4, then 5 and 6 together
#' animation_steps(6, c(3, 4, 5))
#'
#' # ... and then layer 3 disappears again
#' animation_steps(6, c(3, 4, 5, -3))
#' @export
animation_steps <- function(n_layers, animate = NULL) {
  if (n_layers < 1) stop("The plot has no layers.", call. = FALSE)
  if (is.null(animate)) animate <- seq_len(n_layers)
  if (!is.numeric(animate) || anyNA(animate) || any(animate %% 1 != 0) || any(animate == 0)) {
    stop("`animate` must be a vector of whole layer numbers, e.g. c(3, 4, 5) or c(3, 4, -3).",
         call. = FALSE)
  }
  animate <- as.integer(animate)
  if (any(abs(animate) > n_layers)) {
    stop(sprintf("`animate` must only contain layer numbers between 1 and %d (the plot has %d layers).",
                 n_layers, n_layers), call. = FALSE)
  }
  starts <- animate[animate > 0]
  if (length(starts) == 0) stop("`animate` needs at least one positive layer number.", call. = FALSE)
  if (anyDuplicated(starts)) stop("`animate` contains duplicate layer numbers.", call. = FALSE)
  if (anyDuplicated(animate[animate < 0])) stop("Each step can only be removed once.", call. = FALSE)
  if (is.unsorted(starts)) {
    if (any(animate < 0)) stop("The positive numbers in `animate` must be in increasing order.", call. = FALSE)
    warning("`animate` was not in increasing order and has been sorted.", call. = FALSE)
    animate <- sort(animate)
    starts <- animate
  }
  ends <- c(starts[-1] - 1L, n_layers)
  steps <- Map(seq.int, starts, ends)

  action <- character(length(animate))
  step <- integer(length(animate))
  shown <- logical(length(starts))
  for (i in seq_along(animate)) {
    k <- animate[i]
    if (k > 0) {
      action[i] <- "in"; step[i] <- match(k, starts); shown[step[i]] <- TRUE
    } else {
      j <- match(-k, starts)
      if (is.na(j)) {
        stop(sprintf(paste0("`animate` contains %d, but no step starts at layer %d. ",
                            "Only animated steps can be removed; use the number that starts the step."),
                     k, -k), call. = FALSE)
      }
      if (!shown[j]) stop(sprintf("`animate` removes layer %d (%d) before it has appeared.", -k, k), call. = FALSE)
      action[i] <- "out"; step[i] <- j; shown[j] <- FALSE
    }
  }
  list(
    static = seq_len(starts[1] - 1L),
    steps = steps,
    sequence = data.frame(action = action, step = step, stringsAsFactors = FALSE)
  )
}

# Layers shown after each entry of the sequence (first element: start).
shown_after_each <- function(st) {
  shown <- st$static
  out <- list(shown)
  for (i in seq_len(nrow(st$sequence))) {
    l <- st$steps[[st$sequence$step[i]]]
    shown <- if (st$sequence$action[i] == "in") c(shown, l) else setdiff(shown, l)
    out[[i + 1]] <- shown
  }
  out
}

# Build the gtable and check that every panel has the expected structure.
plot_gtable <- function(p) {
  if (!is_gg(p)) stop("`p` must be a ggplot object.", call. = FALSE)
  n_layers <- length(p$layers)
  if (n_layers == 0) stop("The plot has no layers to animate.", call. = FALSE)
  g <- ggplot2::ggplotGrob(p)
  panel_idx <- grep("^panel", g$layout$name)
  if (length(panel_idx) == 0) stop("Could not find any panels in the plot.", call. = FALSE)
  lead <- NA
  for (i in panel_idx) {
    panel <- g$grobs[[i]]
    extra <- length(panel$children) - n_layers
    if (!inherits(panel, "gTree") || extra < 2 || extra %% 2 != 0 ||
        (!is.na(lead) && lead != extra / 2)) {
      stop(sprintf(paste0(
        "Unexpected panel structure (%d grobs for %d layers). ",
        "This coordinate system or extension is not supported."),
        length(panel$children), n_layers), call. = FALSE)
    }
    lead <- extra / 2
  }
  list(g = g, panel_idx = panel_idx, n_layers = n_layers, lead = lead)
}

# Keep only the given layers (and optionally the panel background/foreground).
filter_panel <- function(panel, layers, n_layers, lead, decor) {
  kids <- panel$children
  for (j in seq_along(kids)) {
    layer <- j - lead
    is_decor <- layer < 1 || layer > n_layers
    keep <- if (is_decor) decor else layer %in% layers
    if (!keep) {
      z <- ggplot2::zeroGrob()
      z$name <- paste0("gganimslide-hidden-", j)
      kids[[j]] <- z
    }
  }
  grid::setChildren(panel, do.call(grid::gList, unname(as.list(kids))))
}

# Full plot showing only `layers` (axes, legend, titles included).
frame_with_layers <- function(gt, layers) {
  g <- gt$g
  for (i in gt$panel_idx) {
    g$grobs[[i]] <- filter_panel(g$grobs[[i]], layers, gt$n_layers, gt$lead, decor = TRUE)
  }
  g
}

# Only `layers`, on a transparent background, with everything else blanked.
overlay_with_layers <- function(gt, layers) {
  g <- gt$g
  non_panel <- setdiff(seq_along(g$grobs), gt$panel_idx)
  for (i in non_panel) g$grobs[[i]] <- ggplot2::zeroGrob()
  for (i in gt$panel_idx) {
    g$grobs[[i]] <- filter_panel(g$grobs[[i]], layers, gt$n_layers, gt$lead, decor = FALSE)
  }
  g
}

layer_label <- function(layer) {
  lbl <- sub("^Geom", "", class(layer$geom)[1])
  lbl <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", lbl)
  paste0("geom_", tolower(lbl))
}

# One label per entry of the animation sequence ("- " marks a removal).
seq_labels <- function(p, st) {
  lbl <- step_labels(p, st$steps)[st$sequence$step]
  ifelse(st$sequence$action == "out", paste("remove", lbl), lbl)
}

step_labels <- function(p, steps) {
  vapply(steps, function(l) {
    paste(sprintf("%d %s", l, vapply(p$layers[l], layer_label, "")), collapse = " + ")
  }, "")
}

# is.ggplot() is deprecated from ggplot2 3.5.2; is_ggplot() is missing before.
is_gg <- function(x) {
  ns <- asNamespace("ggplot2")
  f <- if (exists("is_ggplot", envir = ns, inherits = FALSE)) get("is_ggplot", envir = ns) else get("is.ggplot", envir = ns)
  isTRUE(f(x))
}

# Draw the panel foreground (panel.border) outside the panel's clipping
# region. Some PowerPoint renderers drop border lines that lie exactly on the
# clip boundary; moving the border to its own unclipped gtable cell on top
# keeps all four sides. Used for the PowerPoint output only.
unclip_panel_border <- function(g, n_layers) {
  panel_idx <- grep("^panel", g$layout$name)
  z_top <- max(g$layout$z, na.rm = TRUE)
  for (i in panel_idx) {
    panel <- g$grobs[[i]]
    kids <- panel$children
    lead <- (length(kids) - n_layers) / 2
    if (!inherits(panel, "gTree") || lead < 1 || lead %% 1 != 0) next
    fg_idx <- seq.int(length(kids) - lead + 1, length(kids))
    fg <- kids[fg_idx]
    for (j in fg_idx) {
      z <- ggplot2::zeroGrob()
      z$name <- paste0("gganimslide-moved-", j)
      kids[[j]] <- z
    }
    g$grobs[[i]] <- grid::setChildren(panel, do.call(grid::gList, unname(as.list(kids))))
    row <- g$layout[i, , drop = FALSE]
    row$clip <- "off"
    row$z <- z_top + 1
    row$name <- paste0("gganimslide-border-", row$name)
    g$grobs[[length(g$grobs) + 1]] <- grid::gTree(children = do.call(grid::gList, unname(as.list(fg))))
    g$layout <- rbind(g$layout, row)
  }
  g
}
