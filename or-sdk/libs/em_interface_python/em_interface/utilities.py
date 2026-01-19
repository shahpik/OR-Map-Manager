import logging

from em_interface.connect import get_client
from em_interface.exceptions import ExperimentManagerException

logger = logging.getLogger(__name__)

def merge_exp_name(search_args, experiment_name):
    """
    Adds experiment_name to the search arguments.

    Args
    ----
    `search_args: Dict{String, Any}`

    `experiment_name: String`

    Returns
    -------
    `search_args: Dict{String, Any}`

    """
    search_args["experimentName"] = experiment_name
    return search_args


def check_valid_search(search_args, query):
    """
    Checks that the provided search arguments are available for the provided query.

    Args
    ----
    `search_args: Dict{String, Any}`

    `query: String`

    Returns
    -------
    None.

    """
    client = get_client()
    if client.introspection_complete:
        allowed_keys = client.query_to_args_map[query].keys()
    else:
        logger.debug("GQL schema not available, using hardcoded lists of allowed search fields.")
        if query == "getSimulation":
            allowed_keys = ("experimentName", "primaryKey", "simName", "objectId", "p", "timestamp")
        elif query == "getSimulationAgent":
            allowed_keys = ("experimentName", "primaryKey", "simName", "objectId")
        elif query == "getConfigurations":
            allowed_keys = ("experimentName", "studyName", "experimentBase", "configParent", "createdBy")
        else:
            raise ExperimentManagerException(f"No available search fields for query {query}.\n If not expected, try running full_introspection() to get schema ")

    for key in search_args.keys():
        if key not in allowed_keys:
            raise ExperimentManagerException(f"Cannot search {query} on field {key}")


def build_query_args(search_args:dict):
    """
    Add `search_args` dictionary to a new dictionary, as the value for the key `search`.

    The majority of the Experiment Manager queries have this search argument, so this utility function avoids repeated\
        code.

    Args
    ----
    `search_args:dict`

    Returns
    -------
    `Bool` or `Dict`

    """
    query_args = search_args if bool(search_args) else {"search": search_args}
    return query_args