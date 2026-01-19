# Python App Template
This is the OR-SDK Python microservice app and library generator. It is a standardised generator of both the library and microservice deployments in `Python >=3.5`.

## Template Sources
To generate a new microservice, you will need to have access to the Optimal Reality Azure Artefact store (for deployed artefact version) or the Optimal Reality Repo. Both of these options will allow you to generate a new microservice or library.

### Azure Artefact Library Package
The Azure Artefacts require the following **PREREQUISITES**:
- Azure CLI (https://pypi.org/project/azure-cli/)
- Azure DevOps extension `az extension add --name azure-devops`

The Azure Artefacts require you to have a Personal Access Token. You will have to create an Azure DevOps Personal Access Token with the permission of Packaging (read). Set the environment variable AZURE_DEVOPS_EXT_PAT to this token. It is recommended to add this to the local Bash profile. You may use commands similar to the below, which will **make the environment variable available to all new sessions**.

```
echo<<EOF >> ~/.bash_profile

# Azure DevOps Personal Access Token
export AZURE_DEVOPS_EXT_PAT=<personal-access-token>
EOF
```

Finally, you will need to extend your pip configuration with the following (or similar) command:

```
pip3 config set global.extra-index-url https://<personal-access-token>:@pkgs.dev.azure.com/dd-managed-services/721248f2-8f57-4990-95af-c4392f87a903/_packaging/or-core-model/pypi/simple/
```

### Repo version
```
CLONE OR_SDK REPO INFO HERE
```

## Library information
### Library structure
The library for the **python_app_template** is functionally rather light, but it does contain an entire folder structure for the microservice / library that will be generated. The library is made up of two files of functions and two scripts for the makefile.
1) `app_generator.py` contains all the microservice and library generation functions.
2) `readme_generator.py` contains all the readme generation functions to generate a README template.
3) `make_app.py` which is the target of the `Makefile` for the `make new-app NAME=my_app PORT=5000` command
4) `make_lib.py` which is the target of the `Makefile` for the `make new-lib NAME=my_lib` command

### Library functionality
The library will take the template folder structure in `python_microservice_template`, remove files that are not required for the microservice or library, and update any files that are required to have the new microservice or library name, and port if required. This will be put into a new file structure wherever you target.

## Generate a new microservice or library
### Setup
#### Artefact library version
With a version of the library installed through pip;
1) Create a new python virtual environment with `python3 -m env template_test`
2) Within python you will need to import the generate app and generate lib functions: `from python_app_template.app_generator import (generate_app, generate_lib)`

#### Repo version
With a version of the library from the OR-SDK repo;
1) In your terminal, navigate to the ./python_app_template folder in the or-sdk repo
2) Create a new python virtual environment with `python3 -m env template_test`
3) Run `make clean`, `make local-setup`, and then `make local-install` to install the python app template
4) Open the python environment with `python3`
5) Within python you will need to import the generate app and generate lib functions: `from python_app_template.app_generator import (generate_app, generate_lib)`

There is also the option of both `make new-app NAME=app_name_in_snake_case PORT=9999` and `make new-lib NAME=app_name_in_snake_case` which will also generate READMEs.

### Generating a new web app:
In python as set up above, run `generate_app("app_name_in_snake_case", 9999, location="../new_app")`
You can then go into the folder location in terminal and run `make build` and `docker-compose up` to bring up the docker web app.
Look through the files and all the names and ports should be updated.

From here, you will need to run the README generation of choice from the `python_app_template.readme_generator` functions.

### Generating a new library
In python as set up above, run `generate_lib("lib_name_in_snake_case", location="../new_lib")`
You can then go into the folder location and look through the files and all the names should be updated.

From here, you will need to run the README generation of choice from the `python_app_template.readme_generator` functions.

## README Examples for Python App Template
### Python App Template Overview
#### Microservice Requirements
This microservice follows a standardised structure for microservice deployment, and is based on an
asynchronous web-app structure that is used throughout the Optimal Reality ecosystem.

It contains the following items:
- `Python App Template` folder containing the application code.
- `tests` folder to contain any unit and system tests that the microservice may require.
- `requirements*.txt` files to control required files. The standard `requirements.txt` should be used for any non-or packages that are used by the microservice, `requirements-libs.txt` is for OR specific libraries available through the extended pip interface, and others are required for deployements, artefacts, etc.
- `pkg_version.json` for tracking the current semantic version of the microservice.
- `Makefile`, `Dockerfile`, `docker-compose.yaml`, and `azure-pipelines.yaml` examples.

#### Microservice Structure
The following files make up the body of the Python App Template codebase:
- `python_app_template`
    - **TBC**
- **TBC**
- `utilities`
    - `decotrators`
    - `log_utils`
    - logging.yaml

### More Information
For more information, please see [Python App Template][core_documentation_link].

[core_documentation_link]: 
### Python App Template Overview
#### Library Requirements
This library follows a standardised structure for library deployment, and is based on an
a simple library structure that is used throughout the Optimal Reality ecosystem.

It contains the following items:
- `Python App Template` folder containing the application code.
- `tests` folder to contain any unit and system tests that the microservice may require.
- `requirements*.txt` files to control required files. The standard `requirements.txt` should be used for any non-or packages that are used by the microservice, `requirements-libs.txt` is for OR specific libraries available through the extended pip interface, and others are required for deployements, artefacts, etc.
- `pkg_version.json` for tracking the current semantic version of the microservice.
- `setup.py` which will be used to build the library as a package that can be used in python.

- `Makefile`, and `azure-pipelines.yaml` examples.
### Library Structure
The following files make up the body of the Python App Template codebase:
- `python_app_template`
    - **TBC**
- **TBC**
- `utilities`
    - `decotrators`
    - `log_utils`
    - logging.yaml

### How to install
To install this package, please see [OR Python Libraries][core_connect_to_python_libraries] for the connection details and process.

[core_connect_to_python_libraries]: https://hub.deloittedigital.com.au/wiki/display/CORE/OR+Python+Libraries
### More Information
For more information, please see [Python App Template][core_documentation_link].

[core_documentation_link]: 

### Template Version Used
This README and the base level folder structure were generated by the OR-SDK for Python: `v0.1.5`