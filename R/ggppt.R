#' Animated PowerPoint slide from a ggplot
#'
#' Puts a saved ggplot on a PowerPoint slide as a stack of editable vector
#' shapes: one static base (axes, grid, legend, titles and the static layers)
#' and one transparent shape per animation step, all at the same position.
#' Native PowerPoint entrance animations are written for the steps, so in the
#' slide show each step appears on click (or automatically).
#'
#' @param p A saved ggplot object.
#' @param file Path of the `.pptx` to write. If `doc` is given and `file` is
#'   `NULL`, nothing is written and the updated `doc` is returned.
#' @param animate Layers at which a new step starts. Layers before the first
#'   entry are always shown; the last entry also reveals all later layers.
#'   `animate = c(3, 4, 5)` shows layers 1-2, then adds 3, then 4, then 5 and
#'   everything after it. `NULL` (default) reveals every layer on its own.
#' @param scope What the numbers in `animate` count: `"layers"` (default),
#'   `"all"` or `"all_but_theme"`. See [ggtex()] for details. With `"all"` and
#'   `"all_but_theme"` each step is a full redraw of the plot (on a `bg`
#'   background) that covers the previous one, because components such as
#'   titles or themes change the layout.
#' @param bg Background of the full redraws used by `"all"` and
#'   `"all_but_theme"`. Should match the slide background.
#' @param title Slide title. `NULL` for no title.
#' @param effect Entrance effect: `"appear"`, `"fade"`, `"wipe_left"`,
#'   `"wipe_right"`, `"wipe_up"` or `"wipe_down"`. One value, or one per step.
#' @param trigger `"click"` (default), `"after"` (after the previous step) or
#'   `"with"` (with the previous step). One value, or one per step.
#' @param duration Effect duration in seconds (ignored for `"appear"`).
#' @param doc Optional existing `rpptx` object (from [officer::read_pptx()]) to
#'   add the slide to. Lets you build a whole deck with several plots.
#' @param template Optional `.pptx` template whose theme and slide size are
#'   used for a new deck.
#' @param size Slide size of a new deck when no `template` is given:
#'   `"16:9"` (default) or `"4:3"`. Ignored when `doc` or `template` is given.
#' @param width,height Size of the plot on the slide in inches. Default: the
#'   free area below the title. Set the size here rather than by dragging in
#'   PowerPoint: dragging scales lines and points but not text, and resizing
#'   one step's shape misaligns it with the others. A full 16:9 slide is
#'   13.33 x 7.5 inches.
#' @param left,top Position of the plot's top-left corner in inches. Default:
#'   centred in the free area below the title.
#' @param location Optional officer location for the plot (overrides
#'   `width`, `height`, `left`, `top`), e.g.
#'   `officer::ph_location(left = 1, top = 1.5, width = 8, height = 5)`.
#'   Defaults to the area below the title.
#' @param editable If `TRUE`, the shapes and text of the plot can be edited
#'   in PowerPoint.
#' @param ... Further arguments for [rvg::dml()], e.g. `fonts`.
#' @return If `file` is given, its path (invisibly); otherwise the updated
#'   `rpptx` object.
#' @examples
#' \dontrun{
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(colour = "grey70") +
#'   geom_smooth(method = "lm", formula = y ~ x) +
#'   geom_point(data = subset(mtcars, mpg > 30), colour = "red")
#' ggppt(p, "fuel.pptx", animate = c(2, 3), title = "Fuel use")
#' }
#' @export
ggppt <- function(p, file = NULL, animate = NULL,
                  scope = c("layers", "all", "all_but_theme"), title = NULL,
                  effect = "appear", trigger = "click", duration = 0.5,
                  doc = NULL, template = NULL, size = c("16:9", "4:3"),
                  width = NULL, height = NULL, left = NULL, top = NULL, location = NULL,
                  editable = TRUE, bg = "white", ...) {
  scope <- match.arg(scope)
  size <- match.arg(size)
  comp <- if (scope != "layers") {
    resolve_components(substitute(p), parent.frame(), p, required = TRUE)
  }
  if (is.null(file) && is.null(doc)) stop("Give a `file` to write, or a `doc` to add the slide to.", call. = FALSE)

  if (scope == "layers") {
    gt <- plot_gtable(p)
    st <- animation_steps(gt$n_layers, animate)
    n <- length(st$steps)
    frames <- c(list(unclip_panel_border(frame_with_layers(gt, st$static), gt$n_layers)),
                lapply(st$steps, function(l) overlay_with_layers(gt, l)))
    base_label <- if (length(st$static)) {
      paste0("plot base (layers ", paste(st$static, collapse = ", "), ")")
    } else "plot base"
    labels <- c(base_label, sprintf("step %d: layer %s", seq_len(n), step_labels(p, st$steps)))
    bgs <- rep("transparent", n + 1)
  } else {
    cf <- component_frames(comp, animate, scope)
    n <- length(cf$labels)
    frames <- lapply(cf$frames, function(fp) {
      unclip_panel_border(ggplot2::ggplotGrob(fp), length(fp$layers))
    })
    labels <- c(paste("plot", cf$static_label), sprintf("step %d: %s", seq_len(n), cf$labels))
    bgs <- rep(bg, n + 1)
  }
  effect <- check_choice(rep_len(effect, n), effect_names, "effect")
  trigger <- check_choice(rep_len(trigger, n), trigger_names, "trigger")
  duration <- rep_len(duration, n)

  if (is.null(doc)) {
    if (is.null(template) && size == "16:9") {
      template <- system.file("templates", "16x9.pptx", package = "gganimslide")
    }
    doc <- officer::read_pptx(template)
  }
  if (!inherits(doc, "rpptx")) stop("`doc` must be an rpptx object from officer::read_pptx().", call. = FALSE)
  slide <- add_plot_slide(doc, title)
  doc <- slide$doc
  loc <- if (!is.null(location)) {
    officer::fortify_location(location, doc = doc)
  } else {
    place_plot(slide$location, width, height, left, top)
  }

  spids <- character(length(frames))
  for (k in seq_along(frames)) {
    fr <- frames[[k]]
    value <- rvg::dml(code = grid::grid.draw(fr), bg = bgs[k], editable = editable, ...)
    doc <- officer::ph_with(doc, value, location = officer::ph_location(
      left = loc$left, top = loc$top, width = loc$width, height = loc$height,
      newlabel = labels[k]))
    spids[k] <- last_shape_id(doc)
  }

  sld <- xml2::xml_root(current_slide_xml(doc))
  append_animations(sld, spids[-1], effect, trigger, as.integer(round(duration * 1000)))

  if (is.null(file)) return(doc)
  print(doc, target = file)
  invisible(file)
}

check_choice <- function(x, choices, arg) {
  bad <- setdiff(x, choices)
  if (length(bad)) {
    stop(sprintf("Unknown %s: %s. Use one of: %s.", arg, paste(bad, collapse = ", "),
                 paste(choices, collapse = ", ")), call. = FALSE)
  }
  x
}

add_plot_slide <- function(doc, title) {
  layouts <- officer::layout_summary(doc)
  size <- officer::slide_size(doc)
  pick <- function(name) {
    i <- which(layouts$layout == name)[1]
    if (is.na(i)) NULL else list(layout = layouts$layout[i], master = layouts$master[i])
  }
  if (!is.null(title) && !is.null(l <- pick("Title Only"))) {
    doc <- officer::add_slide(doc, layout = l$layout, master = l$master)
    doc <- officer::ph_with(doc, title, location = officer::ph_location_type("title"))
    title_loc <- officer::fortify_location(officer::ph_location_type("title"), doc = doc)
    top <- title_loc$top + title_loc$height + 0.1
    location <- list(left = 0.4, top = top, width = size$width - 0.8,
                     height = size$height - top - 0.3)
  } else {
    l <- pick("Blank")
    if (is.null(l)) l <- list(layout = layouts$layout[1], master = layouts$master[1])
    doc <- officer::add_slide(doc, layout = l$layout, master = l$master)
    if (!is.null(title)) warning("Template has no 'Title Only' layout; title not added.", call. = FALSE)
    location <- list(left = 0.3, top = 0.3, width = size$width - 0.6, height = size$height - 0.6)
  }
  list(doc = doc, location = location)
}

current_slide_xml <- function(doc) doc$slide$get_slide(doc$cursor)$get()

last_shape_id <- function(doc) {
  ns <- c(p = ns_p)
  sld <- current_slide_xml(doc)
  # officer renumbers every p:cNvPr in document order when it saves the file;
  # do the same now so the ids written into the animations stay valid.
  cnvpr <- xml2::xml_find_all(sld, "//p:cNvPr", ns)
  for (i in seq_along(cnvpr)) xml2::xml_attr(cnvpr[[i]], "id") <- i
  tree <- xml2::xml_find_first(sld, "//p:cSld/p:spTree", ns)
  kids <- xml2::xml_children(tree)
  id <- xml2::xml_attr(xml2::xml_find_first(kids[[length(kids)]], "./*[1]/p:cNvPr", ns), "id")
  if (is.na(id)) stop("Could not find the id of the inserted shape.", call. = FALSE)
  id
}

#' Start a new PowerPoint deck
#'
#' Like [officer::read_pptx()], but a new deck is 16:9 by default (officer's
#' own default is 4:3). Use it to build a deck with several plots via the `doc`
#' argument of [ggppt()].
#'
#' @param size `"16:9"` (default) or `"4:3"`. Ignored if `template` is given.
#' @param template Optional `.pptx` template (its own size is kept).
#' @return An `rpptx` object.
#' @examples
#' \dontrun{
#' doc <- ppt_deck()
#' doc <- ggppt(p1, doc = doc, title = "First")
#' doc <- ggppt(p2, doc = doc, title = "Second")
#' print(doc, target = "talk.pptx")
#' }
#' @export
ppt_deck <- function(size = c("16:9", "4:3"), template = NULL) {
  size <- match.arg(size)
  if (is.null(template) && size == "16:9") {
    template <- system.file("templates", "16x9.pptx", package = "gganimslide")
  }
  officer::read_pptx(template)
}

# Fit a plot of the given size into the free area (centred unless left/top given).
place_plot <- function(area, width, height, left, top) {
  w <- if (is.null(width)) area$width else width
  h <- if (is.null(height)) area$height else height
  list(
    left = if (is.null(left)) area$left + (area$width - w) / 2 else left,
    top = if (is.null(top)) area$top + (area$height - h) / 2 else top,
    width = w, height = h
  )
}
