from setuptools import find_packages, setup
import json

PACKAGE_NAME = 'em_interface'
VERSION_FILE = 'pkg_info.json'
version = json.load(open(VERSION_FILE))
requirements = open('requirements.txt').readlines()

setup(
    name=PACKAGE_NAME,
    version=version['version'],
    packages=find_packages(exclude=('tests', 'tests.*')),
    description='Experiment Manager Interface for Python',
    long_description=open('README.md').read(),
    python_requires='>=3.5',
    author_email='all@optimalreality.com.au',
    url='https://optimalreality.com.au',
    include_package_data=True,
    zip_safe=False,
    install_requires=requirements,
)