import os
import logging
from datetime import datetime

from em_interface.connect import connect
from em_interface.generic_gql import em_query, em_mutate, em_subscription


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

EXPERIMENT_MANAGER_ENDPOINT = os.getenv(
    "EXPERIMENT_MANAGER_ENDPOINT",
    "https://localhost:5100"
) + "/graphql"
EXPERIMENT_MANAGER_WS_ENDPOINT = os.getenv(
    "EXPERIMENT_MANAGER_WS_ENDPOINT",
    "wss://localhost:5100"
)
token = os.getenv("OR_MASTER_JWT", "06ef51e77eb04ff6a30a6d831aab1d81")
headers = {"Authorization": f"Bearer {token}"}


connect(EXPERIMENT_MANAGER_ENDPOINT,
        ws_endpoint=EXPERIMENT_MANAGER_WS_ENDPOINT,
        token=token)

result = em_query("getSession", query_args={}, output_fields=["name"])

logging.info(f"RESULT:\n{result}")

# logging.info(em_mutate("saveConfig", {"studyName": "test"}, output_fields=["message"]))
# logging.info(em_mutate("saveConfig", {"studyName": "test", "updateExisting": True}))


def sample_function(resp, *args, **kwargs):
    print(f"The subscription says:\n{resp}")

def test_start_function(*args, **kwargs):
    print("This is an example of an initialisation function.")
    print(f"It ran at: {int(datetime.now().timestamp())}")

query_name = "subTask"
query_arguments = {"taskIds": []}

optional_kwargs = {
    "output_fields": ["taskId", "status", "eventIds"],
    "sub_timeout": 300,  # Timeout in seconds
    "fn_init": test_start_function,
}

em_subscription(query_name, sample_function, query_arguments, **optional_kwargs)