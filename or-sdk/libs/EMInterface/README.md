# Experiment Manager Interface

This package provides an interface to the Optimal Reality Experiment Manager.

## Summary

The following functions/macros are exported:

|Function|Description|
|---|---|
| `connect` | Connect to Experiment Manager GraphQL server and perform full introspection of schema |
| `get_configuration`| Get configuration(s)|
| `save_configuration`| Save a configuration |
| `execute_configuration`| Execute a configuration|
| `update_app_data`| Update application data|
| `get_app_data`| Get application data |
| `query`| Re-exported from `GraphQLClient`, generic GraphQL query|
| `mutate`| Re-exported from `GraphQLClient`, generic GraphQL mutation|
| `open_subcription`| Re-exported from `GraphQLClient`, generic GraphQL subscription|

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

## Documentation

Documentation can be built by running `docs/make.jl`. The generated Markdown documentation can
then be found at `docs/build/index.md`.

## Future work

In no particular order:

- App registering
- App results suscription
- App results posting
- Chained queries/mutations
- Simulation results posting
- User functions
- get_sources - things that you use to construct the network