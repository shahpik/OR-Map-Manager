# MapOrchestrator

Contents:
- [MapOrchestrator](#maporchestrator)
  - [Template Overview](#template-overview)
    - [Structure](#structure)
    - [The `src` folder](#the-src-folder)
    - [Default Routes and Handling](#default-routes-and-handling)
    - [Asynchronous behaviour](#asynchronous-behaviour)
    - [Environment Variables](#environment-variables)
    - [Running the Application](#running-the-application)
    - [Building the Application](#building-the-application)
    - [Building Application Documents](#building-application-documents)
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
- `bin` folder containing examples
- `deploy` folder containing scripts to build application
- `Makefile`, `Dockerfile` and `docker-compose.yaml` examples

### The `src` folder

The `src` folder contains the following files:

- `MapOrchestrator.jl` is the top level file for the microservice
- `Resource.jl` contains the majority of the HTTP interface. For simple uses, this will not need much editing.
- `Workers.jl` provides a macro that enables requests to be performed on other threads to the main thread,
    leaving the main thread for the handling of requests.
- `App.jl` should contain the application code. Additional files can be `include`d if there is too much code
for one file
- `AppTypes.jl` is a suggested location for any custom `struct`s that are required for the application.
- `Logger.jl` initialises a logger for the module, using the standard Julia `Logging.jl`

The way the module is architected, `Resouce`, `Workers`, `App`, `AppTypes` and `Logger` are all
individual modules which are loaded into `MapOrchestrator` by using, for example

```
using .Resource
```

The `.` indicates that this module is in the local scope, and not in a registry. These "sub" modules can load another sub module by using `..` (see how `App` uses `AppTypes`). The double dot indicates that the module is in the parent scope of the module that is trying to use it.

### Default Routes and Handling

The template contains three default routes:

1. `/live`

Returns "OK", used to test that the microservice is running.

2. `/ready`

Checks to see if the microservice is ready to run. By default, this checks
that the Experiment Manager is ready to run by checking its corresponding
ready endpoint.

3. `/execute`

Runs `App.execute_app(req)`. More explicitly, this route runs `Resource.execute_app`
which in turn calls `App.execute_app`. The template shows three way basic ways in
which `App.execute_app` can be called by `Resource.execute_app`:

```julia
# Run asynchronously on any thread except for the main thread, output not needed
function execute_app(req)
    Workers.@async(App.execute_app(req))
    return "App executed"
end

# Run asynchronously on any thread except for the main thread, output is needed
execute_app(req) = fetch(Workers.@async(App.execute_app(req)))

# Run synchronously
execute_app(req) = App.execute_app(req)
```

More generally, requests to routes are handled by the request handler defined in
`Resource`. The handler accepts different response types from the called
function:

1. A string message, which is returned along with the status code 200 (i.e. everything is OK).
2. A variable, which is encoded to JSON and returned along with the status code 200 (i.e. everything is OK).
3. A tuple pair, with the first element being the status code and the second being a variable
    returned as per either 1. or 2.
4. A `HTTP.Messages.Reponse`, allowing full configuration of the response.

This means that `App.execute_app` should return one of these options.

To see how to add new routes, see [Adding Routes](#adding-routes)

### Asynchronous behaviour

The template provides a submodule `Workers` which can be used to control
asynchronous behaviour.

The main HTTP server will always run on thread 1. If a route runs an expensive
or lengthy function, this will block this thread and therefore holdup further
HTTP requests.

The `Workers.@async` macro can be used to pass a task to a any thread except
for thread 1, leaving the HTTP server always available to handle requests. Note,
if the queue becomes full (set in `Workers`), then this macro will end up
blocking thread 1. However the default queue length is large (1000).

Either the base `@async` macro or `Workers.@async` can be used within functions
called by `Workers.@async` to further share out tasks amongst threads. However
doing this may block other threads, so this must be done with care.

### Environment Variables
The following environment variables can be configured for the image in `docker-compose.yaml`:

| Name | Description |
|------|------------ |
| EXPERIMENT_MANAGER_ENDPOINT | Experiment Manager endpoint|
| EXPERIMENT_MANAGER_WS_ENDPOINT | Experiment Manager websocket endpoint |
| APP_PORT | Port to be used by the microservice |
| APP_ADDRESS | Address to be used by the microservice |
| LOG_LEVEL | Logging level, can be DEBUG, INFO, WARN or ERROR |
| JULIA_NUM_THREADS | Number of threads available to Julia |

If running from the REPL, system environment variables will be used and if they are not set, default values will be used.

### Running the Application

The application can be run in the REPL by:

```julia
julia> using MapOrchestrator
julia> MapOrchestrator.run()
```

If a docker image has been built, it can be started with:

```
$ docker-compose up
```

### Building the Application

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

### Building Application Documents

Julia allows for quick automatic creation of documentation. This template is configured to
produce documentation by running `docs/make.jl`. The generated Markdown documentation can
then be found at `docs/build/index.md`.

For further information see https://juliadocs.github.io/Documenter.jl/stable/.

## Template Version Used

This application generated with or-sdk JuliaAppTemplate v0.2.39