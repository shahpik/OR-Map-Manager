

import argparse
import os
import shutil
from distutils.dir_util import copy_tree
from pathlib import Path

# TEMPLATE_RDS_PARAMETER_GROUP = asa-atm-test-optimalreality-rds-dbparametergroup
# TEMPLATE_RDS_SECURITY_GROUP = asa-atm-test-optimalreality-rds-security-group
# TEMPLATE_BASTION_SECURITY_GROUP = asa-atm-test-optimalreality-bastion-security-group
# TEMPLATE_VPC_SUBNET_GROUP_FOR_RDS = asa-atm-test-rds-dbsubnetgroup
# TEMPLATE_CLUSTER_NAME = asa-atm-test-optimalreality
# TEMPLATE_VPC_NAME = or-demo-test-vpc
# TEMPLATE_SSM_RDS_PASSWORD_KEY = /asa/atm/test/optimalreality/postgresql_password
# TEMPLATE_SSM_RDS_USERNAME_KEY = /asa/atm/test/optimalreality/postgresql_username
# TEMPLATE_RDS_IDENTIFIER = asa-atm-test-optimalreality
# TEMPLATE_BASTION_INSTANCE_NAME = asa-atm-test-optimalreality-bastion

patterns = {}


def generate_names_from_client_and_env(client, environment):
    name_arguments = {}
    name_arguments["TEMPLATE_RDS_PARAMETER_GROUP"] = f"{client}-{environment}-rds-dbparametergroup"
    name_arguments["TEMPLATE_RDS_SECURITY_GROUP"] = f"{client}-{environment}-rds-security-group"
    name_arguments["TEMPLATE_BASTION_SECURITY_GROUP"] = f"{client}-{environment}-bastion-security-group"
    name_arguments["TEMPLATE_VPC_SUBNET_GROUP_FOR_RDS"] = f"{client}-{environment}-rds-dbsubnetgroup"
    name_arguments["TEMPLATE_CLUSTER_NAME"] = f"{client}-{environment}"
    name_arguments["TEMPLATE_VPC_NAME"] = f"{client}-{environment}"
    name_arguments["TEMPLATE_SSM_RDS_PASSWORD_KEY"] = f"/{client}/{environment}/optimalreality/postgresql_password"
    name_arguments["TEMPLATE_SSM_RDS_USERNAME_KEY"] = f"/{client}/{environment}/optimalreality/postgresql_username"
    name_arguments["TEMPLATE_SSM_RDS_MASTER_PASSWORD_KEY"] = f"/{client}/{environment}/optimalreality/master_password"
    name_arguments["TEMPLATE_RDS_IDENTIFIER"] = f"{client}-{environment}"
    name_arguments["TEMPLATE_BASTION_INSTANCE_NAME"] = f"{client}-{environment}-bastion"
    name_arguments["TEMPLATE_CLIENT_NAME"] = f"{client}"

    return name_arguments

    
def replace_all_patterns(content, conf):
    for key in conf:
        content = content.replace(key, conf[key])
    return content


def copy_template(target_dir, conf):
    source_dir = "./aws_template"
    file_names = os.listdir(source_dir)
    for file_name in file_names:
        with open(source_dir + "/" + file_name, 'r') as file:
            file_data = file.read()
            file_data = replace_all_patterns(file_data, conf)
            target_file_path = os.path.join(target_dir, file_name)
            with open(target_file_path, "w") as f:
                f.write(file_data)

def copy_charts(root_dir):
    source_dir = "./microservices_charts"
    target_dir = os.path.join(root_dir, "microservices_charts")
    copy_tree(source_dir, target_dir)
    result = list(Path(target_dir).glob('**/values.yaml'))
    for chart_values_file in result:
        with open(chart_values_file, 'r') as file:
            file_data = file.read()
            file_data = replace_all_patterns(file_data, conf)
            with open(chart_values_file, "w") as f:
                f.write(file_data)


def read_conf(filename, client, env):
    lines = open(filename).readlines()
    conf = {}
    for line in lines:
        if line.strip().startswith("#"):
            continue
        try:
            toks = line.split("=")
            conf[toks[0].strip()] = toks[1].strip()
        except:
            pass
    name_arguments = generate_names_from_client_and_env(client, env)
    conf.update(name_arguments)
    return conf


if __name__ == '__main__':
   parser = argparse.ArgumentParser()
   parser.add_argument('--cloud')
   parser.add_argument('--root_dir')
   parser.add_argument('--conf_file')
   parser.add_argument('--client')
   parser.add_argument('--env')

   args = parser.parse_args()
   output_dir = os.path.join(args.root_dir, "terraform", args.env)

   arguments = {'cloud': args.cloud, 'output_dir': output_dir, 'conf_file': args.conf_file, "client":args.client, "env":args.env, "root_dir":args.root_dir}

   if not os.path.exists(arguments['output_dir']):
       os.makedirs(arguments['output_dir'])

   if arguments['cloud'].lower().strip() == 'aws':
        conf = read_conf(arguments['conf_file'], arguments['client'], arguments['env'])
        print(conf)
        print(f"Creating Terraform folder for AWS at {arguments['output_dir']}")
        try:
           os.mkdir(arguments['output_dir'])
        except:
            pass
        
        copy_template(arguments['output_dir'], conf)

        print(f"Creating Chart folder for Client at {arguments['output_dir']}")

        copy_charts(arguments["root_dir"])
        
        print(f"SUCCESS")

