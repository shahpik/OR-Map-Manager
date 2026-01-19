import logging

from gql_interface.mutations import mutate
from gql_interface.queries import query

from em_interface.utilities import merge_exp_name
from em_interface.connect import get_client

logger = logging.getLogger(__name__)


def build_config_output_fields(
        output_fields,
        agent_fields,
        test_fields
    ):
    """
    Appends the agent and test fields to the output fields in a nested position under the agent,\
        edges, node fields for output and then returns the updated output fields. If either of \
        agent or test fields is empty then nothing will be appended.

    Args
    ----
    `output_fields`

    `agent_fields`

    `test_fields`

    Returns
    -------
    `output_fields`

    """
    if agent_fields:
        output_fields.append({
            "agents": {
                "edges": {
                    "node": agent_fields
                }
            }
        })

    if test_fields:
        output_fields.append({
            "tests": {
                "edges": {
                    "node": test_fields
                }
            }
        })
    return output_fields


def get_configuration(experiment_name, search_args, **kwargs):
    search_args = merge_exp_name(search_args, experiment_name)
    config = _get_configuration(search_args=search_args, **kwargs)
    return config


def _get_configuration(
        client,
        search_args,
        output_fields,
        agent_fields,
        test_fields
    ):
    query_args = None
    if not search_args:
        query_args = search_args
    else:
        query_args = {"search": search_args}

    output_fields = build_config_output_fields(
        output_fields,
        agent_fields,
        test_fields
    )
    config = query(
        get_client(),
        "getConfigurations",
        query_args=query_args,
        output_fields=output_fields
    )
    if not config:
        logger.info("No configuration(s) found")
        return
    return config


def save_configuration(
        experimentBase,
        studyName,
        updateExisting=True,
        setConfigParams=None,
        agentBuilder=None,
        testBuilder=None,
        output_fields=None,
        agent_fields=None,
        test_fields=None
    ):
    args = {
        "studyName": studyName,
        "experimentBase": experimentBase,
        "updateExisting": updateExisting
    }
    if setConfigParams:
        args["setConfigParams"] = setConfigParams
    if agentBuilder:
        args["agentBuilder"] = agentBuilder
    if testBuilder:
        args["testBuilder"] = testBuilder

    output_fields.append("experimentName")
    output_fields = list(set(output_fields))
    output_fields = build_config_output_fields(
        output_fields,
        agent_fields,
        test_fields
    )
    output_fields = ["message", {"configOut":output_fields}]

    result = mutate(
        get_client(),
        "saveConfig",
        args,
        output_fields=output_fields
    )

    exp_name = result["configOut"]["experimentName"]
    logger.info(f"Configuration saved, experiment name: {exp_name}")
    return result


def execute_configuration(
        experimentName,
        apps,
        forceExecution,
        parallelExecution,
        output_fields
    ):
    studyName = experimentName.split("_std_")[1].split("_ver")[0]
    args = {
        "experimentName": experimentName,
        "studyName": studyName,
    }
    if forceExecution:
        args["forceExecution"] = forceExecution
    if parallelExecution:
        args["parallelExecution"] = parallelExecution
    if apps:
        args["executeApplication"] = {"apps":[{"app":app} for app in apps]}

    output_fields.append("message")
    result = mutate(get_client(), "executeConfig", args, output_fields=output_fields)
    return result

