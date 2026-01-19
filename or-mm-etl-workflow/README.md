# Introduction 
Map Manager needs to load data on-demand from static external sources such as OpenStreetMap, DataShare, etc.
Map Importer, Map-Matcher, Map-Editor, Map-Exporter four Map Manager Microservices operate on a "extract-load-transform" (ELT) model, where the data is loaded into/from the database/s3 bucket, then directly transformed and inserted through SQL scripts. 
- AWS Services: AWS Step Function, Lambda, Event Bridage, Kubernetes
- Language: Julia, Python, Jinja, Terraform

# Infrastructure
- Map Manger ETL Step Function workflow: https://hub.deloittedigital.com.au/wiki/display/DOTOR/06.1.5+Importing

- Map Manager AWS Cloud Infrastructure workflow: https://hub.deloittedigital.com.au/wiki/display/DOTOR/07.7+AWS+Lambda%2C+Step+Function+with+AWS+EKS+Batch+Job

# Build
- Pipeline: https://dev.azure.com/dd-managed-services/Optimal-Reality/_build?definitionId=1428
- Code Base: https://dev.azure.com/dd-managed-services/Optimal-Reality/_git/or-mm-etl-workflow

# Contribute
Thanks to:
- Developer: Prashant Solanki
- Developer: Nini Cui
- DevOps: Xiaofen Pan
- DevOps: Joseph Lin