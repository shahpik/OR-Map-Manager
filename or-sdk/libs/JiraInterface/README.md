# JiraInterface

Contents:
- [JiraInterface](#julialibrarytemplate)
  - [Template Overview](#template-overview)
    - [Structure](#structure)
    - [The `src` folder](#the-src-folder)
    - [Building Library Documents](#building-library-documents)
  - [Template Version Used](#template-version-used)

## Template Overview
### Structure

This microservice follows the standard layout for a Julia package. For a fuller description see https://julialang.github.io/Pkg.jl/v1/creating-packages/.

In summary, it contains the following:
- `src` folder containing application code
- `tests` folder containing unit tests
- `docs` folder containing document generation scripts and files
- `Project.toml` file which contains the UUID (universally unique identifier) and its dependencies, amongst other information. (See https://julialang.github.io/Pkg.jl/v1/toml-files/ for more info)

Additionally, it contains:
- `Makefile` which contains commands to register new version in the OR Core Julia Registry

### The `src` folder

The `src` folder contains the following files:

- `JiraInterface.jl` is the top level file for the library.

### Building Library Documents

Julia allows for quick automatic creation of documentation. This template is configured to
produce documentation by running `docs/make.jl`. The generated Markdown documentation can
then be found at `docs/build/index.md`.

For further information see https://juliadocs.github.io/Documenter.jl/stable/.

## Template Version Used

This application generated with or-sdk JuliaAppTemplate v0.2.25