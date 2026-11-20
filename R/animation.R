# writing native powerpoint entrance animations (<p:timing>) into slide xml

ns_p <- "http://schemas.openxmlformats.org/presentationml/2006/main"
ns_a <- "http://schemas.openxmlformats.org/drawingml/2006/main"
ns_r <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

effect_spec <- function(effect) {
  switch(effect,
    appear     = list(preset = 1,  subtype = 0, filter = NA),
    fade       = list(preset = 10, subtype = 0, filter = "fade"),
    wipe_left  = list(preset = 22, subtype = 8, filter = "wipe(left)"),
    wipe_right = list(preset = 22, subtype = 2, filter = "wipe(right)"),
    wipe_up    = list(preset = 22, subtype = 4, filter = "wipe(down)"),
    wipe_down  = list(preset = 22, subtype = 1, filter = "wipe(up)"),
    stop("Unknown effect '", effect, "'.", call. = FALSE)
  )
}

effect_names <- c("appear", "fade", "wipe_left", "wipe_right", "wipe_up", "wipe_down")
trigger_names <- c("click", "with", "after")

# one effect as an xml string; cTn ids are placeholders ("ID") renumbered later
# entrance: make visible, then run the filter "in". exit: run the filter
# "out", then hide the shape when it has finished
effect_xml <- function(spid, effect, node_type, dur_ms, exit = FALSE) {
  s <- effect_spec(effect)
  has_filter <- !is.na(s$filter)
  set_delay <- if (exit && has_filter) max(dur_ms - 1L, 0L) else 0L
  set <- sprintf(paste0(
    '<p:set><p:cBhvr><p:cTn id="ID" dur="1" fill="hold"><p:stCondLst><p:cond delay="%d"/></p:stCondLst></p:cTn>',
    '<p:tgtEl><p:spTgt spid="%s"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst>',
    '</p:cBhvr><p:to><p:strVal val="%s"/></p:to></p:set>'),
    set_delay, spid, if (exit) "hidden" else "visible")
  anim <- if (!has_filter) "" else sprintf(paste0(
    '<p:animEffect transition="%s" filter="%s"><p:cBhvr><p:cTn id="ID" dur="%d"/>',
    '<p:tgtEl><p:spTgt spid="%s"/></p:tgtEl></p:cBhvr></p:animEffect>'),
    if (exit) "out" else "in", s$filter, dur_ms, spid)
  body <- if (exit) paste0(anim, set) else paste0(set, anim)
  sprintf(paste0(
    '<p:par><p:cTn id="ID" presetID="%d" presetClass="%s" presetSubtype="%d" fill="hold" nodeType="%s">',
    '<p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>%s</p:childTnLst></p:cTn></p:par>'),
    s$preset, if (exit) "exit" else "entr", s$subtype, node_type, body)
}

# existing animation sequence on a slide, as a list of click groups. each group
# is a list of "sub-steps" (things that start at the same time) with a start
# delay (ms), an end time (ms) and the effect xml strings
read_sequence <- function(sld) {
  ns <- c(p = ns_p)
  groups <- xml2::xml_find_all(sld,
    "./p:timing//p:cTn[@nodeType='mainSeq']/p:childTnLst/p:par", ns)
  lapply(groups, function(gr) {
    subs <- xml2::xml_find_all(gr, "./p:cTn/p:childTnLst/p:par", ns)
    lapply(subs, function(sb) {
      delay <- as.numeric(xml2::xml_attr(
        xml2::xml_find_first(sb, "./p:cTn/p:stCondLst/p:cond", ns), "delay"))
      if (is.na(delay)) delay <- 0
      effects <- xml2::xml_find_all(sb, "./p:cTn/p:childTnLst/p:par", ns)
      durs <- as.numeric(xml2::xml_attr(xml2::xml_find_all(sb, ".//p:cBhvr/p:cTn", ns), "dur"))
      list(delay = delay, end = delay + max(c(1, durs), na.rm = TRUE),
           effects = vapply(effects, function(e) as.character(e, options = "no_declaration"), ""))
    })
  })
}

# add animations for shapes `spids` to the slide's main sequence
append_animations <- function(sld, spids, effect, trigger, dur_ms, exit = rep(FALSE, length(spids))) {
  groups <- read_sequence(sld)
  for (k in seq_along(spids)) {
    trg <- trigger[k]
    if (trg != "click" && length(groups) == 0) trg <- "click"
    node_type <- switch(trg, click = "clickEffect", with = "withEffect", after = "afterEffect")
    eff <- effect_xml(spids[k], effect[k], node_type, dur_ms[k], exit = exit[k])
    end_dur <- if (effect[k] == "appear") 1 else dur_ms[k]
    if (trg == "click") {
      groups[[length(groups) + 1]] <- list(list(delay = 0, end = end_dur, effects = eff))
    } else {
      g <- groups[[length(groups)]]
      last <- g[[length(g)]]
      if (trg == "with") {
        last$effects <- c(last$effects, eff)
        last$end <- max(last$end, last$delay + end_dur)
        g[[length(g)]] <- last
      } else {
        g[[length(g) + 1]] <- list(delay = last$end, end = last$end + end_dur, effects = eff)
      }
      groups[[length(groups)]] <- g
    }
  }
  write_timing(sld, groups)
}

write_timing <- function(sld, groups) {
  group_xml <- vapply(groups, function(g) {
    subs <- vapply(g, function(sb) sprintf(paste0(
      '<p:par><p:cTn id="ID" fill="hold"><p:stCondLst><p:cond delay="%d"/></p:stCondLst>',
      '<p:childTnLst>%s</p:childTnLst></p:cTn></p:par>'),
      as.integer(sb$delay), paste(sb$effects, collapse = "")), "")
    sprintf(paste0(
      '<p:par><p:cTn id="ID" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst>',
      '<p:childTnLst>%s</p:childTnLst></p:cTn></p:par>'), paste(subs, collapse = ""))
  }, "")

  txt <- sprintf(paste0(
    '<p:timing xmlns:a="%s" xmlns:r="%s" xmlns:p="%s"><p:tnLst><p:par>',
    '<p:cTn id="ID" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>',
    '<p:seq concurrent="1" nextAc="seek"><p:cTn id="ID" dur="indefinite" nodeType="mainSeq"><p:childTnLst>',
    '%s',
    '</p:childTnLst></p:cTn>',
    '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>',
    '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>',
    '</p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>'),
    ns_a, ns_r, ns_p, paste(group_xml, collapse = ""))

  # strip namespace declarations copied along with old effect nodes, then
  # number every cTn sequentially (powerpoint requires unique ids)
  txt <- gsub(' xmlns:[a-z]+="[^"]*"', "", txt)
  txt <- sub("<p:timing", sprintf('<p:timing xmlns:a="%s" xmlns:r="%s" xmlns:p="%s"', ns_a, ns_r, ns_p), txt, fixed = TRUE)
  txt <- renumber_ctn(txt)
  new_node <- xml2::read_xml(txt)

  ns <- c(p = ns_p)
  old <- xml2::xml_find_first(sld, "./p:timing", ns)
  if (!inherits(old, "xml_missing")) {
    xml2::xml_replace(old, new_node)
  } else {
    ext <- xml2::xml_find_first(sld, "./p:extLst", ns)
    if (!inherits(ext, "xml_missing")) {
      xml2::xml_add_sibling(ext, new_node, .where = "before")
    } else {
      xml2::xml_add_child(sld, new_node)
    }
  }
  invisible(sld)
}

renumber_ctn <- function(txt) {
  parts <- strsplit(txt, '<p:cTn id="[^"]*"', perl = TRUE)[[1]]
  if (length(parts) == 1) return(txt)
  out <- parts[1]
  for (i in seq_along(parts)[-1]) out <- paste0(out, '<p:cTn id="', i - 1, '"', parts[i])
  out
}
