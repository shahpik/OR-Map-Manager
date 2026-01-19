from gql_interface.gql_client import GQLClient
from gql_interface.introspection import full_introspection
from em_interface.exceptions import ExperimentManagerException
import logging

logger = logging.getLogger(__name__)

CLIENT = None


def connect(endpoint, ws_endpoint, token:str="") -> None:
    """
    Establish a connection to a module-wide and consistent singleton Graphql Client, at the provided endpoints and\
        with the provided bearer token.

    Args
    ---------
        `endpoint`: The open http(s) endpoint of the Graphiql Server that the connection should be attached to.

        `ws_endpoint`: The open websocked endpoint of the Graphiql Server that the connection should be attached to.

    Kwargs
    ------
        `token:str=""`: The authorisation bearer token to access the Graphiql Server


    Sets
    ----
        `global CLIENT`: Sets the global `CLIENT` to a GQLClient with the provided endpoints and using the provided token.

    Returns
    -------
        None.

    Example
    -------
    >>> connect("http://0.0.0.0:8080", "ws://0.0.0.0:8080")

    """
    global CLIENT
    client = GQLClient(endpoint, ws_endpoint, headers=get_headers(token))
    logger.debug(f"Performing full introspection on {client.endpoint}")
    full_introspection(client)
    if CLIENT:
        logger.warn(
            f"Dropping connection to {CLIENT.endpoint} and connecting to {client.endpoint}")
    CLIENT = client


def get_headers(token:str):
    """Returns a Bearer Authorisation header dictionary with the provided token."""
    if token:
        headers = {"Authorization": f"Bearer {token}"}
    else:
        headers = {}
    return headers


def get_client():
    """Returns the `CLIENT` singleton if it exists, or raises an ExperimentManagerException if not."""
    if not CLIENT:
        raise ExperimentManagerException(
            "Not connected to the Experiment Manager")
    return CLIENT
