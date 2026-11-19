library(ggplot2)
library(hexSticker)
library(showtext)

font_add_google("Orbitron", "orbitron")
showtext_auto()
showtext_opts(dpi = 300)

d <- data.frame(x = 1:4, y = c(2, 3, 4, 5), a = c(0.25, 0.5, 0.75, 1))
g <- ggplot(d, aes(x, y, alpha = a)) +
  geom_col(fill = "white", width = 0.7) +
  scale_alpha_identity() +
  theme_void()

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

sticker(
  g,
  package = "gganimslide",
  p_family = "orbitron",
  p_fontface = "bold",
  p_size = 4.5,
  p_y = 1.45,
  p_color = "#FFFFFF",
  s_x = 1, s_y = 0.8, s_width = 1.1, s_height = 0.75,
  h_fill = "#002FA7",
  h_color = "#F2FF00",
  h_size = 1.8,
  filename = "man/figures/logo.png") 