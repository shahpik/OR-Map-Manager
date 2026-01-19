# Experiment Manager Interface for Python
## Introduction
The Experiment Manager Interface for Python allows for easy, reproducible, and consistent connection 
to the GraphQL Experiment Manager that sits at the center of the Optimal Reality platform's client 
ecosystems. It manages the orchestration and connection of microservices with each other and with 
the datastores that support each system.

This Software Development Kit item allows for python microservices and python libraries to quickly 
and easily connect to the GQL Experiment Manager and ensure that the queries, arguments, and outputs
are available.

## Overview
### Library Requirements
This library follows a standardised structure for library deployment, and is based on an
a simple library structure that is used throughout the Optimal Reality ecosystem.

It contains the following items:
- `em_interface` folder containing the application code.
- `requirements*.txt` files to control required files.
- `pkg_version.json` for tracking the current semantic version of the microservice.
- `setup.py` which will be used to build the library as a package that can be used in python.
- `Makefile`, and `azure-pipelines.yaml` examples.

### Library Structure
The following files make up the body of the em_interface library:
- `application`
- `configuration`
- `connect`
- `exceptions`
- `generic_gql`
- `sample_calls`
- `sim_results`
- `utilities`

## How to install
To install this package, please see [OR Python Libraries][core_connect_to_python_libraries] for the connection details and process.

## More Information
For more information, please see [Experiment Manager Interface - Python][core_python_em_documentation_link].


[core_python_em_documentation_link]: https://hub.deloittedigital.com.au/wiki/display/CORE/Experiment+Manager+Interface+-+Python
[core_connect_to_python_libraries]: https://hub.deloittedigital.com.au/wiki/display/CORE/OR+Python+Libraries