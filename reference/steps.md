# Remember the order of a plot's components

Wrap the code that makes a plot in \`steps()\` to store the order of its
\`+\` components inside the plot. The result is a normal ggplot (you can
print, save and \`readRDS()\` it), and \[ggppt()\] / \[ggtex()\] can
later reveal any of its components with \`scope = "all"\` or \`scope =
"all_but_theme"\`.

## Usage

``` r
steps(plot)
```

## Arguments

- plot:

  The code that makes the plot, e.g. \`ggplot(df, aes(x, y)) +
  geom_point() + labs(title = "A")\`.

## Value

The plot, with the component order stored as an attribute.

## Details

Only needed for these two scopes. With the default \`scope = "layers"\`,
any saved ggplot works without \`steps()\`.

## Examples

``` r
library(ggplot2)
p <- steps(
  ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +                                  # 1
    labs(title = "Fuel use") +                      # 2
    theme_minimal() +                               # 3
    geom_smooth(method = "lm", formula = y ~ x)     # 4
)
plot_components(p)
#>  component                                   all all_but_theme layers
#>  geom_point()                                1   1             1     
#>  labs(title = "Fuel use")                    2   2             -     
#>  theme_minimal()                             3   -             -     
#>  geom_smooth(method = "lm", formula = y ~ x) 4   3             2     
```
