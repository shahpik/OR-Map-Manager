from gql_interface.exceptions import GraphQLError
from gql_interface.string_utils import get_output_str
from gql_interface.queries import generic_gql_query


def mutate(client, mutation_name, args, output_fields=None, **kwargs):
    """
    Generic mutation interface that checks that the mutation name exists within the client schema\
    and wraps the generic format of GraphQL query which is formatted and called on the client.

    Input
    -----
    `client`
    
    `mutation_name` - Name of the mutation that is being called.
    
    `args` - Mutation args for the generic_gql_query that is called and returned.
    
    `output_fields=None` - Output fields to be returned from the GaphQL mutation. By default this \
    will return no output fields.
    
    `**kwargs` - Other kwargs for the generic_gql_query that is called and returned.

    Returns
    -------
    `query_response:Dict`

    """
    if output_fields is None:
        output_fields = []

    if mutation_name not in client.query_to_type_map:
        raise GraphQLError(f"{mutation_name} is not an existing mutation")
    output_str = get_output_str(output_fields)

    return generic_gql_query(client, "mutation", mutation_name, args,
                             output_str, **kwargs)
