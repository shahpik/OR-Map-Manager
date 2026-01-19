# DEPRECATION NOTICE

This version is no longer maintained as it got open sourced to github:
https://github.com/DeloitteOptimalReality/PromClient.jl

You can pull that version directly using the Julia Package Manager (i.e. `pkg`)

See GITHUB version for quickstart/readme, and is a prom specification compliant client.


# PrometheusClient (OLD AND NO LONGER MAINTAINED - use github version)
Lightweight implementation of prometheus logging/metric collection tools in Julia for Julia microservices.


This version only supports:
- Gauge
- Counter

And is not a full spec compliant client. Migration from this version should be done on any services still using this verison.

As of v0.1 of the Github `PromClient` version, it has the same interface as this and should be an in-place upgrade when switching out the package.


## Template Version Used

This application generated with or-sdk JuliaAppTemplate v0.2.37