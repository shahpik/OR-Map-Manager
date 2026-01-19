import argparse
import os
import shutil
from distutils.dir_util import copy_tree
import subprocess
import json

values_to_replace = {
   "TEMPLATE_RDS_ENDPOINT": "",
}


def replace_all_patterns(content, conf):
    for key in conf:
        content = content.replace(key, conf[key])
    return content


def generate_values(base_file_directory, env):
    with open(os.path.join(base_file_directory, "values.yaml") , 'r') as f:
         file_data = f.read()
         file_data = replace_all_patterns(file_data, values_to_replace)
         target_file_path = os.path.join(base_file_directory, f"values_{env}.yaml")
         with open(target_file_path, "w") as f:
            f.write(file_data)

def create_deploy_pipeline_yaml(base_file_directory, client_name):
    content = ""
    with open(os.path.join(base_file_directory,"microservices_charts", "deploy_pipeline.yaml") , 'r') as f:
        file_data = f.read()
        content = file_data.replace("TEMPLATE_CLIENT_NAME", client_name)
    
    with open(os.path.join(base_file_directory,"microservices_charts", "deploy_pipeline.yaml") , "w") as f:
         f.write(content)
        
        
if __name__ == '__main__':
   parser = argparse.ArgumentParser()
   parser.add_argument('--root_dir')
   parser.add_argument('--env')
   parser.add_argument('--client')
   parser.add_argument('--cloud')

   args = parser.parse_args()

   arguments = {'cloud': args.cloud, 'root_dir': args.root_dir, "env":args.env, "client": args.client}

   if arguments['cloud'].lower().strip() == 'aws':
        print(f"Generating helm chart values for ** {args.env} ** environment for all microservices at {arguments['root_dir']}")
        

        cwd = os.getcwd()
        tf_directory = os.path.join(args.root_dir, "terraform", args.env)
        os.chdir(tf_directory)
        
        terraform_output = json.loads(os.popen('terraform output -json ').read())

        print(terraform_output)
        rds_endpoint = terraform_output['rds_endpoint']['value']

        #TODO: add oidc_endpoint
        values_to_replace['TEMPLATE_RDS_ENDPOINT'] = rds_endpoint
        values_to_replace['TEMPLATE_CLIENT_ENV'] = f"{arguments['client']}-{arguments['env']}"
        values_to_replace['TEMPLATE_EKS_ROLE'] = terraform_output['kube_sa_role_arn']['value']
        print(values_to_replace)
        
        microservices = os.listdir(os.path.join(args.root_dir, "microservices_charts"))
        print(microservices)
        
        for service in microservices:
            if ".yaml" in service:
                continue
            graphql_path = os.path.join(args.root_dir, "microservices_charts", service, "chart")
            generate_values(graphql_path, args.env)

        create_deploy_pipeline_yaml(args.root_dir, arguments['client'])