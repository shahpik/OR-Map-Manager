from gql.client import Client
from gql.gql import gql
from gql.transport.requests import RequestsHTTPTransport
from gql.transport.websockets import WebsocketsTransport


class GQLClient:
    """
    Client class for the GQL connection. This stores the connection and header information for connecting to the \
    GraphQL Experiment manager, or any other GraphQL instance.

    Parameters
    ----------
    `endpoint` - The HTTP(S) endpoint of hte GraphQL Experiment Manager or Service.

    `ws_endpoint=None` - The websocket endpoint of hte GraphQL Experiment Manager or Service. This will default \
    to the websocket version of the `endpoint`.

    `headers=None` - Connection headers required for the GraphQL endpoints. This will default to an empty dictionary \
    if none are provided.

    """

    def __init__(self, endpoint, ws_endpoint=None, headers=None):
        self.endpoint = endpoint
        if ws_endpoint:
            self.ws_endpoint = ws_endpoint
        else:
            self.ws_endpoint = endpoint.replace("^http", "ws")

        if headers:
            self.headers = headers
        else:
            self.headers = {}
        self.subscription_tracker = {}
