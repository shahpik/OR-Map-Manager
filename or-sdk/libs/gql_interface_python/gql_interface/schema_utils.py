from gql_interface.exceptions import GraphQLError
from gql_interface.execution import execute


def gettype(field, level="top"):
    """Gets the type of the provided object field, at the provided level."""
    if level == "top":
        typefield = "type"
    else:
        typefield = "ofType"
    if field[typefield]["kind"] in ("SCALAR", "INPUT_OBJECT", "ENUM"):
        type = field[typefield]["name"]
    elif field[typefield]["kind"] == "LIST":
        type = "[" + gettype(field[typefield], level="child") + "]"
    elif field[typefield]["kind"] == "NON_NULL":
        type = gettype(field[typefield], level="child") + "!"
    else:
        raise GraphQLError(
            "gettype function does not handle this case currently")
    return type


def getsubfield(field):
    """Get the subfield of the provided object field."""
    if "type" in field:
        return field["type"]
    elif "ofType" in field:
        return field["ofType"]
    else:
        raise GraphQLError(f"{field} is not a field, rerurn subfield")


def istype(field, comparison):
    """Check if the provided field matches the comparison type."""
    if "type" in field:
        return field["type"]["kind"] == comparison
    elif "ofType" in field:
        if  field["ofType"] and "kind" in field["ofType"]:
            return field["ofType"]["kind"] == comparison
        return False
    raise GraphQLError(f"{field} is not a field, cannot check type.")


def islist(field):
    """Check if the provided field is of type `LIST`."""
    return istype(field, "LIST")


def isscalar(field):
    """Check if the provided field is of type `SCALAR`."""
    return istype(field, "SCALAR")


def is_input_object(field):
    """Check if the provided field is of type `INPUT_OBJECT`."""
    return istype(field, "INPUT_OBJECT")


def is_nonnull_input_object(field):
    """Check if the provided field is not null and is of type `INPUT_OBJECT`."""
    return field and istype(getsubfield(field), "INPUT_OBJECT")


def isobject(field):
    """Check if the provided field is of type `OBJECT`."""
    return istype(field, "OBJECT")


def isnonnull(field):
    """Check if the provided field is of type `NON_NULL`."""
    return istype(field, "NON_NULL")


def process_schema(schema):
    """
    Processes a GraphQL Schema introspection schema and gets the types and arguments that the queries\
    require.

    Inputs
    ------
    `schema` - A GraphQL Service schema introspection.

    Returns
    -------
    `input_object_fields_to_type_map`

    `query_to_type_map`

    `query_to_args_map`

    `type_to_fields_map`

    """
    keys_to_include = ["queryType", "mutationType", "subscriptionType"]
    gql_types = [schema[k]["name"] for k in keys_to_include]

    input_object_fields_to_type_map = {}  # Reset
    for gql_type in schema["types"]:
        if gql_type["kind"] == "INPUT_OBJECT":
            field_to_type_map = {}
            for field in gql_type["inputFields"]:
                field_to_type_map[field["name"]] = gettype(field)
            input_object_fields_to_type_map[
                gql_type["name"]] = field_to_type_map

    query_to_type_map = {}  # Reset
    for gql_type in schema["types"]:
        if gql_type["name"] in gql_types:
            for field in gql_type["fields"]:
                field_type = _recursive_get_value(
                    field["type"],
                    "ofType"
                )["name"]
                query_to_type_map[field["name"]] = field_type

    query_to_args_map = {}  # Reset
    for gql_type in schema["types"]:
        if gql_type["name"] in gql_types:
            for field in gql_type["fields"]:
                for arg in field["args"]:
                    arg_type = _recursive_get_value(
                        arg["type"],
                        "ofType"
                    )["name"]
                    if field["name"] not in query_to_args_map:
                        query_to_args_map[field["name"]] = {}
                    query_to_args_map[field["name"]][arg["name"]] = arg_type
                    # If list (either plain list or non-null list) bracket the type
                    if islist(arg) or (
                            isnonnull(arg) and islist(getsubfield(arg))):
                        query_to_args_map[field["name"]][
                            arg["name"]] = "[" + arg_type + "]"
                    # If non null, add ! to type
                    if isnonnull(arg):
                        query_to_args_map[field["name"]][arg["name"]] += "!"

                    if is_input_object(arg):
                        fields_to_add = input_object_fields_to_type_map[
                            arg["type"]["name"]]
                        for (f, v) in fields_to_add.items():
                            query_to_args_map[field["name"]][f] = v

                    elif is_nonnull_input_object(arg):
                        fields_to_add = input_object_fields_to_type_map[
                            arg["type"]["ofType"]["name"]]
                        for (f, v) in fields_to_add.items():
                            query_to_args_map[field["name"]][f] = v

    type_to_fields_map = {}
    for gql_type in schema["types"]:
        if gql_type["fields"]:
            type_to_fields_map[gql_type["name"]] = {f["name"]: f for f in
                                                    gql_type["fields"]}
        elif gql_type["inputFields"]:
            type_to_fields_map[gql_type["name"]] = {f["name"]: f for f in
                                                    gql_type["inputFields"]}
    return input_object_fields_to_type_map, query_to_type_map, query_to_args_map, type_to_fields_map


def introspect_node(client, node):
    raise NotImplementedError


def _recursive_get_value(dict, key):
    """Recursively go through dictionary until the key isn't in the dictionary at that depth, return the value at that point."""
    if key in dict and dict[key]:
        return _recursive_get_value(dict[key], key)
    else:
        return dict
