from gql_interface.execution import execute
from gql_interface.string_utils import get_query_args_str, get_variables_str, \
    get_query_variables, get_output_str, get_all_output_fields_str
from gql_interface.exceptions import GraphQLError


def generic_gql_query(client, query_type, query_name, query_args, output_str="",
                      **kwargs):
    """
    The most generic format for GraphQL queries. The query payload is generated as a dictionary of the\
    query as a string, and the query argument variables as a string, and passes them through to the\
    generic execute function to request from the client service.

    Inputs
    ------
    `client`

    `query_type` - The type of query (`query`, `mutation`, `subscription`) as a string.

    `query_name` - Name of the query / mutation / subscription that is being called.

    `query_args` - Query args for the query / mutation / subscription that is called and returned.

    `output_str=""` - Output fields to be returned from the GaphQL query in a stringified format.

    `**kwargs` - Other kwargs for the generic_gql_query that is called and returned.

    Returns
    -------
    `query_response:Dict`

    """
    payload = get_generic_query_payload(query_type, query_name, query_args,
                                        output_str, client)

    return execute(client, payload['query'], payload['variables'], **kwargs)[query_name]


def get_generic_query_payload(query_type, query_name, query_args,
                              output_str="", client=None):
    """
    Creates the query and variable payload strings required for the generic GraphQL query. The query\
    and variable strings are formatted for use in GraphQL, and are created using the `string_utils`.\
    The query is returned in the following format:

    >>> {query_type} {vars_str} {{
    >>>     {query_name} {query_args_str}
    >>>         {output_str}
    >>> }}

    Inputs
    ------
    `query_type` - The type of query (`query`, `mutation`, `subscription`) as a string.

    `query_name` - Name of the query / mutation / subscription that is being called.

    `query_args` - Query args for the query / mutation / subscription that is called and returned.

    `output_str=""` - Output fields to be returned from the GaphQL query in a stringified format.

    `client=None`

    Returns
    -------
    payload_dictionary

    """
    query_args_str = ""
    vars_str = ""
    variables = {}
    if query_args:
        query_args_str, arg_names = get_query_args_str(query_args)
        vars_str = "(" + get_variables_str(query_args, query_name, client,
                                           arg_names,
                                           client.query_to_args_map) + ")"
        variables = get_query_variables(query_args, arg_names)

    if output_str:
        output_str = "{" + output_str + "}"

    query = f"""
            {query_type} {vars_str} {{
                {query_name} {query_args_str}
                    {output_str}
            }}
        """
    return {"query": query, "variables": variables}


def query(client, query_name, query_args=None, output_fields="", **kwargs):
    """
    Generic query interface that checks that the query name exists within the client schema\
    and wraps the generic format of GraphQL query which is formatted and called on the client.

    Input
    -----
    `client`
    
    `query_name` - Name of the query that is being called.
    
    `query_args=None` - Query args for the generic_gql_query that is called and returned. By default\
    this will pass no query arguments.
    
    `output_fields=""` - Output fields to be returned from the GaphQL query. By default this will \
    return all the outputs.
    
    `**kwargs` - Other kwargs for the generic_gql_query that is called and returned.

    Returns
    -------
    `query_response:Dict`

    """
    if query_args is None:
        query_args = {}
    if query_name not in client.query_to_type_map:
        raise GraphQLError(f"{query_name} is not an existing mutation")
    if output_fields:
        output_str = get_output_str(output_fields)
    else:
        output_str = get_all_output_fields_str(query_name, client.type_to_fields_map,
                              client.query_to_type_map)
    return generic_gql_query(client, "query", query_name, query_args,
                             output_str, **kwargs)
