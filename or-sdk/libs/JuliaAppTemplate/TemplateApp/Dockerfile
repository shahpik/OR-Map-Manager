# syntax=docker/dockerfile:experimental
FROM julia:1.6.2-alpine3.14

ARG OPTION=NONE

# Try to boost precompilation speed
ENV JULIA_NUM_THREADS=4

# May also consider: postgresql-client zip
RUN apk add --update --no-cache gcc openssh netcat-openbsd unzip curl gnu-libiconv musl-dev

WORKDIR /app

COPY . .

# Add or-core-julia-registry
RUN mkdir -m 600 ~/.ssh && ssh-keyscan dvcs.deloittedigital.com.au >> ~/.ssh/known_hosts
RUN --mount=type=ssh julia -e 'using Pkg; Pkg.Registry.add("General"); Pkg.Registry.add(RegistrySpec(url="ssh://git@dvcs.deloittedigital.com.au:22/core/or-core-julia-registry.git"))'

ENV JULIA_PROJECT @.
RUN --mount=type=ssh julia deploy/packagecompile.jl "$OPTION"
RUN --mount=type=ssh julia -e 'using Pkg; Pkg.instantiate()'

EXPOSE 5082

ENTRYPOINT ["julia", "-JJuliaAppTemplate.so", "-e", "JuliaAppTemplate.run()"]
