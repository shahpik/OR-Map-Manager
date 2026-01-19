"""
    print_results_table(results)

Uses PrettyTables.jl to print out a pretty table.
"""
function print_results_table(results)
    # Convert results to arrays for each column and append total results
    filenames = push!([result.filename for result in results], "TOTAL")
    lines_covered = [result.lines_covered for result in results]
    lines_covered = vcat(lines_covered, sum(lines_covered))
    total_lines = [result.total_lines for result in results]
    total_lines = vcat(total_lines, sum(total_lines))
    percent = [result.percent for result in results]
    percent = vcat(percent, lines_covered[end]*100/total_lines[end])

    # Format into data matrix
    nrows = length(filenames)
    data = hcat(filenames, lines_covered, total_lines, percent)

    # Set up table
    column_names = ["File", "Lines Covered", "Total Lines", "Percent"]
    formatters = ft_printf("%5.1f", 4:4)
    hl_g = Highlighter((data, i, j)->(j==4) && (data[i,j] >= 95.0), crayon"green bold")
    hl_y = Highlighter((data, i, j)->(j==4) && (data[i,j] >= 80.0), crayon"yellow bold")
    hl_r = Highlighter((data, i, j)->(j==4) && (data[i,j] < 80.0), crayon"red bold")
    hl_b = Highlighter((data, i, j)->(i==nrows), crayon"bold")

    # Print
    pretty_table(
        data;
        header=column_names,
        formatters=formatters,
        highlighters=(hl_g, hl_y, hl_r, hl_b),
        tf=tf_compact,
        body_hlines=[nrows-1]
    )
end