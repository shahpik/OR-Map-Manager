# MapMatching
Hidden Markov Model (HMM) map matching for LightOSM.

## Contents
- [Usage](#usage)
- [Areas for improvement](#areas-for-improvement)
- [References](#references)

## Usage
Start with a LightOSM graph and a linestring to match.
```julia
g = graph_from_download(
    :place_name, 
    network_type=:drive, 
    place_name="Victoria", 
    weight_type=:distance
)
ls = [
  [144.96162, -37.81699],
  [144.95896, -37.81772],
  [144.95853, -37.81672],
  [144.95612, -37.81733]
]
```
Match the linestring.
```julia
match = match_linestring(g, ls)
```
The resulting `MapMatch` object contains info about the match, including:
```julia
julia> match.matched_nodes
35-element Vector{Int64}:
 2180785617
 2180785597
 6167489482
          ⋮
 6407790002
 9146197604

julia> match.matched_ways
6-element Vector{Int64}:
  207831943
 1051208745
  207831319
  878771431
  208641736
  968328214

julia> match.matched_path
35-element Vector{GeoLocation}:
 GeoLocation(-37.8169305, 144.9616849, 0.0)
 GeoLocation(-37.8169685, 144.961547, 0.0)
 GeoLocation(-37.8169947, 144.9614569, 0.0)
 ⋮
 GeoLocation(-37.8173258, 144.956334, 0.0)
 GeoLocation(-37.8173523, 144.9562416, 0.0)
```
To speed up run time, you can pre-compute the R-tree and share it between 
separate matching runs. This R-tree is used internally to find nearby ways.
```julia
rtree = compute_rtree(g);
match = match_linestring(g, ls)
```

## Areas for improvement
- Make generic interface for different emission and transition probabilities 
  so other metrics can be used e.g. street names.
- Utilities to calculate optimal values for `σ` and `β`.
- Allow user input of `σ` and `β`.
- Generic typing for `OSMGraph` and node/way ID types.
- Handle breaks in the graph for increased robustness by following the process 
  described in Newson and Krumm:
  *When a break is detected between time step `t` and time step `t+1`, we 
  remove measured points `z_t` and `z_t+1` from the model, and check to see if 
  the break has been healed. The break is considered healed if the measured
  points at `t−1` and `t+2` lead to a reconnection in the HMM after
  rechecking the points with the bulleted conditions above. If the break is 
  still present, we continue to remove the points on either side of the break 
  until the break is healed.*

## References
- [P. Newson and J. Krumm, “Hidden Markov map matching through noise and sparseness,” presented at the ACM SIGSPATIAL GIS 2009, New York, NY, USA, Nov. 2009, pp. 336–343, doi: 10.1145/1653771.1653818.](https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/)
- [T. Peng, “Map Matching in a Programmer’s Perspective,” Valhalla, 2016.](https://valhalla.readthedocs.io/en/stable/meili/algorithms/)
