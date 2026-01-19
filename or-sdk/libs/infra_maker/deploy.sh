# This will be deleted - This will be in make file and this is just an example to test 
helm upgrade redis microservices_charts/redis/chart \
	--install \
	--create-namespace \
	--namespace test \
	--wait

helm upgrade tile38 microservices_charts/tile38/chart \
	--install \
	--create-namespace \
	--namespace test \
	--wait


helm install graphql-service microservices_charts/graphql_service/chart \
    --create-namespace \
    --namespace test \
    --set-string aws.region=ap-southeast-2 \
    --set-string tpoc.aws_region=ap-southeast-2 \
    --set-string image.repository=438954004210.dkr.ecr.ap-southeast-2.amazonaws.com/asa/atm/graphql-service \
    --set-string image.tag=0.21.103 \
    --values microservices_charts/graphql_service/chart/values_test.yaml \
    --set-string tpoc.aws_access_key_id=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string tpoc.aws_secret_access_key=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresqlSimulation.password=`aws ssm get-parameter --name /asa/atm/test/optimalreality/postgresql_password --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresqlSimulation.username=`aws ssm get-parameter --name /asa/atm/test/optimalreality/postgresql_username --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresql.password=`aws ssm get-parameter --name /asa/atm/test/optimalreality/master_password --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
--set-string aws.accessKeyId=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
--set-string aws.secretAccessKey=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text`  \
 --atomic


helm install session-manager-service microservices_charts/SessionManager/chart \
    --create-namespace \
    --namespace test \
    --set-string aws.region=ap-southeast-2 \
    --set-string tpoc.aws_region=ap-southeast-2 \
    --set-string image.repository=438954004210.dkr.ecr.ap-southeast-2.amazonaws.com/asa/atm/session-manager-service \
    --set-string image.tag=latest \
    --values microservices_charts/SessionManager/chart/values_test.yaml \
    --set-string tpoc.aws_access_key_id=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string tpoc.aws_secret_access_key=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresqlSimulation.password=`aws ssm get-parameter --name /asa/atm/test/optimalreality/postgresql_password --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresqlSimulation.username=`aws ssm get-parameter --name /asa/atm/test/optimalreality/postgresql_username --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
    --set-string postgresql.password=`aws ssm get-parameter --name /asa/atm/test/optimalreality/master_password --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
--set-string aws.accessKeyId=`aws ssm get-parameter --name /tpoc/aws_access_key_id --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text` \
--set-string aws.secretAccessKey=`aws ssm get-parameter --name /tpoc/aws_secret_access_key --region ap-southeast-2 --query 'Parameter.Value' --with-decryption --output text`  \
 --atomic
    