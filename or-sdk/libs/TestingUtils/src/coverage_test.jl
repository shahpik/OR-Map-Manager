export run_coverage_report

"""
    run_coverage_report(dir::AbstractString; save_cov::Bool=false)

Entry point for running coverage report. This is used after the testing is run 
and .cov files are made. 

# Arguments:
- `dir`: String that is the path of the test dir of the microservice.
- `save_cov`: Bool the represents if we need to save the .cov files made from
the testing package when. 
"""
function run_coverage_report(dir::AbstractString; save_cov::Bool=false)
    # Process '*.cov' files
    src_root = replace(dir, "/test" => "/src")
    test_root = dir
    coverage = process_folder(src_root) # defaults to src/; alternatively, supply the folder name as argument
    results = map(x -> get_file_info(x, coverage), coverage)
    print_results_table(results)
    
    if !(save_cov)
        remove_cov(src_root)
        remove_cov(test_root)
    end
end
