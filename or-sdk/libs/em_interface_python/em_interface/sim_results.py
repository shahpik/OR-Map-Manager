import logging

from gql_interface.queries import query

from utilities import merge_exp_name, check_valid_search, build_query_args
from em_interface.connect import get_client

logger = logging.getLogger(__name__)


def get_detailed_simulation_results(experimentName, search_args, **kwargs):
    """Get the detailed-level simulation results for the provided experiment name and search arguments."""
    search_args = merge_exp_name(search_args, experimentName)
    return _get_detailed_simulation_results(search_args=search_args, **kwargs)


def _get_detailed_simulation_results(search_args, output_fields=None):
    check_valid_search(search_args, "getSimulation")
    query_args = build_query_args(search_args)
    result = query(
        get_client(),
        "getSimulation",
        query_args=query_args,
        output_fields=output_fields
    )
    return result

def get_summary_simulation_results(experimentName, search_args, **kwargs):
    """Get the summary-level simulation results for the provided experiment name and search arguments."""
    search_args = merge_exp_name(search_args, experimentName)
    return _get_summary_simulation_results(search_args=search_args, **kwargs)

def _get_summary_simulation_results(search_args, output_fields):
    check_valid_search(search_args, "getSimulationAgent")
    query_args = build_query_args(search_args)
    result = query(
        get_client(),
        "getSimulationAgent",
        query_args=query_args,
        output_fields=output_fields
    )
    return result

def all_sims_finished(result):
    """
    Check if all simulations have been completed, based on the simulation result response.
    """
    n_finished = len(result[0]["data"]["simResultIds"])
    all_sims_finished = result[0]["data"]["nSimulations"] == n_finished
    if all_sims_finished:
        logger.info("All simulations finished, closing subscription.")
    return all_sims_finished

def open_sims_results_subscription(fn, experimentName, execute=False):
    pass
