import boto3
import re
import base64
from botocore.signers import RequestSigner


class AwsService:
    STS_TOKEN_EXPIRES_IN = 60

    def __init__(self) -> None:
        self.eks = boto3.client("eks")
        self.session = boto3.session.Session()
        self.sts = self.session.client("sts")

    def get_eks_client(self):
        return self.eks

    def get_sts_client(self):
        return self.sts

    def get_sts_session(self):
        return self.session

    def get_sts_service_id(self):
        return self.sts.meta.service_model.service_id

    def get_kube_bearer_token(self, cluster_name, session, service_id):
        "Create authentication token"
        if session == None:
            session = self.session

        if service_id == None:
            service_id = self.get_sts_service_id()

        signer = RequestSigner(
            service_id,
            session.region_name,
            "sts",
            "v4",
            session.get_credentials(),
            session.events,
        )

        params = {
            "method": "GET",
            "url": "https://sts.{}.amazonaws.com/"
            "?Action=GetCallerIdentity&Version=2011-06-15".format(session.region_name),
            "body": {},
            "headers": {"x-k8s-aws-id": cluster_name},
            "context": {},
        }

        signed_url = signer.generate_presigned_url(
            params,
            region_name=session.region_name,
            expires_in=self.STS_TOKEN_EXPIRES_IN,
            operation_name="",
        )
        base64_url = base64.urlsafe_b64encode(signed_url.encode("utf-8")).decode(
            "utf-8"
        )

        # remove any base64 encoding padding:
        return "k8s-aws-v1." + re.sub(r"=*", "", base64_url)
