from setuptools import find_packages, setup
from pathlib import Path
import json

ignore = ["__pycache__", "python_app_template.egg-info"]

def find_all_files(path, store):
    things = []
    for item in list(Path(path).glob("*")):
        if item.name in ignore:
            continue
        if item.is_dir():
            find_all_files(item, store)
            continue
        things.append(str(item))
    store.append((str(path), things))

PACKAGE_NAME = 'python_app_template'
VERSION_FILE = 'pkg_info.json'
REQUIREMENTS_LIST = ['requirements.txt']
version = json.load(open(VERSION_FILE))
requirements = []
for reqs in REQUIREMENTS_LIST:
    requirements += open(reqs).readlines()
data_required = []
find_all_files(Path("./python_app_template/python_microservice_template"), data_required)


setup(
    name=PACKAGE_NAME,
    version=version['version'],
    packages=find_packages(exclude=('tests', 'tests.*')),
    description='Python App Template for Python',
    long_description=open('README.md').read(),
    python_requires='>=3.5',
    author_email='all@optimalreality.com.au',
    url='https://optimalreality.com.au',
    data_files=data_required,
    include_package_data=True,
    zip_safe=False,
    install_requires=requirements,
)