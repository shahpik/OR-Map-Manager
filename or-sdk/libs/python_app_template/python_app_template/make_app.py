import argparse
from pathlib import Path

from python_app_template.app_generator import generate_app
import python_app_template.readme_generator as rm

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Builds a new Python Microservice using the OR SDK for Python Microservices.\
            This service will be placed in the current working directory."
    )
    parser.add_argument(
        "-n", "--name",
        metavar="NAME",
        required=True,
        help="The name of the new python microservice in snake_case.",
        dest="service_name"
    )
    parser.add_argument(
        "-p", "--port",
        metavar="PORT",
        type=int,
        required=True,
        help="The target port of the new python microservice as an integer.",
        dest="service_port"
    )
    args = parser.parse_args()
    generate_app(args.service_name, args.service_port, location=Path.cwd(), force=True)

    app_dir = Path(Path.cwd(), args.service_name)
    rm.generate_title(args.service_name, app_dir)
    rm.generate_microservice_readme_body(args.service_name, app_dir)
    rm.generate_version_used(app_dir)
