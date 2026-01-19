import os
import logging
import asyncio

from gql_interface.gql_client import GQLClient
from gql_interface.introspection import full_introspection
from gql_interface.queries import get_generic_query_payload
from gql_interface.mutations import mutate
from gql_interface.queries import query
from gql_interface.subscriptions import subscription, GQLSubscription


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

EXPERIMENT_MANAGER_ENDPOINT = os.getenv(
    "EXPERIMENT_MANAGER_ENDPOINT",
    "https://graphql-nonprod.optimalreality.com.au"
) + "/graphql"
EXPERIMENT_MANAGER_WS_ENDPOINT = os.getenv(
    "EXPERIMENT_MANAGER_WS_ENDPOINT",
    "wss://graphql-nonprod.optimalreality.com.au"
)
token = os.getenv("OR_MASTER_JWT", "06ef51e77eb04ff6a30a6d831aab1d81")
headers = {"Authorization": f"Bearer {token}"}

# # Test the GQLClient, introspection, etc using a test GraphQL API
# client = GQLClient("https://apollo.fanoutapp.com/")
# query1 = """
#    mutation {
#   addNote(note:{
#     content:"buy bread",
#     collection:"shopping",
#   }) {
#     id,
#     content,
#     collection,
#   }
# }
# """

# logger.info(execute(client, query))
# full_introspection(client)
# logger.info(client.query_to_type_map)
# logger.info(client.query_to_args_map)
# logger.info(client.input_object_fields_to_type_map)
# logger.info(client.type_to_fields_map)
# args = {"note": {
#     "content": "buy bread",
#     "collection": "shopping",
# }}
# output_fields = ["id", "content", "collection"]
#
# logger.info(mutate(client, "addNote", args, output_fields=output_fields))
# logger.info(query(client, "notes",{}, output_fields=["id"] ))

# # Test the introspection on the EM endpoint
# client = GQLClient(EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT, headers=headers)
# logger.info(full_introspection(client))

async def print_and_false(data):
    logger.info("\nThis is a simple test function\n\n")
    print(data)
    return False

def test_start_function(*args, **kwargs):
    print("This is an example of an initialisation function.")
    print("""
 __________   ___      ___      .___  ___. .______    __       _______ 
|   ____\  \ /  /     /   \     |   \/   | |   _  \  |  |     |   ____|
|  |__   \  V  /     /  ^  \    |  \  /  | |  |_)  | |  |     |  |__   
|   __|   >   <     /  /_\  \   |  |\/|  | |   ___/  |  |     |   __|  
|  |____ /  .  \   /  _____  \  |  |  |  | |  |      |  `----.|  |____ 
|_______/__/ \__\ /__/     \__\ |__|  |__| | _|      |_______||_______|
    """)

async def test_function(EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT, headers):
    client = GQLClient(EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT, headers=headers)
    full_introspection(client)

    logger.info("Introspection complete.")

    query_name = "subTask"
    query_arguments = {"taskIds": []}
    query_output = ["taskId", "status", "eventIds"]

    optional_kwargs = {
        "sub_timeout": 300,  # Timeout in seconds
        "fn_init": test_start_function,
    }

    await subscription(
        client,
        print_and_false,
        query_name,
        subscription_args=query_arguments,
        output_fields=query_output,
        **optional_kwargs
    )

    # test_sub =  GQLSubscription(
    #     client,
    # )

    # test_sub.set_payload(
    #     query_name,
    #     query_arguments,
    #     query_output
    # )

    # await test_sub.subscribe(
    #     print_and_false,
    # )

asyncio.run(test_function(EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT, headers))


