# Start a new PowerPoint deck

Like \[officer::read_pptx()\], but a new deck is 16:9 by default
(officer's own default is 4:3). Use it to build a deck with several
plots via the \`doc\` argument of \[ggppt()\].

## Usage

``` r
ppt_deck(size = c("16:9", "4:3"), template = NULL)
```

## Arguments

- size:

  \`"16:9"\` (default) or \`"4:3"\`. Ignored if \`template\` is given.

- template:

  Optional \`.pptx\` template (its own size is kept).

## Value

An \`rpptx\` object.

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- ppt_deck()
doc <- ggppt(p1, doc = doc, title = "First")
doc <- ggppt(p2, doc = doc, title = "Second")
print(doc, target = "talk.pptx")
} # }
```
