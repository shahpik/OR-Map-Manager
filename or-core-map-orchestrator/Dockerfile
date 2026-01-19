# syntax=docker/dockerfile:experimental
ARG UPSTREAM_IMAGE=558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-cmp-base-alpine-julia:1.6-alpine-latest

# FROM julia:1.6
FROM $UPSTREAM_IMAGE

ARG OPTION=NONE

# Try to boost precompilation speed
ENV JULIA_NUM_THREADS=4

WORKDIR /app
COPY . .
RUN rm Manifest.toml -f

RUN apk add --update --no-cache gcc openssh netcat-openbsd unzip curl gnu-libiconv musl-dev
RUN apk add --update --upgrade --no-cache gcc openssh gnu-libiconv musl-dev postgresql-client aws-cli krb5-libs proj-util

RUN adduser -u 10000 -S runtime --home /runtime
ENV JULIA_DEPOT_PATH=/runtime/.julia

# Update Bitbucket SSH reference to Azure DevOps HTTPS using system accesstoken for authentication
ARG SYSTEM_ACCESSTOKEN=""
ENV JULIA_PKG_USE_CLI_GIT=TRUE
RUN apk add -y --no-cache git
RUN git config --global url."https://$SYSTEM_ACCESSTOKEN@dev.azure.com/dd-managed-services/Optimal-Reality/_git/".insteadOf "git@ssh.dev.azure.com:v3/dd-managed-services/Optimal-Reality/"

# Add or-julia-registry
RUN julia -e 'using Pkg; Pkg.Registry.add("General"); Pkg.Registry.add(RegistrySpec(path="or-julia-registry"))'

ENV JULIA_PROJECT @.
RUN julia deploy/packagecompile.jl "$OPTION"
RUN julia -e 'using Pkg; Pkg.instantiate()'

# change ownership and clear out test keys (using root user)
RUN chown -R runtime /runtime/.julia/ && \
  find /usr/local/julia/* -type f -regex '.*\/test\/keys\/.*' -delete && \
  find /runtime/.julia/packages/* -type f -regex '.*\/test\/.*.pem' -delete && \
  find /runtime/.julia/* -type f -regex '.*\/test\/.*.key' -delete && \
  find /runtime/.julia/* -type f -regex '.*\/test\/keys\/.*' -delete && \
  find /runtime/.julia/* -type f -regex '.*\/Jedis\/*.*\/redis.key' -delete

RUN apk del gcc git

USER runtime

EXPOSE 6704

ENTRYPOINT ["julia", "-JMapOrchestrator.so", "-e", "MapOrchestrator.run()"]

