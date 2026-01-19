"""
Generates a new placeholder app from the OR-SDK python microservice app template.
"""
import logging
import shutil
import re
from pathlib import Path

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

FILES_WITH_PORTS = [
    r".*docker-compose.yaml",
    r".*Dockerfile",
    r".*(\.yaml)",
    r".*service.py"
]


def generate_app(
        name:str,
        port:int,
        location:Path=Path.cwd(),
        force:bool=False
    ) -> None:
    """
    Generates a new python microservice based on the OR-CORE Python Application Template.

    Parameters
    ----------
        `name:str` - The name of the microservice, in `snake_case`.
        `port:int` - The port that the service will use for web connections.
        `location:Path or str=Path.cwd()` - Folder path that the new app will be \
            created. Default is current working directory.
        `force:bool=False` - Force replace the app directory if it already exists. Default is \
            `False` and will raise an error if the directory exists.

    Returns
    -------
    `None`

    """
    new_app_dir = Path(location, name)
    if force and new_app_dir.is_dir():
        logger.info(f"Removing {new_app_dir}")
        shutil.rmtree(new_app_dir)
    logger.info(f"Creating the {name} app in: {new_app_dir}")
    template_dir = Path(Path(__file__).parent, "python_microservice_template")
    shutil.copytree(template_dir, new_app_dir, dirs_exist_ok=force)
    Path(new_app_dir, "python_microservice_template").rename(Path(new_app_dir, name))
    logger.info("Removing library files.")
    for lib_file in [
        "setup.py",
        f"{name}/service/lib.py",
        "requirements-library.txt",
        "Makefile-library",
        "azure-pipelines-library.yaml"
    ]:
        Path(new_app_dir, lib_file).unlink(missing_ok=True)
    logger.info("Renaming microservice files.")
    rename_me = {
        "requirements-microservice.txt": "requirements.txt",
        "Makefile-microservice": "Makefile",
        "azure-pipelines-microservice.yaml": "azure-pipelines.yaml"
    }
    for key in rename_me:
        Path(new_app_dir, key).rename(Path(new_app_dir, rename_me[key]))
    new_app_dir.chmod(0o755)
    recursive_template_renaming(new_app_dir, name=name, port=port)
    display_success_message(name, port, new_app_dir)


def generate_lib(
        name:str,
        location:Path=Path.cwd(),
        force:bool=False
    ) -> None:
    """
    Generates a new python library based on the OR-CORE Python Application Template.

    Parameters
    ----------
        `name:str` - The name of the microservice, in `snake_case`.
        `location:Path or str=Path.cwd()` - Folder path that the new app will be \
            created. Default is current working directory.
        `force:bool=False` - Force replace the app directory if it already exists. Default is \
            `False` and will raise an error if the directory exists.

    Returns
    -------
    `None`

    """
    new_app_dir = Path(location, name)
    if force and new_app_dir.is_dir():
        logger.info(f"Removing {new_app_dir}")
        shutil.rmtree(new_app_dir)
    logger.info(f"Creating the {name} library in: {new_app_dir}")
    template_dir = Path(Path(__file__).parent, "python_microservice_template")
    shutil.copytree(template_dir, new_app_dir)
    Path(new_app_dir, "python_microservice_template").rename(Path(new_app_dir, name))
    logger.info("Removing microservice files.")
    for service_file in [
        "Dockerfile",
        "docer-compose.yaml",
        "Dockerfile.dockerignore",
        "DockerBuildTest",
        "DockerBuildTest.dockerignore",
        "docker-entrypoint.sh",
        f"{name}/service/service.py",
        "requirements-microservice.txt",
        "Makefile-microservice",
        "azure-pipelines-microservice.yaml"
    ]:
        Path(new_app_dir, service_file).unlink(missing_ok=True)
    shutil.rmtree(Path(new_app_dir, "chart"))
    logger.info("Renaming library files.")
    rename_me = {
        "requirements-library.txt": "requirements.txt",
        "Makefile-library": "Makefile",
        "azure-pipelines-library.yaml": "azure-pipelines.yaml"
    }
    for key in rename_me:
        Path(new_app_dir, key).rename(Path(new_app_dir, rename_me[key]))
    new_app_dir.chmod(0o755)
    recursive_template_renaming(new_app_dir, name=name, has_port=False)
    display_success_message(name, None, new_app_dir)


def recursive_template_renaming(
        dir:Path,
        name:str="python_microservice_template",
        port:int=5082,
        has_port:bool=True
    ) -> None:
    """
    Recursively renames the microservice in all files and subfolders of the provided directory.

    Parameters
    ----------
        `dir:Path or str` - The directory path that will be recursively walked through to rename \
            text items.
        `name:str="python_app_template"` - The name of the new app in `snake_case`, which will be \
            put into all the text files of the app.
        `port:int=5082` - The port that the service will use for web connections, which will be \
            put into all the text files of the app.
        `has_port:bool=True` - Defines if this needs a port input. Default is true, sop ports will \
            be replaced. False will not replace ports and will require manual cleanup.

    Returns
    -------
    `None`
    """

    DEFAULT_NAME = "python_microservice_template"
    DEFAULT_PORT = 5082

    for child in Path(dir).iterdir():
        child.chmod(0o755)
        if child.is_dir():
            recursive_template_renaming(child, name=name, port=port, has_port=has_port)
            continue
        if not child.is_file():
            logger.warning(f"{child} is not a directory or a file.")
            continue
        if child.name.find(".cpython") > -1:
            logger.warning(f"{child} has been compiled to cpython.")
            continue
        with child.open(mode='r+') as file:
            logger.debug(f"{child} will be updated for {name}.")
            text = file.read()
            text = text.replace(DEFAULT_NAME, name)
            text = text.replace(get_kebab_case(DEFAULT_NAME), get_kebab_case(name))
            text = text.replace(get_screaming_snake_case(DEFAULT_NAME), get_screaming_snake_case(name))
            if has_port and check_all_regex_list(FILES_WITH_PORTS, str(child)):
                text = text.replace(str(DEFAULT_PORT), str(port))
            file.seek(0)
            file.write(text)
            file.truncate()
    

def check_all_regex_list(pattern_list:list, string:str) -> bool:
    """
    Checks the string to see if it contains any of the regex patterns in the provided list of patterns.
    """
    match = [False] * len(pattern_list)
    for i, pattern in enumerate(pattern_list):
        match[i] = (re.match(pattern, string) is not None)
    return any(match)


def get_kebab_case(name:str):
    """
    Converts `snake_case` to `kebab-case`.
    """
    return name.replace("_", "-")


def get_screaming_snake_case(name:str):
    """
    Converts `snake_case` to `SCREAMING_SNAKE_CASE`.
    """
    return name.upper()


def display_success_message(name, port, path):
    port_line = "This is a library and will need to be built into an artefact."
    if port is not None:
        port_line = f"It will use port {port} when it's deployed, so make sure that's known."
    print(f"""
   _____                            _         _       _   _
  / ____|                          | |       | |     | | (_)
 | |     ___  _ __   __ _ _ __ __ _| |_ _   _| | __ _| |_ _  ___  _ __  ___ 
 | |    / _ \| '_ \ / _` | '__/ _` | __| | | | |/ _` | __| |/ _ \| '_ \/ __|
 | |___| (_) | | | | (_| | | | (_| | |_| |_| | | (_| | |_| | (_) | | | \__ \\
  \_____\___/|_| |_|\__, |_|  \__,_|\__|\__,_|_|\__,_|\__|_|\___/|_| |_|___/
                     __/ |
                    |___/

You've just set up your new app: \"{name}\"!

{port_line}

It's now located in {path} for you to continue to expand.

NOTE: You will need to update the \"requirements.txt\" file with any python libraries you require.
We recommend using a new virtual environment and installing as you go, so that only required libraries
appear in `pip freeze`.

Good luck and happy coding.
    """)
