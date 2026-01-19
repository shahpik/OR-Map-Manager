# Julia Microservice Application Template

This package has functions for creating template microservices (application)
and template libraries.

Contents:
- [Julia Microservice Application Template](#julia-microservice-application-template)
  - [Generating a New App](#generating-a-new-app)
  - [Generating a New Library](#generating-a-new-library)
  - [Pre-requisites](#pre-requisites)
      - [Connecting to Optimal Reality Julia Registry](#connecting-to-optimal-reality-julia-registry)
  - [Application Template Overview](#application-template-overview)
    - [Structure](#structure)
    - [The `src` folder](#the-src-folder)
    - [Default Routes and Handling](#default-routes-and-handling)
    - [Asynchronous behaviour](#asynchronous-behaviour)
    - [Environment Variables](#environment-variables)
  - [Developing the Application](#developing-the-application)
      - [Adding Functions](#adding-functions)
      - [Adding Routes](#adding-routes)
    - [Running the Application](#running-the-application)
    - [Building the Application](#building-the-application)
    - [Example Application Functions](#example-application-functions)
  - [Building Application and Library Documentation](#building-application-and-library-documentation)
  - [Future Improvements to Template](#future-improvements-to-template)

## Generating a New App

To generate a new app, start a Julia REPL in the location where you want your
new app and run

```julia
julia> using JuliaAppTemplate
julia> JuliaAppTemplate.generate("MyApp", "5900")
```

This will generate a new folder called `MyApp` which is a Julia package that
will run at port `5900`. 

## Generating a New Library

To generate a new library, start a Julia REPL in the location where you want your
new app and run

```julia
julia> using JuliaAppTemplate
julia> JuliaAppTemplate.generate_library("MyLib")
```

This will generate a new folder called `MyLib` containing the library.

The library is the bare-bones shell of a Julia package, with placeholder
[documentation](#building-application-and-library-documentation) and a
`makefile` for registering a new version with the OR Core Julia Registry.

## Pre-requisites

1) Julia 1.5.0 (https://julialang.org/downloads/)  
2) Connect to Optimal Reality Julia Registry

#### Connecting to Optimal Reality Julia Registry
This template uses packages from the **Optimal Reality Julia Registry**.

To access this, perform the follings steps.

1) Ensure ssh key is the correct format (OpenSSL PEM)

Your ssh key, typically located at `~/.ssh/~`, needs to begin:
```
-----BEGIN RSA PRIVATE KEY-----
```
If it begins:
```
-----BEGIN OPENSSH PRIVATE KEY-----
```
It is in OpenSSH format and will not work. Generate a new key in the correct format by
```
$ ssh-keygen -m PEM
```

2) If you have generated a new key, add it to your Bitbucket profile

https://confluence.atlassian.com/bitbucketserver/ssh-user-keys-for-personal-use-776639793.html

3) (MacOS only) Add to keychain

Run the following in terminal
```
ssh-add -K ~/.ssh/[your-private-key]
```
and enter passphrase.

There may be a Windows equivalent to this, and this page should be updated accordingly.

4) (MacOS only) Configure SSH to always use the keychain

Create a `~/.ssh/config` file and add
```
Host *
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_rsa
```
This step stops Julia requiring a passphrase each time.

5) Add registry to Julia

Open a Julia session and run the following
```
>julia using Pkg
>julia Pkg.add("LocalRegistry")
>julia pkg"registry add ssh://git@dvcs.deloittedigital.com.au:22/core/or-core-julia-registry.git"
```

## Application Template Overview

Once generated, the new template has the following structure.

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

- `MyApp.jl` is the top level file for the microservice
- `Resource.jl` contains the majority of the HTTP interface. For simple uses, this will not need much editing.
- `Workers.jl` provides a macro that enables requests to be performed on other threads to the main thread,
    leaving the main thread for the handling of requests.
- `App.jl` should contain the application code. Code should be `include`d in additional files, unless the application
    is very short.
- `AppTypes.jl` is a suggested location for any custom `struct`s that are required for the application.
- `Logger.jl` initialises a logger for the module, using the standard Julia `Logging.jl`

The way the module is architected, `Resouce`, `Workers`, `App`, `AppTypes` and `Logger` are all
individual modules which are loaded into `MyApp` by using, for example

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

If running from the REPL, system environment variables will be used and if they are not set, default values will be used.

## Developing the Application

#### Adding Functions

It is suggested that any functions be added to `App`, or scripts `include`d by `App`
to maintain a clear separation between the application code and the microservice
framework.

#### Adding Routes

New routes can be added, and it is suggested that this is done in `Resource`.

To add a new route, define it as follows:

```julia
HTTP.@register(ROUTER, "/routename", myfunction)         # Any request type
HTTP.@register(ROUTER, "PUT", "/routename", myfunction)  # Put request
```

When the route "routename" recieves a request, the HTTP router calls `myfunction`
**with** the request as an argument. With the default handler written here,
`myfunction` must return one of the options specified in
[Default Routes and Handling](#default-routes-and-handling).

### Running the Application

The application can be run in the REPL by:

```julia
julia> using MyApp
julia> MyApp.run()
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

Note the correct `ENTRYPOINT` must be set in `Dockerfile`.

2) `make build-test`

Builds a docker image without the Julia system image. This is much faster and useful for testing,
but will result in a slower microservice.

Note the correct `ENTRYPOINT` must be set in `Dockerfile`.

3) `make build-app`

Rather than building a docker image, this builds a Julia App inside a docker container. This app
can be then be run in another docker container. **this process had not been fully realised in
this template yet**.

### Example Application Functions

Example applications can be found in `bin/examples.jl`

## Building Application and Library Documentation

Julia allows for quick automatic creation of documentation. This template is configured to
produce documentation by running `docs/make.jl`. The generated Markdown documentation can
then be found at `docs/build/index.md`.

For further information see https://juliadocs.github.io/Documenter.jl/stable/.

## Future Improvements to Template

- Add example unit tests
