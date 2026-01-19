# MapMatcher

Contents:
- [MapMatcher](#mapmatcher)
  - [Map Matcher Functionalities](#map-matcher-functionalities)
    - [Map Matching Layer Retrieval](#map-matching-layer-retrieval)
    - [Map Matching Operation](#map-matching-operation)
    - [Map Match Data Load](#map-match-data-load)
    - [Map Matcher Endpoints](#map-matcher-endpoints)
    - [Get Started](#get-started)
    - [Running the Application](#running-the-application)
    - [Building the Application](#building-the-application)
    - [Building Application Documents](#building-application-documents)
  - [Template Version Used](#template-version-used)

## Map
### Map Matcher Functionalities
The following listed the overall goal and functionalities of Map Matcher.

#### Map Matching Layer Retrieval
Map Matcher microservice is able to import source layers and OSM as files from the database.

#### Map Matching Operation
Source layers can be matched against the OSM base layer and map matching statistics can be produced. 

#### Map Match Data Load
Matched data and statistics can be loaded to the Map Manager database and should be able to retrieved from GraphQL.

### Map Matcher Endpoints
To be discussed.

### Get Started

#### Running the Application
The application can be run in the REPL by:

```julia
julia> using MapMatcher
julia> MapMatcher.run()
```

If a docker image has been built, it can be started with:

```
$ docker-compose up
```

#### Building the Application

Currently three build targets are supplied. These require docker to use your SSH
credentials to connect to the Optimal Reality Julia Registry. If you use an SSH agent,
this will be picked up automatically. If not, specifiy the location of your key in
the environment variable `OR_JULIA_REGISTRY_SSH_DIR`, by adding something like this
to your bash profile

```
OR_JULIA_REGISTRY_SSH_DIR=~/.ssh/id_rsa
```

This will not be copied into the container, it will just be used for the builds.

1) `make build`

Builds a docker image with a Julia `sysimage`. A system image is a way of speeding up the
loading of a Julia Package and the initial execution its functions. The functions that
are used in the precompile file (`precompile_execution_file` argument of `create_sysimage`)
are precompiled. By default in this template, the precompilation file includes all the
tests in `test/runtests.jl`. (See `deploy/packagecompile.jl` and `deploy/precompile.jl`).

Sometimes, the building of a Julia sysimage may take too long to do locally, in which
case Azure pipelines can be configured to build the system image and save it to an
artifact feed. If this approach is desired, see the commented out `build` target in
`Makefile` and the corresponding build stage in `azure-pipelines.yaml`. This will require
the SSH keys to be set in the pipeline.

1) `make build-test`

Builds a docker image without the Julia system image. This is much faster and useful for testing,
but will result in a slower microservice.

3) `make build-app`

Rather than building a docker image, this builds a Julia App inside a docker container. This app
can be then be run in another docker container. **this process had not been fully realised in
this template yet**.

#### Building Application Documents

Julia allows for quick automatic creation of documentation. This template is configured to
produce documentation by running `docs/make.jl`. The generated Markdown documentation can
then be found at `docs/build/index.md`.

For further information see https://juliadocs.github.io/Documenter.jl/stable/.

### Template Version Used

This application generated with or-sdk JuliaAppTemplate v0.2.37