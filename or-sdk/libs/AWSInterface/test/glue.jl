include("../src/services/glue.jl")

@testset "glue config" begin
    
    parms = GlueInterface._make_glue_parameters(;
        command_name="glueetl",
        job_name="job_name",
        script_location="s3://bucket/path/file.py",
        description="glue job",
        role="arn:aws:iam::999999999999:role/service-role/AWSGlueServiceRole-gluerole",
        glue_bucket="glue_bucket",
        glue_bucket_path_prefix="dev-1")

    # minimum requirements testing, including clashing parameters
    @test haskey(parms, "Name")
    @test sum([haskey(parms, "AllocatedCapacity"), haskey(parms, "MaxCapacity")]) <= 1
    @test sum([(haskey(parms, "WorkerType") && haskey(parms, "NumberOfWorkers")), haskey(parms, "MaxCapacity")]) <= 1

end
