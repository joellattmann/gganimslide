# categorical = TRUE: split each animation step into one sub-step per group (each bar, box, colour group, etc.). 

# the plot is built once with ggplot_build(); frames are made by filtering the *built* 
# layer data by its `group` column and turning it into a gtable with ggplot_gtable()

# scales, axes and legends are trained before that point, so every frame has the same
# layout and the pieces line up exactly

# groups of each layer (NA for layers without real groups, i.e. group == -1)
layer_groups <- function(built) {
  lapply(built$data, function(d) {
    g <- sort(unique(d$group))
    g <- g[g > 0]
    if (length(g) <= 1) NA_integer_ else as.integer(g)
  })
}

# expand the steps of animation_steps() into sub-steps
# returns list(sub = list of list(step, layers, group), seq = expanded sequence)
categorical_plan <- function(st, groups) {
  sub <- list()
  sub_of_step <- vector("list", length(st$steps))
  for (s in seq_along(st$steps)) {
    layers <- st$steps[[s]]
    g <- sort(unique(unlist(groups[layers])))
    g <- g[!is.na(g)]
    if (length(g) <= 1) {
      sub[[length(sub) + 1]] <- list(step = s, layers = layers, group = NA_integer_, first = TRUE)
    } else {
      for (i in seq_along(g)) {
        sub[[length(sub) + 1]] <- list(step = s, layers = layers, group = g[i], first = i == 1)
      }
    }
    sub_of_step[[s]] <- which(vapply(sub, function(x) x$step == s, logical(1)))
  }
  
  # one sequence row per sub-step for entrances; one row per removed step
  # (listing all of its sub-steps) for exits 
  
  # `entry` points back to the position in `animate`, so effect/trigger/duration can be looked up
  rows <- list()
  for (i in seq_len(nrow(st$sequence))) {
    s <- st$sequence$step[i]
    if (st$sequence$action[i] == "in") {
      for (j in sub_of_step[[s]]) rows[[length(rows) + 1]] <- list(action = "in", subs = j, entry = i)
    } else {
      rows[[length(rows) + 1]] <- list(action = "out", subs = sub_of_step[[s]], entry = i)
    }
  }
  list(sub = sub, seq = rows)
}

# which rows of each layer a sub-step shows: TRUE (all) or a group id
sub_spec <- function(sb, groups) {
  spec <- list()
  for (k in sb$layers) {
    has_groups <- !all(is.na(groups[[k]]))
    if (is.na(sb$group)) {
      spec[[as.character(k)]] <- TRUE
    } else if (has_groups) {
      spec[[as.character(k)]] <- sb$group
    } else if (sb$first) {
      spec[[as.character(k)]] <- TRUE # ungrouped layers come with the first group
    }
  }
  spec
}

# merge several specs (for cumulative full frames)
merge_specs <- function(specs) {
  out <- list()
  for (sp in specs) {
    for (k in names(sp)) {
      cur <- out[[k]]
      new <- sp[[k]]
      out[[k]] <- if (isTRUE(cur) || isTRUE(new)) TRUE else sort(unique(c(cur, new)))
    }
  }
  out
}

# gtable of the built plot with each layer reduced to `spec`
# (layers not in spec are emptied)
gtable_from_spec <- function(built, spec) {
  b <- built
  for (k in seq_along(b$data)) {
    d <- b$data[[k]]
    keep <- spec[[as.character(k)]]
    b$data[[k]] <- if (is.null(keep)) d[0, , drop = FALSE] else if (isTRUE(keep)) d else d[d$group %in% keep, , drop = FALSE]
  }
  g <- ggplot2::ggplot_gtable(b)
  panel_idx <- grep("^panel", g$layout$name)
  n <- length(built$data)
  lead <- (length(g$grobs[[panel_idx[1]]]$children) - n) / 2
  list(g = g, panel_idx = panel_idx, n_layers = n, lead = lead)
}

sub_label <- function(p, sb) {
  lbl <- step_labels(p, list(sb$layers))
  if (is.na(sb$group)) lbl else paste0(lbl, ", group ", sb$group)
}
