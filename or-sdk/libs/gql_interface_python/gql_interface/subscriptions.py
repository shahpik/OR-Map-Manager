import logging
import asyncio
from datetime import datetime
from typing import Union

from gql.client import Client
from gql.gql import gql
from gql.transport.websockets import WebsocketsTransport

from gql_interface.exceptions import GraphQLError
from gql_interface.gql_client import GQLClient
from gql_interface.queries import get_generic_query_payload
from gql_interface.string_utils import get_output_str


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def subscription(
        client,
        on_response_function,
        subscription_name,
        subscription_args,
        output_fields="",
        **kwargs
    ):
    """
    Creates a subscription connection to the provided named subscription and applied the `on_response_function`\
    to the responses.

    Parameters
    ----------
        `client:GQLClient`
            The GQLClient for connecting to the Subscription.

        `on_response_function:callable`
            The function that will be applied to the subscription responses. Any other argument fields\
            must go in the **kwargs.

        `subscription_name:str`
            The name of the subscription.

        `subscription_args`
            The subscription query arguments.

        `output_fields=""`
            The output fields of the subscription.

        `**kwargs`
            Any other key work arguments that might be required for this or subsequent functions. The\
            following kwargs are used:
                `on_response_args:List` - A list of all the subscription method arguments in order.
                `on_response_kwargs:Dict` - A dictionary of keywords and arguments for the subscription\
                    method.
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
        `None`.
    """
    class_kwargs = {}
    class_kwarg_names = ["fn_init", "init_args", "sub_timeout", "fn_stop", "fn_logger"]
    response_kwargs = {}
    response_kwarg_names = ["on_response_args", "on_response_kwargs"]
    logger.debug(f"Decomposing kwargs:\n{kwargs}")
    for key, value in kwargs.items():
        if key in class_kwarg_names:
            class_kwargs[key] = value
        if key in response_kwarg_names:
            response_kwargs[key] = value

    logger.info("Setting up the subscription.")
    subscription =  GQLSubscription(
        client,
        **class_kwargs
    )

    if "fn_response_processing" in kwargs.keys():
        logger.info(f"Applying the response processor: {kwargs['fn_response_processing'].__name__}")
        subscription.set_response_processing(kwargs["fn_response_processing"])

    subscription.set_payload(
        subscription_name,
        subscription_args,
        output_fields
    )

    if "on_response_args" not in response_kwargs.keys():
        response_kwargs["on_response_args"] = []
    if "on_response_kwargs" not in response_kwargs.keys():
        response_kwargs["on_response_kwargs"] = {}
    logging.debug(
        f"Beginning the subscription to {subscription_name}\nApplying {on_response_function.__name__} to the response with:\n"
        f"Response arguments: {response_kwargs['on_response_args']}\nResponse kwargs: {response_kwargs['on_response_kwargs']}")
    await subscription.subscribe(
        on_response_function,
        *response_kwargs["on_response_args"],
        **response_kwargs["on_response_kwargs"]
    )


class GQLSubscription():
    """
    The GraphQL Subscription Manager class, which maintains any and all subscriptions to a GraphQL\
    experiment manage.
    """

    # NOTE: an attempt was made create an async-appropriate, context-managed class using the __aenter__ and __aexit__
    #   attributes, but it was not successful. Revisitng thins would solve a LOT of problems
    # TODO: Make this class work with the async context manager using __aenter__ and __aexit__

    _log_level = logging.INFO
    _log_name = "INFO"

    def __init__(
            self,
            client:GQLClient,
            fn_init:Union[callable, None]=None,
            init_args=None,
            sub_timeout:int=0,
            fn_stop:Union[callable, None]=None,
            fn_logger:Union[callable, None]=None
        ):
        """
        Constructs a new GraphQL Subscription connector using the provided client. This should be wrapped by a subscription
        function.

        Attributes
        ----------
            `client:GQLClient`
                The GQLClient for connecting to the Subscription
            `fn_init:Union[callable, None]=None`
                An initiation function that is run when the subscription is started. It receives the\
                `init_args` attribute as a parameter when it is run.
            `init_args=None`
                The arguments for the `fn_init` function when it's run at the start of the subscription.
            `sub_timeout:int=0`
                The subscription timeout in seconds, used as the default comparison condition for the\
                `_check_timeout_condition` method. If zero, then the `_check_timeout_condition`\
                method will never check time out and will always return true. A negative will always\
                return `False` and break the subscription.
            `fn_stop:Union[callable, None]=None`
                If a function is provided then that function is used as the subscription end condition.\
                By default, if no function is provided, then the `_check_timeout_condition` method is used\
                to end the subscription.
            `fn_logger:Union[callable, None]=None`
                If a function is provided then that function is used as the default logging. By default\
                if no function is provided, then a new instance of a logger is created for the object\
                and is set to the class defined logging level.


        Returns
        -------
            `GQLSubscription`
                Returns a GQL subscription object configured for the provided GQLClient. The subscription\
                query payload has not yet been defined, and no processessing will be done to the response\
                data other than get the data from the query name level of the response.

        Examples
        --------
            >>> sample_client = GQLClient(*client_args)
            >>> GQLSubscription(sample_client)
            GQLSubscription

        """
        # Public attributes
        self.client = client
        self.init_args = init_args
        self.sub_timeout = sub_timeout
        self.start_time = None

        # Public methods
        self.fn_init = GQLSubscription.placeholder
        self.fn_stop = GQLSubscription.placeholder
        self.fn_logger = GQLSubscription.placeholder

        if fn_logger is None or not callable(fn_logger):
            logging.basicConfig(level=GQLSubscription._log_level)  # TODO: Set to ENV
            self.fn_logger = logging.getLogger(f"{__name__}.GQLSubscription").info
            self.fn_logger(f"Using a default logger, with the following level: {GQLSubscription._log_name}")
        else:
            self.fn_logger = fn_logger

        if fn_init is not None and callable(fn_init):
            self.fn_init = fn_init

        if fn_stop is None or not callable(fn_stop):
            self.fn_stop = self._check_timeout_condition
        else:
            self.fn_stop = fn_stop

        # Private attributes
        self._subscription_transport = self._set_sub_transport()
        self._subscription_name = None
        self._payload = None

        # Private methods
        self._response_processing = GQLSubscription.clean_response

    @staticmethod
    async def clean_response(data):
        """Returns the data as-is."""
        return data

    @staticmethod
    def placeholder(*args, **kwargs):
        """Placeholder pass function, used for initialisation."""
        pass

    def set_response_processing(self, processing_function):
        """Sets the response processing function, an async function that processes and then returns a response."""
        self.fn_logger(f"The subscription response processing function has been updated to: {processing_function.__name__}")
        self.set_response_processing = processing_function


    def _check_timeout_condition(self, resp):
        if self.sub_timeout == 0:
            return True  # Never time out.
        if self.sub_timeout < 0:
            return False  # Immediately time out
        check = abs(self.start_time - int(datetime.now().timestamp())) >= self.sub_timeout
        if check:
            self.fn_logger("Timeout condition has been met.")
        return check

    def _set_sub_transport(
            self,
            connect_timeout=120,
            close_timeout=60,
            ack_timeout=60
        ):
        """
        Constructs the websocked subscription transport client, based on the client attribute.
        """
        headers = {x: self.client.headers[x] for x in self.client.headers}
        headers["Content-Type"] = "application/json"
        ws_endpoint = f"{self.client.ws_endpoint}/subscriptions"
        ws_connection_args = {"ping_interval": None}  # NOTE: DO NOT CHANGE
        return WebsocketsTransport(
            url=ws_endpoint,
            headers=headers,
            connect_timeout=connect_timeout,
            close_timeout=close_timeout,
            ack_timeout=ack_timeout,
            connect_args=ws_connection_args
        )

    def set_payload(
            self,
            subscription_name,
            sub_args,
            output_fields,
        ):
        """
        Constructs the subscription payload.
        """
        if self._subscription_name is not None or self._payload is not None:
            self.fn_logger(f"Setting a new subscription payload: {subscription_name}.")
        self._subscription_name = subscription_name
        output_str = get_output_str(output_fields)
        self._payload = get_generic_query_payload(
            "subscription",
            subscription_name,
            sub_args,
            output_str,
            client=self.client
        )

    async def subscribe(
            self,
            response_function,
            *args,
            **kwargs
        ):
        """
        The subscription interface for the GQLSubscription object. This function will apply the supplied\
        response function to the subscription response when it is received.
        """
        if self._subscription_name is None or self._payload is None:
            raise GraphQLError("A subscription name and subscription payload are required to subscribe.")
        self.fn_logger(f"Creating a subscription connection to {self._subscription_name}.")
        async with Client(
            transport=self._subscription_transport,
            execute_timeout=10000
        ) as subscription_session:
            self.start_time = int(datetime.now().timestamp())
            self.fn_logger(f"Establishing the subscription connection at {self.start_time}.")
            self.fn_init(self.init_args)
            async for response in subscription_session.subscribe(
                gql(self._payload["query"]),
                variable_values=self._payload["variables"]
            ):
                # TODO: Redesign this section to prevent blocking and make better use f async functionality.
                resp = await asyncio.ensure_future(self._response_processing(response[self._subscription_name]))
                asyncio.ensure_future(response_function(resp, *args, **kwargs))

                if self.fn_stop(resp):
                    self.fn_logger(f"Closing subscription to {self._subscription_name} at {int(datetime.now().timestamp())}, stop requirements have been met.")
                    break

