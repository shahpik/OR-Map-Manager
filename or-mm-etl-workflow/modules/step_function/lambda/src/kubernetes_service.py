import logging
import jinja2
import yaml
import json

from kubernetes import client, config

from src.utils import DateTimeEncoder

cluster_cache = {}
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class KubeService:

    def __init__(self, cluster_name, eks) -> None:
        self.eks = eks
        self.cluster_name = cluster_name
        # Jinja configs to render the job manifest
        templateLoader = jinja2.FileSystemLoader(searchpath="./")
        self.templateEnv = jinja2.Environment(
            autoescape=jinja2.select_autoescape(default_for_string=True, default=True),
            loader=templateLoader,
            trim_blocks=True,
        )

    def get_cluster_info(self, cluster_name=None):
        "Retrieve cluster endpoint and certificate"

        if cluster_name == None:
            cluster_name = self.cluster_name

        cluster_info = self.eks.describe_cluster(name=cluster_name)

        endpoint = cluster_info["cluster"]["endpoint"]
        cert_authority = cluster_info["cluster"]["certificateAuthority"]["data"]

        cluster_info = {"endpoint": endpoint, "ca": cert_authority}
        return cluster_info

    def get_cluster(self, cluster_name=None):
        if cluster_name == None:
            cluster_name = self.cluster_name

        cluster = None

        if cluster_name in cluster_cache:
            cluster = cluster_cache[cluster_name]
        else:
            # not present in cache retrieve cluster info from EKS service
            cluster = self.get_cluster_info(cluster_name=cluster_name)
            # store in cache for execution environment resuse
            cluster_cache[cluster_name] = cluster
        return cluster

    def get_kube_config(
        self, cluster_bearer_token, cluster_ca=None, cluster_endpoint=None
    ):
        if cluster_ca == None:
            cluster_ca = self.get_cluster()["ca"]

        if cluster_endpoint == None:
            cluster_endpoint = self.get_cluster()["endpoint"]

        kubeconfig = {
            "apiVersion": "v1",
            "clusters": [
                {
                    "name": "cluster1",
                    "cluster": {
                        "certificate-authority-data": cluster_ca,
                        "server": cluster_endpoint,
                    },
                }
            ],
            "contexts": [
                {
                    "name": "context1",
                    "context": {"cluster": "cluster1", "user": "user1"},
                }
            ],
            "current-context": "context1",
            "kind": "Config",
            "preferences": {},
            "users": [{"name": "user1", "user": {"token": cluster_bearer_token}}],
        }

        return kubeconfig

    def configure_kubenetes(self, kube_config=None):
        if kube_config == None:
            kube_config = self.get_kube_config()

        config.load_kube_config_from_dict(config_dict=kube_config)

    def create_job(self, api_instance, job_params):
        "create a job based on passed in parameters and the jinja2 templates"

        logging.info(f"job_params: {job_params}")

        # use the template file to render the job manifest
        template_file = "templates/job.yaml.jinja"
        template = self.templateEnv.get_template(template_file)

        job = yaml.safe_load(template.render(vars=job_params))

        creation_response = api_instance.create_namespaced_job(
            body=job, namespace=job_params["namespace"], pretty=True
        )

        creation_response_json = json.loads(
            json.dumps(
                creation_response.to_dict(),
                cls=DateTimeEncoder,
                indent=4,
                sort_keys=True,
                default=str,
            )
        )

        logging.info(f"Job created. status='{creation_response_json}'")

        # status_response_json = self.get_job_status(api_instance, job_params)

        return creation_response_json

    def get_job_status(self, api_instance, job_params):
        "get the status of a job based on passed in parameters"

        api_response = api_instance.read_namespaced_job_status(
            name=job_params["name"], namespace=job_params["namespace"], pretty=True
        )

        print(f"Job status='{str(api_response.status)}'")

        return json.loads(
            json.dumps(
                api_response.to_dict(),
                cls=DateTimeEncoder,
                indent=4,
                sort_keys=True,
                default=str,
            )
        )

    def delete_job(self, api_instance, job_params):
        try:
            api_response = api_instance.delete_namespaced_job(
                name=job_params["name"],
                namespace=job_params["namespace"],
                body=client.V1DeleteOptions(propagation_policy='Background'),
            )
            
            logger.info(f"Job '{job_params['name']}' deleted successfully.")
            
            return json.loads(
                json.dumps(
                    api_response.to_dict(),
                    cls=DateTimeEncoder,
                    indent=4,
                    sort_keys=True,
                    default=str,
                )
            )
        except Exception as e:
            logger.error(f"Error deleting Job '{job_params['name']}': {str(e)}")

    def get_batch_api(self):
        return client.BatchV1Api()
