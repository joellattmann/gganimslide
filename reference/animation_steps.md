# Work out the animation steps from \`animate\`

Positive numbers in \`animate\` are the layers at which a new step
starts. Layers before the first positive number are static. Each step
shows its layer and every following layer up to the next positive
number; the last one also shows all layers after it. A negative number
\`-k\` removes the step that started at layer \`k\` again (it fades out,
or disappears). The entries are played in the order given.

## Usage

``` r
animation_steps(n_layers, animate = NULL)
```

## Arguments

- n_layers:

  Number of layers in the plot.

- animate:

  \`NULL\` (every layer is its own step) or an integer vector.

## Value

A list with \`static\` (layers always shown), \`steps\` (list of layer
vectors, one per step that appears) and \`sequence\` (data frame with
one row per entry: \`action\` \`"in"\` or \`"out"\`, and the \`step\` it
refers to).

## Examples

``` r
# Six layers, animate = c(3, 4, 5):
# layers 1-2 static, then 3, then 4, then 5 and 6 together
animation_steps(6, c(3, 4, 5))
#> $static
#> [1] 1 2
#> 
#> $steps
#> $steps[[1]]
#> [1] 3
#> 
#> $steps[[2]]
#> [1] 4
#> 
#> $steps[[3]]
#> [1] 5 6
#> 
#> 
#> $sequence
#>   action step
#> 1     in    1
#> 2     in    2
#> 3     in    3
#> 

# ... and then layer 3 disappears again
animation_steps(6, c(3, 4, 5, -3))
#> $static
#> [1] 1 2
#> 
#> $steps
#> $steps[[1]]
#> [1] 3
#> 
#> $steps[[2]]
#> [1] 4
#> 
#> $steps[[3]]
#> [1] 5 6
#> 
#> 
#> $sequence
#>   action step
#> 1     in    1
#> 2     in    2
#> 3     in    3
#> 4    out    1
#> 
```
