# GraphQL Interface for Python
## Introduction

## Overview
### Library Requirements

This library follows a standardised structure for library deployment, and is based on an
a simple library structure that is used throughout the Optimal Reality ecosystem.

It contains the following items:
- `python_app_template` folder containing the application code.
- `requirements*.txt` files to control required files.
- `pkg_version.json` for tracking the current semantic version of the microservice.
- `setup.py` which will be used to build the library as a package that can be used in python.
- `Makefile`, and `azure-pipelines.yaml` examples.

### Library Structure
The following files make up the body of the gql_interface library:
- `exceptions`
- `execution`
- `gql_client`
- `introspection`
- `mutations`
- `queries`
- `sample_calls`
- `schema_utils`
- `string_utils`
- `subscriptions`
- `utilities`

## How to install
To install this package, please see [OR Python Libraries][core_connect_to_python_libraries] for the connection details and process.

## More Information
For more information, please see [GraphQL Interface - Python][core_python_gql_documentation_link].


[core_python_gql_documentation_link]: https://hub.deloittedigital.com.au/wiki/display/CORE/GraphQL+Interface+-+Python
[core_connect_to_python_libraries]: https://hub.deloittedigital.com.au/wiki/display/CORE/OR+Python+Libraries