library(ggplot2)

p6 <- ggplot(mtcars, aes(wt, mpg)) +
  geom_hline(yintercept = 20) + geom_vline(xintercept = 3) +
  geom_point() + geom_smooth(method = "lm", formula = y ~ x) +
  geom_rug() + geom_text(aes(label = cyl))

test_that("animate = c(3, 4, 5) gives static 1:2, then 3, 4, and 5 onwards", {
  st <- animation_steps(6, c(3, 4, 5))
  expect_equal(st$static, 1:2)
  expect_equal(st$steps, list(3L, 4L, 5:6))
})

test_that("default animates every layer; bad input errors", {
  expect_equal(animation_steps(3)$steps, list(1L, 2L, 3L))
  expect_length(animation_steps(3)$static, 0)
  expect_error(animation_steps(3, 4), "between 1 and 3")
  expect_error(animation_steps(3, c(2, 2)), "duplicate")
  expect_warning(animation_steps(3, c(3, 2)), "sorted")
})

test_that("ggtex writes one PDF page per overlay and beamer code", {
  f <- tempfile(fileext = ".pdf")
  code <- capture.output(res <- ggtex(p6, f, animate = c(3, 4, 5)))
  expect_true(file.exists(f))
  expect_match(res, "\\\\only<1>")
  expect_match(res, "\\\\only<4->\\{\\\\includegraphics\\[width=\\\\linewidth,page=4\\]")
  expect_false(grepl("only<5", res))
})

test_that("ggppt writes animations that target the step shapes", {
  skip_if_not_installed("officer")
  skip_if_not_installed("rvg")
  f <- tempfile(fileext = ".pptx")
  ggppt(p6, f, animate = c(3, 4, 5), title = "Test")
  d <- tempfile(); utils::unzip(f, exdir = d)
  x <- xml2::read_xml(file.path(d, "ppt/slides/slide1.xml"))
  ns <- xml2::xml_ns(x)
  spids <- unique(xml2::xml_attr(xml2::xml_find_all(x, "//p:timing//p:spTgt", ns), "spid"))
  expect_length(spids, 3)
  names <- vapply(spids, function(id) xml2::xml_attr(
    xml2::xml_find_first(x, sprintf("//p:cNvPr[@id='%s']", id), ns), "name"), "")
  expect_match(names[1], "^step 1: layer 3")
  expect_match(names[2], "^step 2: layer 4")
  expect_match(names[3], "^step 3: layer 5 .*6 geom_text")
})

test_that("steps() stores components; scopes count them correctly", {
  p <- steps(ggplot(mtcars, aes(wt, mpg)) + geom_point() + labs(title = "A") +
               theme_minimal() + geom_smooth(method = "lm", formula = y ~ x))
  f <- tempfile(fileext = ".rds"); saveRDS(p, f); p <- readRDS(f)
  comp <- attr(p, "gganimslide")
  expect_length(comp$objects, 4)
  cf <- component_frames(comp, c(2, 3, 4), "all")
  expect_length(cf$frames, 4)
  expect_null(cf$frames[[1]]$labels$title)
  expect_equal(cf$frames[[2]]$labels$title, "A")
  cf2 <- component_frames(comp, c(2, 3), "all_but_theme")
  expect_length(cf2$frames, 3)
  expect_match(cf2$labels[2], "geom_smooth")
})

test_that("components are recorded automatically and survive saveRDS", {
  q <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + labs(title = "C") + theme_bw()
  f <- tempfile(fileext = ".rds"); saveRDS(q, f); q <- readRDS(f)
  comp <- attr(q, "gganimslide")
  expect_equal(comp$labels, c("geom_point()", "labs(title = \"C\")", "theme_bw()"))
  expect_length(component_frames(comp, 2, "all")$frames, 2)
})

test_that("scope = 'all' errors helpfully without a recorded history", {
  q <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  attr(q, "gganimslide") <- NULL
  expect_error(ggtex(q, tempfile(fileext = ".pdf"), scope = "all"), "steps\\(\\)")
  f <- tempfile(fileext = ".pdf")
  out <- capture.output(ggtex(ggplot(mtcars, aes(wt, mpg)) + geom_point() + labs(title = "B"),
                              f, animate = 2, scope = "all"))
  expect_true(file.exists(f))
})

test_that("negative numbers remove steps again", {
  st <- animation_steps(6, c(3, 4, 5, -3))
  expect_equal(st$steps, list(3L, 4L, 5:6))
  expect_equal(st$sequence$action, c("in", "in", "in", "out"))
  expect_equal(st$sequence$step, c(1L, 2L, 3L, 1L))
  expect_equal(shown_after_each(st)[[5]], c(1:2, 4L, 5:6))
  expect_error(animation_steps(6, c(3, -4)), "no step starts")
  expect_error(animation_steps(6, c(-3, 3)), "before it has appeared")
  expect_error(animation_steps(6, c(1, 2, -1, 1)), "duplicate")
})

test_that("ggppt writes exit animations; ggtex drops the layer", {
  f <- tempfile(fileext = ".pptx")
  ggppt(p6, f, animate = c(3, 4, -3), effect = c("fade", "fade", "fade"))
  d <- tempfile(); utils::unzip(f, exdir = d)
  x <- paste(readLines(file.path(d, "ppt/slides/slide1.xml"), warn = FALSE), collapse = "")
  expect_match(x, 'presetClass="exit"')
  expect_match(x, 'transition="out"')
  expect_match(x, 'val="hidden"')
  pdf <- tempfile(fileext = ".pdf")
  out <- capture.output(code <- ggtex(p6, pdf, animate = c(3, 4, -3)))
  expect_match(code, "page=4")
  expect_false(grepl("page=5", code))
})
