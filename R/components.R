# step-by-step reveal of *all* `+` components of a plot (scope = "all" or
# "all_but_theme")

# a finished ggplot does not remember the order in which labs(), scales, 
# coords, facets and themes were added, so the order comes from (1) plot 
# code written directly into ggppt()/ggtex(), or (2) steps()

#' Remember the order of a plot's components
#'
#' Wrap the code that makes a plot in `steps()` to store the order of its `+`
#' components inside the plot. The result is a normal ggplot (you can print,
#' save and `readRDS()` it), and [ggppt()] / [ggtex()] can later reveal any of
#' its components with `scope = "all"` or `scope = "all_but_theme"`.
#'
#' Only needed for these two scopes. With the default `scope = "layers"`,
#' any saved ggplot works without `steps()`.
#'
#' @param plot The code that makes the plot, e.g.
#'   `ggplot(df, aes(x, y)) + geom_point() + labs(title = "A")`.
#' @return The plot, with the component order stored as an attribute.
#' @examples
#' library(ggplot2)
#' p <- steps(
#'   ggplot(mtcars, aes(wt, mpg)) +
#'     geom_point() +                                  # 1
#'     labs(title = "Fuel use") +                      # 2
#'     theme_minimal() +                               # 3
#'     geom_smooth(method = "lm", formula = y ~ x)     # 4
#' )
#' plot_components(p)
#' @export
steps <- function(plot) {
  comp <- components_from_expr(substitute(plot), parent.frame())
  p <- build_plot(comp, seq_along(comp$objects))
  attr(p, "gganimslide") <- comp
  p
}

#' List a plot's components and their numbers
#'
#' Shows how the numbers in `animate` map onto the plot's components for each
#' `scope`. Needs a plot made with [steps()] (or the plot code itself).
#'
#' @param p A plot made with [steps()], or plot code.
#' @return A data frame with one row per component, invisibly; it is printed.
#' @export
plot_components <- function(p) {
  comp <- resolve_components(substitute(p), parent.frame(), p, required = TRUE)
  is_theme <- vapply(comp$objects, is_theme_component, logical(1))
  is_layer <- vapply(comp$objects, is_layer_component, logical(1))
  out <- data.frame(
    component = comp$labels,
    all = seq_along(comp$labels),
    all_but_theme = ifelse(is_theme, NA, cumsum(!is_theme)),
    layers = ifelse(is_layer, cumsum(is_layer), NA),
    stringsAsFactors = FALSE
  )
  shown <- out
  for (v in c("all", "all_but_theme", "layers")) shown[[v]] <- ifelse(is.na(out[[v]]), "-", out[[v]])
  print(shown, row.names = FALSE, right = FALSE)
  invisible(out)
}

# --- internals -------------------------------------------------------------

flatten_plus <- function(e) {
  if (is.call(e) && identical(e[[1]], as.name("+")) && length(e) == 3) {
    c(flatten_plus(e[[2]]), list(e[[3]]))
  } else {
    list(e)
  }
}

components_from_expr <- function(expr, env) {
  parts <- flatten_plus(expr)
  if (length(parts) < 2) {
    stop("The plot code has no `+` components to reveal.", call. = FALSE)
  }
  base <- eval(parts[[1]], env)
  attr(base, "gganimslide") <- NULL
  if (!is_gg(base)) {
    stop("The plot code must start with a ggplot, e.g. ggplot(df, aes(x, y)) + ...", call. = FALSE)
  }
  objects <- lapply(parts[-1], eval, envir = env)
  labels <- vapply(parts[-1], function(e) {
    txt <- paste(deparse(e, width.cutoff = 500L), collapse = " ")
    if (nchar(txt) > 60) paste0(substr(txt, 1, 57), "...") else txt
  }, character(1))
  list(base = base, objects = objects, labels = labels)
}

# find the components: plot code in the call > steps() attribute > none
resolve_components <- function(expr, env, p, required = FALSE) {
  if (is.call(expr) && identical(expr[[1]], as.name("+"))) {
    return(components_from_expr(expr, env))
  }
  comp <- attr(p, "gganimslide", exact = TRUE)
  if (!is.null(comp)) {
    rebuilt <- build_plot(comp, seq_along(comp$objects))
    if (length(rebuilt$layers) != length(p$layers)) {
      warning("The plot was changed after steps(); wrap the full plot code in steps() again.",
              call. = FALSE)
    }
    return(comp)
  }
  if (required) {
    stop(paste0(
      "This plot does not know the order of its components. Make it with steps(), ",
      "e.g. p <- steps(ggplot(df, aes(x, y)) + geom_point() + ...), or write the ",
      "plot code directly into the call."), call. = FALSE)
  }
  NULL
}

is_theme_component <- function(x) inherits(x, "theme")
is_layer_component <- function(x) inherits(x, "LayerInstance")

build_plot <- function(comp, which) {
  p <- comp$base
  attr(p, "gganimslide") <- NULL
  for (i in sort(which)) p <- p + comp$objects[[i]]
  p
}

# for scope "all" / "all_but_theme": a list of full plots, one per overlay
# (first = static part), and a label per step
component_frames <- function(comp, animate, scope) {
  is_theme <- vapply(comp$objects, is_theme_component, logical(1))
  counted <- if (scope == "all_but_theme") which(!is_theme) else seq_along(comp$objects)
  always <- if (scope == "all_but_theme") which(is_theme) else integer(0)
  st <- animation_steps(length(counted), animate)

  frames <- lapply(shown_after_each(st), function(l) build_plot(comp, c(always, counted[l])))
  step_lbl <- vapply(st$steps, function(s) {
    paste(sprintf("%d %s", s, comp$labels[counted[s]]), collapse = " + ")
  }, character(1))
  labels <- step_lbl[st$sequence$step]
  labels <- ifelse(st$sequence$action == "out", paste("remove", labels), labels)
  static_label <- if (length(st$static)) paste("static", paste(st$static, collapse = ",")) else "base"
  list(frames = frames, labels = labels, static_label = static_label)
}