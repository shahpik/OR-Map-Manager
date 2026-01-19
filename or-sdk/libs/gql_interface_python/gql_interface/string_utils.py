from gql_interface.schema_utils import isobject, isnonnull, islist, getsubfield, isscalar
from gql_interface.exceptions import GraphQLError
import re


def get_output_str(outputs):
    """
    Recursively restructure the output requirements from strings, lists, and dictionaries into a \
    GraphQL-appropriate string format for use in the generic GraphQL payload.

    """
    if isinstance(outputs, list):
        output_str = ""
        for output in outputs:
            output_str += get_output_str(output)
        return output_str
    elif isinstance(outputs, str):
        return outputs + "\n"
    elif isinstance(outputs, dict):
        output_str = ""
        for (key, val) in outputs.items():
            output_str = f"{key} {{\n"
            output_str += get_output_str(val)
            output_str += "}\n"
        return output_str


def _get_field_str(field, type_to_fields_map):
    """Gets the field string for the provided field, and field type if required."""
    if not isobject(field) and not isnonnull(field):
        return field["name"]

    if field["name"] in ("pageInfo", "cursor"):
        return ""

    if isnonnull(field):
        if islist(getsubfield(field)):
            subtype = field["type"]["ofType"]["ofType"]["name"]
            fields_str = get_type_field_string(subtype, type_to_fields_map)
        elif isscalar(getsubfield(field)):
            return field["name"]
        else:
            raise GraphQLError(
                "_get_field_str does not handle this case currently.")
    else:
        subtype = field["type"]["name"]
        fields_str = get_type_field_string(subtype, type_to_fields_map)

    return field["name"] + "{" + fields_str + "}"


def get_type_field_string(type, type_to_fields_map):
    """Get the fields for the specified type, and provide field type information if it is required."""
    fields = type_to_fields_map[type]
    fields_str = ""
    for field in fields:
        fields_str += _get_field_str(fields[field], type_to_fields_map)
        fields_str += "\n "
    return fields_str


def get_all_output_fields_str(query_name, type_to_fields_map,
                              query_to_type_map):
    """Get the fields and types required for the output str for the provided query name."""
    type = query_to_type_map[query_name]
    if type in type_to_fields_map:
        return get_type_field_string(type, type_to_fields_map)
    else:
        return ""


def get_query_variables(args, arg_names, name_tracking=None):
    """
    Creates the variable JSON dictionary for the variable part of the query payload.

    Inputs
    ------
    `args` - 

    `arg_names` - 

    `name_tracking=None` - 

    Returns
    -------
    `query_variables_payload` - JSON format of the query variables for the query payload.

    """
    if not name_tracking:
        name_tracking = []
    variables = {}
    for key, val in args.items():
        if isinstance(val, dict):
            variables = {**variables, **get_query_variables(val, arg_names[key],
                                                            name_tracking=name_tracking)}
        elif isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
            for i in range(len(val)):
                variables = {**variables,
                             **get_query_variables(val[i], arg_names[key][i],
                                                   name_tracking=name_tracking)}
        else:
            if arg_names[key] in name_tracking:
                raise GraphQLError(
                    f"Duplicate name {arg_names[key]} found when creating variable dictionary for HTTP query.")
            name_tracking.append(arg_names[key])
            variables[arg_names[key]] = val
    return variables


def initialise_arg_names(args):
    """Initialises a dictionary of argument names, at the key and list level only."""
    if isinstance(args, str):
        return ""
    elif isinstance(args, list):
        return [initialise_arg_names(i) for i in args]
    elif isinstance(args, dict):
        arg_names = {}
        for key, val in args.items():
            arg_names[key] = initialise_arg_names(val)
        return arg_names


def get_query_args_str(args):
    """Recursively collect the query argument names and create the argument string."""
    arg_names = initialise_arg_names(args)
    fieldname_tracker = []

    def recursive_get(arg_values, arg_names, enumerate):
        str = ""
        for (fieldname, val) in arg_values.items():
            if isinstance(val, dict):
                str += f"{fieldname}:{{\n" + recursive_get(val,
                                                           arg_names[fieldname],
                                                           enumerate) + "}\n"
            elif isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
                str += f"{fieldname}:["
                for i in range(len(val)):
                    str += "{\n" + recursive_get(val[i],
                                                 arg_names[fieldname][i],
                                                 i) + "},\n"
                str += "]\n"
            else:
                name = fieldname
                str += f"{fieldname}:${fieldname}"
                if enumerate > 0:
                    name = fieldname + str(enumerate)
                    str += str(enumerate)
                is_field_name_used(name, fieldname_tracker)

                fieldname_tracker.append(name)
                arg_names[fieldname] = name
                str += "\n"
        return str

    query_args_str = "(" + recursive_get(args, arg_names, 0) + ")"
    return query_args_str, arg_names


def is_field_name_used(fieldname, fieldnamelist):
    """Check if the fieldname has already been used and raise an error if it has."""
    if fieldname in fieldnamelist:
        raise (GraphQLError(f"{fieldname} in args is not a unique field name."))


def get_variables_str(args, query, client, arg_names=None, typedict=None):
    """
    Create the variable string for the query payload, which maps the variables in the variable JSON payload to their\
    expected types.

    """
    if arg_names is None:
        vars_str = "(" + "\n".join(
            ["$" + key + ": " + client.query_to_args_map[query][key] for key in
             args])
        return vars_str
    else:
        vars_str = ""
        query = query.replace("!", "")
        query = re.sub('^\[|\]$', '', query)
        for key, val in args.items():
            if isinstance(val, dict):
                vars_str += get_variables_str(val,
                                              typedict[query][key],
                                              client,
                                              arg_names[key],
                                              typedict=client.input_object_fields_to_type_map)
            elif isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
                for a in val:
                    vars_str += get_variables_str(a, typedict[query][key],
                                                  client, arg_names[key][0],
                                                  typedict=client.input_object_fields_to_type_map)
                    vars_str += "\n "
            else:
                vars_str += "$" + arg_names[key] + ": " + typedict[query][key]
            vars_str += "\n"
        return vars_str
