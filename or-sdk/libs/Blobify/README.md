# Blobify

Blobify contains functions to calculate various fields of a `Blob`, i.e. the parameter
structure used by our simulations.

It is the intention that `Blob` itself will eventually be defined in this library, but
not yet.

Thank you to Jackson Calvert-Lane for the naming inspiration.

## Installation

Once the [OR Core Julia Registry is installed](https://hub.deloittedigital.com.au/stash/projects/CORE/repos/or-core-julia-registry/browse), install using the package manager:

```julia
julia> using Pkg
julia> Pkg.add("Blobify")
```

## Notes on use

### Inbounds

All of the functions defined here are annotated with `Base.@propagate_inbounds`. This
ensures that if they propagate the inbounds state from their calling function, rather
than `@inbounds` not being passed through. For further info, see the Julia docs
[here](https://docs.julialang.org/en/v1/base/base/#Base.@propagate_inbounds) and
[here](https://docs.julialang.org/en/v1/devdocs/boundscheck/#eliding-bounds-checks).

### Threads

Some of the functions here benefit hugely from being able to multithread their `for`
loops. Rather than just using `@threads`, which would use all available threads,
the functions in this package use a custom numer of threads as specified by the
constant `MULTITHREAD_RANGE[]`. This allows some threads to be left for other purposes,
e.g. HTTP communication.

`MULTITHREAD_RANGE[]` can be updated in two ways.

1. Enviroment Variables

Upon initialisation of `Blobify`, the environment variables `MULTITHREAD_START` and
`MULTITHREAD_END` are checked. If they exist, they are parsed as integers into
`MULTITHREAD_RANGE[]`.

2. Using `Blobify.set_multithread_range`

The function `Blobify.set_multithread_range` can be used to set the range. Typically
for OR microservices that already make use of `Workers.@threads`, this can be used as
follows:

```julia
using .Workers
using Blobify

Blobify.set_multithread_range(Workers.MULTITHREAD_RANGE[])
```

### Breaking changes from 0.1.x to 0.2.0
The folowing breaking changes to intersection detection from 0.1.x to 0.2.0:
- `Intersection` struct:
  - `centroid_locations` field is deprecated, use `Intersection.nodes[id].location` instead
  - `inc_highway_types` field is deprecated, use `Blobify.inc_highway_types` function instead
  - `out_highway_types` field is deprecated, use `Blobify.out_highway_types` function instead
  - `is_roundabout` field is deprecated, use `Intersection.type <: RoundaboutIntersection` instead
  - `roundabout_ways` field is deprecated, use `Intersection.internal_ways` instead
- `get_intersection_centroid_location` function is deprecated, use `get_intersection_centre_location` instead

## Developers

To register a new version:

1. Make sure the commit is final (i.e. rebased/squashed) and won't change.
2. Make sure `Project.toml` version number is updated.
3. Run the `make register-version` command, and then
submit a pull request with the created branch to the [OR Core Julia Registry](https://hub.deloittedigital.com.au/stash/projects/CORE/repos/or-core-julia-registry/browse).

This make command creates a new branch in the registry, registers the new
version of `Blobify`, pushes the change and then checks out `master` so
your copy of the registry is unaffected. If the make command fails for
any reason, the branch(es) are deleted and `master` checked out.
