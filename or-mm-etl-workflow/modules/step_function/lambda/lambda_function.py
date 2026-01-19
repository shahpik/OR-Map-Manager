import logging
import os
from src.aws_service import AwsService
from src.kubernetes_service import KubeService
from src.exceptions import ValidationException, MissingParamException


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, _context):
    "Lambda handler"
    logger.info(event)
    validate_event(event=event)
    job_params = event["job_params"]
    mode = event["mode"]
    response = {}
    cluster_name = os.getenv("ENV_PREFIX")
    # Init Aws
    aws = AwsService()
    eks = aws.get_eks_client()
    session = aws.get_sts_session()
    service_id = aws.get_sts_service_id()
    kube_bearer_token = aws.get_kube_bearer_token(
        cluster_name=cluster_name, session=session, service_id=service_id
    )

    kube = KubeService(cluster_name=cluster_name, eks=eks)
    kube_config = kube.get_kube_config(cluster_bearer_token=kube_bearer_token)
    kube.configure_kubenetes(kube_config=kube_config)
    batch_v1_api = kube.get_batch_api()

    if mode == "INITIATE":
        kube_response = kube.create_job(batch_v1_api, job_params=job_params)
        logger.info(f"Name: {kube_response['metadata']['name']}")
        logger.info(f"Creation: {kube_response['status']}")
        kube_status_response = kube.get_job_status(batch_v1_api, job_params=job_params)
        logger.info(f"Status: {kube_status_response['status']}")
        response = { "kube_creation": kube_response, "kube_status": kube_status_response }
        response["status"] = "Success"
        response["code"] = 200
        return response

    elif mode == "MONITOR":
        kube_response = kube.get_job_status(batch_v1_api, job_params=job_params)
        logger.info(kube_response['metadata']['name'])
        logger.info(f"Creation: {kube_response['status']}")
        response = kube_response['status']

        if response['active'] is None and \
            response['failed'] == 3 and \
            response['conditions'] is not None and \
            len(response['conditions']) > 0 and \
            any(condition.get('type') == "Failed" for condition in response['conditions']):
            logger.info("Job failed: 'active' is None, 'failed' count is 3, and conditions indicate failure.")
            response['job_status'] = "Failed"

        elif response['active'] is not None and response["active"] > 0:
            logger.info("Job is running: 'active' is greater than 0.")
            response["job_status"] = "Running"

        elif response['active'] is None and \
            response['succeeded'] is not None and \
            response['succeeded'] >= 1 and \
            response['conditions'] is not None and \
            len(response['conditions']) > 0 and \
            any(condition.get('type') == "Complete" and condition.get('status') == "True" for condition in response['conditions']):
            logger.info("Job completed successfully: 'succeeded' count is >= 1 and conditions indicate success.")
            response["job_status"] = "Success"
            
        elif response["failed"] is not None:
            logger.info("Job failed: 'failed' failed count is non-null.")
            response["job_status"] = "Failed"
        else:
            logger.info("Job status is unknown: none of the defined conditions were met.")
            response["job_status"] = "Unknown"

        response["status"] = "Success"
        response["code"] = 200
        return response

    elif mode == "DELETE":
        kube_response = kube.delete_job(batch_v1_api, job_params=job_params)
        logger.info(kube_response)
        response = kube_response
        response["status"] = "Success"
        response["code"] = 200
        return response

    else:
        raise ValidationException(
            error_message=f"Invalid value of 'mode'. Allowed values - MONITOR, INITIATE, DELETE. Found - ${mode}"
        )


def validate_event(event):
    if "mode" not in event:
        raise MissingParamException(param_name="mode")

    if event["mode"] not in ["MONITOR", "INITIATE", "DELETE"]:
        raise ValidationException(
            error_message=f"Invalid value of 'mode'. Allowed values - MONITOR, INITIATE, DELETE. Found - ${event['mode']}"
        )

    if "job_params" not in event:
        raise MissingParamException(param_name="job_params")

    job_params = event["job_params"]

    if "name" not in job_params:
        raise MissingParamException(param_name="job_params.name")
    
    if "namespace" not in job_params:
        raise MissingParamException(param_name="job_params.namespace")

    if "image" not in job_params and event["mode"] == "INITIATE":
        raise MissingParamException(param_name="job_params.image")

    if "julia_module" not in job_params and event["mode"] == "INITIATE":
        raise MissingParamException(param_name="job_params.julia_module")

    if "julia_function" not in job_params and event["mode"] == "INITIATE":
        raise MissingParamException(param_name="job_params.julia_function")


# ****** THIS LINE IS FOR LOCAL DEVELOPMENT ONLY ********
# proxy_url = os.getenv('http_proxy', None)

# ***** THIS CONDITION IS FOR LOCAL DEVELOPMENT ONLY ******
# if proxy_url:
#     proxy_url = "http://"+proxy_url
#     logging.warning("Setting proxy: {}".format(proxy_url))
#     client.Configuration._default.proxy = proxy_url

## ADDED FOR LOCAL DEVELOPMENT ONLY. STEP FUNCTION SHOULD EXECUTE THIS LOGIC
# job_completed = False
# while not job_completed:
#     api_response = get_job_status(batch_v1, job_params, create_response.metadata.name )
#     if api_response.status.succeeded is not None or \
#             api_response.status.failed is not None:
#         job_completed = True
#     sleep(1)
# print(f"Job status='{str(api_response.status)}'")

# SEE examples here: https://github.com/kubernetes-client/python/blob/master/examples/job_crud.py

# returns the api status. let the calling step function then decide on what to do
# the logic is either
#         api_response.status.succeeded is not None
#           or
#         api_response.status.failed is not None:
# for the job to be completed

# ***** THIS IS FOR LOCAL DEVELOPMENT ONLY *****
# if __name__ == "__main__":
#     main(None, None)
