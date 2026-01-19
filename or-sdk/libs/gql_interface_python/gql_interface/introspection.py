from gql_interface.execution import execute
from gql_interface.schema_utils import process_schema


def full_introspection(client):
    """
    Fully introspects the GraphQL schema of the provided client and updates the client to include:
    - `input_object_fields_to_type_map`
    - `query_to_type_map`
    - `query_to_args_map`
    - `type_to_fields_map`

    Inputs
    ------
    `client`

    Returns
    -------
    `schema:Dict` - The complete GraphQL schema for the client GraphQL Experiment Manager or Service.

    """
    query_str = """
    query IntrospectionQuery {
        __schema {
            queryType {
                name
            }
            mutationType {
                name
            }
            subscriptionType {
                name
            }
            types {
                ...FullType
            }
            directives {
                name
                description
                locations
                args {
                    ...InputValue
                }
            }
        }
    }

    fragment FullType on __Type {
        kind
        name
        description
        fields(includeDeprecated: true) {
            name
            description
            args {
                ...InputValue
            }
            type {
                ...TypeRef
            }
            isDeprecated
            deprecationReason
        }
        inputFields {
            ...InputValue
        }
        interfaces {
            ...TypeRef
        }
        enumValues(includeDeprecated: true) {
            name
            description
            isDeprecated
            deprecationReason
        }
        possibleTypes {
            ...TypeRef
        }
    }
    fragment InputValue on __InputValue {
        name
        description
        type {
            ...TypeRef
        }
        defaultValue
    }
    fragment TypeRef on __Type {
        kind
        name
        ofType {
            kind
            name
            ofType {
                kind
                name
                ofType {
                    kind
                    name
                    ofType {
                        kind
                        name
                        ofType {
                            kind
                            name
                            ofType {
                                kind
                                name
                                ofType {
                                    kind
                                    name
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    """

    body = execute(client, query_str)
    schema = body["__schema"]
    input_object_fields_to_type_map, query_to_type_map, query_to_args_map, type_to_fields_map = process_schema(
        schema)
    client.input_object_fields_to_type_map = input_object_fields_to_type_map
    client.query_to_type_map = query_to_type_map
    client.query_to_args_map = query_to_args_map
    client.type_to_fields_map = type_to_fields_map
    return schema
