# automatic recording of plot components.

# every `plot + component` in ggplot2 (3.x and 4.x) goes through the internal
# function ggplot2:::add_ggplot(p, object, objectname). while gganimslide is
# loaded, that function is wrapped so each new plot remembers its base plot and
# the components added to it, in order. that is what scope = "all" and
# scope = "all_but_theme" need, so plots no longer have to be wrapped in
# steps(). turn it off with options(gganimslide.record = FALSE) before loading

.recorder <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  if (!isFALSE(getOption("gganimslide.record", TRUE))) install_recorder()
}

.onUnload <- function(libpath) remove_recorder()

install_recorder <- function() {
  ns <- asNamespace("ggplot2")
  if (!exists("add_ggplot", envir = ns, inherits = FALSE)) return(invisible(FALSE))
  orig <- get("add_ggplot", envir = ns, inherits = FALSE)
  if (isTRUE(attr(orig, "gganimslide_recorder"))) return(invisible(TRUE))
  if (!identical(names(formals(orig)), c("p", "object", "objectname"))) return(invisible(FALSE))
  .recorder$orig <- orig

  recording_add_ggplot <- function(p, object, objectname) {
    out <- .recorder$orig(p, object, objectname)
    tryCatch(out <- record_component(p, out, object, objectname),
             error = function(e) NULL)
    out
  }
  attr(recording_add_ggplot, "gganimslide_recorder") <- TRUE
  replace_binding(ns, "add_ggplot", recording_add_ggplot)
  invisible(TRUE)
}

remove_recorder <- function() {
  if (is.null(.recorder$orig)) return(invisible(FALSE))
  ns <- asNamespace("ggplot2")
  replace_binding(ns, "add_ggplot", .recorder$orig)
  .recorder$orig <- NULL
  invisible(TRUE)
}

replace_binding <- function(ns, name, value) {
  locked <- bindingIsLocked(name, ns)
  if (locked) get("unlockBinding", baseenv())(name, ns)
  assign(name, value, envir = ns)
  if (locked) lockBinding(name, ns)
}

record_component <- function(p, out, object, objectname) {
  if (is.null(object)) return(out)
  hist <- attr(p, "gganimslide", exact = TRUE)
  if (is.null(hist)) {
    base <- p
    attr(base, "gganimslide") <- NULL
    hist <- list(base = base, objects = list(), labels = character(0))
  }
  hist$objects <- c(hist$objects, list(object))
  hist$labels <- c(hist$labels, short_label(objectname))
  attr(out, "gganimslide") <- hist
  out
}

short_label <- function(txt) {
  txt <- gsub("\\s+", " ", paste(txt, collapse = " "))
  if (nchar(txt) > 60) paste0(substr(txt, 1, 57), "...") else txt
}
