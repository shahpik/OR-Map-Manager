"""
    get_file_info(file, coverage)

Returns filename, lines covered, total lines and percentage value for coverage variable.
"""
function get_file_info(file, coverage)
    i_range = findlast("/src/", coverage[1].filename)
    filename = file.filename[i_range[2]:end]
    lines_covered, total_lines = get_summary(file)
    percent = iszero(total_lines) ? 100.0 : lines_covered * 100 / total_lines
    return (; filename, lines_covered, total_lines, percent)
end

"""
    remove_cov(path)

After processing the .cov files, remove all files that finish with 
the .cov extension. This is run be default. To keep .cov files use
"make local-unit-test COVERAGE=true SAVECOV=true"

# Arguments:
- `path`: Path to remove *.cov files from
"""
function remove_cov(path)
    foreach(rm, filter(endswith(".cov"), "$(path)/" .* readdir(path))) 
end