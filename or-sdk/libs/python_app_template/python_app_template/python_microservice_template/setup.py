from setuptools import find_packages, setup
from pathlib import Path
import json

def find_all_files(path, store):
    things = []
    for item in list(Path(path).glob("*")):
        if item.is_dir():
            find_all_files(item, store)
            continue
        things.append(str(item))
    store.append((str(path), things))

PACKAGE_NAME = 'python_microservice_template'
VERSION_FILE = 'pkg_info.json'
REQUIREMENTS_LIST = ['requirements.txt', 'requirements-libs.txt']
version = json.load(open(VERSION_FILE))
requirements = []
for reqs in REQUIREMENTS_LIST:
    requirements += open(reqs).readlines()

# If library requires data, uncomment and iterate through all folders
# data_required = []
# find_all_files(Path(f"./{PACKAGE_NAME}"), data_required)

setup(
    name=PACKAGE_NAME,
    version=version['version'],
    packages=find_packages(exclude=('tests', 'tests.*')),
    description='python_microservice_template library for Python',
    long_description=open('README.md').read(),
    python_requires='>=3.5',
    author_email='all@optimalreality.com.au',
    url='https://optimalreality.com.au',
    include_package_data=True,
    # data_files=data_required,  # If library requires data, uncomment
    zip_safe=False,
    install_requires=requirements,
)