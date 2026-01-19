# WhosNext

This machine learning, AI based framework will leverage the latest theoretical and 
technological advances to select who will be next from a list of names. 

Choose from `reprinter`, `knock_out`,`roll_the_dice`, `olympic_sprint` or 
`dropping_like_flies`. Can't decide? It's a hard choice. Just use `tell_me_what_to_play`. 

Tension can always be increased by upping `t`.

## Usage
```julia
using WhosNext

```

## Development
How to make a new game:
1. Make a copy of `WhosNextTemplate.jl` in the `/src/games` folder with your game's name.
2. Update the following things:
    * Module name
    * `WHOSNEXT_TITLE`
    * `WHOSNEXT_AUTHOR`
    * `WHOSNEXT_FUNCTION`
    * `WHOSNEXT_DESCRIPTION`
3. Write your code in the `run()` function. Add any helper functions above.
4. Add your module name to the `STRATS` variable in `WhosNext.jl`.
