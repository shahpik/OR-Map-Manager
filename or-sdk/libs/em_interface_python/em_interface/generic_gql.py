import asyncio
import logging
from functools import wraps, partial

from gql_interface.mutations import mutate
from gql_interface.queries import query
from gql_interface.subscriptions import subscription
# from gql_interface.utilities import async_wrap

from em_interface.connect import get_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def em_query(query_name:str, **kwargs):
    """
    Runs the provided query with the provided key word arguments on the globally defined `CLIENT` singleton.

    Parameters
    ----------
    `query_name:str`
        Name of the GQL query that is being called, which must exist in the GQL server that is connected in\
        the globally defined `CLIENT` singleton.

    `**kwargs`
        Optional arguments for the mutation query to run, icluding:
            `query_args` - Dictionary of strings or nested dictionaries as defined by `CLIENT`. See examples or the target GQL\
                Server documentation for more information.
            `output_fields` - List of strings or nested dictionaries and/or lists as defined by `CLIENT`. See examples or the \
                target GQL Server documentation for more information.
            ...

    Returns
    -------
    Query output as a `List`, `Dict`, or `Str` as defined by the `CLIENT` for the query.

    Examples
    --------
    >>> em_query(
    >>>     "getWay",  # Query name, which exists in the `CLIENT` GQL Server.
    >>>     query_args={"ref": {"wayId": 126228664}},  # Nested query argument that is required for the query.
    >>>     output_fields=["wayId"]  # The output fields that are desired from those available in the `CLIENT` GQL Server.
    >>> )
    [{"wayId": "126228664"}]

    """
    return query(get_client(), query_name, **kwargs)


def em_mutate(query_name, *args, **kwargs):
    """
    Runs the provided mutation with the provided arguments and key-word arguments on the globally defined `CLIENT` singleton. This is\
    updating data in one or more locations connected to the `CLIENT`.

    Parameters
    ----------
    `query_name:str`
        Name of the GQL mutation that is being called, which must exist in the GQL server that is connected in\
            the globally defined `CLIENT` singleton.

    `args`
        A number of required arguments for the mutation query to run:
            `query_args` - Dictionary of strings or nested dictionaries as defined by `CLIENT`. See examples or the target GQL\
                Server documentation for more information.

    `**kwargs:dict`
        Optional arguments for the mutation query to run, icluding:
            `output_fields` - List of strings or nested dictionaries and/or lists as defined by `CLIENT`. See examples or the \
                target GQL Server documentation for more information.
            ...

    Returns
    -------
    Mutation output or response as a `List`, `Dict`, or `Str` as defined by the `CLIENT` for the query.

    Examples
    --------
    >>>  # These are the stringified list of stringified actuals and stringified references
    >>> stringified_actuals = f"[{', '.join([json.dumps(dict) for dict in actuals_list])}]" 
    >>> stringified_references = f"[{', '.join([json.dumps(dict) for dict in references_list])}]"
    >>> em_mutate(
    >>>     "updateLiveEventActual",
    >>>     {
    >>>         "actual": stringified_actuals
    >>>         "refData": stringified_references
    >>>     },
    >>>     output_fields=["message"]
    >>> )
    # TODO: Add the output message string here.

    """
    return mutate(get_client(), query_name, *args, **kwargs)


def em_subscription(query_name, on_response_function, *args, **kwargs):
    """
    Runs the provided subscription and applies the `on_response_function` to the subscription responses,\
    with the provided arguments and key-word arguments on the globally defined `CLIENT` singleton.

    Parameters
    ----------
    `query_name:str`
        Name of the GQL subscription that is being called, which must exist in the GQL server that is connected in\
            the globally defined `CLIENT` singleton.

    `on_response_function:callable`
        A callable function that must take the response as an input. additional `*args` and `**kwargs` can be provided\
            in the `**kwargs`

    `args`
        A number of required arguments for the subscription query to run:
            `subscription_args` -Dictionary of strings or nested dictionaries as defined by `CLIENT`. See examples or the target GQL\
                Server documentation for more information.

    `**kwargs:dict`
        Optional arguments for the subscription query to run, icluding:
            `output_fields=""` - The output fields of the subscription.
            `on_response_args:List` - A list of all the subscription method arguments in order.
            `on_response_kwargs:Dict` - A dictionary of keywords and arguments for the subscription method.
            `fn_init:Callable` - A function to run when the subscription is set up.
            `init_args` - Single argument for the `fn_init` function.  # TODO: More args and kwargs
            `sub_timeout:int` - The subscription timeout in seconds, used as the default comparison\
                condition for the default `fn_stop` function.
            `fn_stop:Callable` - Stopping function for the subscription. Must only take the subscription\
                response as an input.
            `fn_logger:Callable` - Logging function to use if the default is not advised. Must take\
                string as an input.
            `fn_response_processing:Callable` - A processing function applied to the response items\
                to convert their format or make them more appropriate as input to the `on_response_function`.

    Returns
    -------
    None.

    Examples
    --------
    >>> def sample_function(resp, *args, **kwargs):
    >>>     print(f"The subscription says:\\n{resp}")
    >>> def test_start_function(*args, **kwargs):
    >>>     print("This is an example of an initialisation function.")
    >>>     print(f"It ran at: {int(datetime.now().timestamp())}")
    >>> query_name = "subTask"
    >>> query_arguments = {"taskIds": []}
    >>> optional_kwargs = {
    >>>     "output_fields": ["taskId", "status", "eventIds"],
    >>>     "sub_timeout": 300,  # Timeout in seconds
    >>>     "fn_init": test_start_function,
    >>> }
    >>> em_subscription(query_name, sample_function, query_arguments, **optional_kwargs)
    This is an example of an initialisation function.
    It ran at: 1614224450
    INFO:gql.transport.websockets:>>> {"id": "1", "type": "start", "payload": {"query": "subscription \
        ($taskIds: [String]) {\\n subTask(taskIds: $taskIds) {\\n   taskId\\n   status\\n   eventIds\\n \
        }\\n}\\n", "variables": {"taskIds": []}}}

    """
    output_fields = ""
    if "output_fields" in kwargs.keys():
        logger.debug(kwargs["output_fields"])
        output_fields = kwargs["output_fields"]
        del kwargs["output_fields"]  # Remove it to prevent confusion

    func = on_response_function
    if not asyncio.iscoroutinefunction(on_response_function):
        logger.debug("A synchronous function was input. Wrapping it with an asynch loop.")
        func = async_wrap(on_response_function)

    asyncio.run(subscription(get_client(), func, query_name, *args, output_fields=output_fields, **kwargs))


def async_wrap(func):
    """Wraps or decorates a function to ensure it is asynchronous."""
    @wraps(func)
    async def run(*args, loop=None, executor=None, **kwargs):
        if loop is None:
            loop = asyncio.get_event_loop()
        pfunc = partial(func, *args, **kwargs)
        return await loop.run_in_executor(executor, pfunc)
    return run