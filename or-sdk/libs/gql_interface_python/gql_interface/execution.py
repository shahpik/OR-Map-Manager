from gql.client import Client
from gql.gql import gql
from gql.transport.requests import RequestsHTTPTransport
from gql_interface.gql_client import GQLClient
from gql_interface.exceptions import GraphQLError


def execute(client, query, variables=None, retries=1, readtimeout=60):
    """
    Executes a query on the provided client and returns the response.

    Inputs
    ------
    `client`

    `query`

    `variables=None` - Query variables, if required

    `retries=1` - Number of retries permitted on the query execution to the client.

    `readtimeout=60` - Timeout on the query exeuction, in seconds.

    Returns
    -------
    `resp:Dict` - Query response in a dictionary from the client.

    """
    headers = {x: client.headers[x] for x in client.headers}
    headers["Content-Type"] = "application/json"
    try:
        transport = RequestsHTTPTransport(
            url=client.endpoint,
            verify=True,
            retries=retries,
            headers=headers,
            timeout=readtimeout
        )
        client = Client(transport=transport,
                        fetch_schema_from_transport=True)

        resp = client.execute(gql(query), variable_values=variables)
        return resp
    except Exception as e:
        raise GraphQLError(e)

















