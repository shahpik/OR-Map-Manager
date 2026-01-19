# Use a mix of Int and Float formats to test tolerance for different types

@testset "Test get_line_wkt(vector_x, vector_y)" begin
    @testset "Valid integer linestring" begin
        line_x_int = Vector{Int64}([1, 2, 3])
        line_y_int = Vector{Int64}([1, 2, 3])
        @test get_line_wkt(line_x_int, line_y_int) == "LINESTRING(1 1, 2 2, 3 3)"
    end

    @testset "Valid float linestring" begin
        line_x_float = Vector{Float64}([1.1, 2.2, 3.3])
        line_y_float = Vector{Float64}([1.1, 2.2, 3.3])
        @test get_line_wkt(line_x_float, line_y_float) == "LINESTRING(1.1 1.1, 2.2 2.2, 3.3 3.3)"
    end

    @testset "Valid mixed type linestring" begin
        line_x_int = [1, 2, 3]
        line_y_float = [1.1, 2.2, 3.3]
        @test get_line_wkt(line_x_int, line_y_float) == "LINESTRING(1 1.1, 2 2.2, 3 3.3)"
        @test get_line_wkt(line_y_float, line_x_int) == "LINESTRING(1.1 1, 2.2 2, 3.3 3)"
    end

    @testset "Throws when vector lengths do not match" begin
        @test_throws ArgumentError get_line_wkt([1 2 3], [1 2])
    end
end

@testset "Test get_line_wkt(matrix)" begin
    line_x = [1.5, 2.2, 3]
    line_y = [1, 2, 3.3]
    # test get_line_wkt(matrix) function signature
    @testset "Valid matrix with size 3x2" begin
        @test get_line_wkt(hcat(line_x, line_y)) == "LINESTRING(1.5 1.0, 2.2 2.0, 3.0 3.3)"
    end
    @testset "Valid matrix with size 2x3" begin
        @test get_line_wkt(vcat(line_x', line_y')) == "LINESTRING(1.5 1.0, 2.2 2.0, 3.0 3.3)"
    end
    @testset "Throws if matrix has too many dimensions" begin
        @test_throws ArgumentError get_line_wkt(ones(3, 3))
    end
end

@testset "Test merge_lines '[[[x...],[y...]], [[x'...],[y'...]], ...]'" begin
    line_1_x_int = [1, 2, 3, 4] # longest/base line
    line_1_y_int = [1, 2.0, 3, 4] # longest/base line

    # append at the end
    line_2_x_int = [3, 4, 5]
    line_2_y_float = [3.0, 4.0, 5]

    # append in the front
    line_3_x_int = [-1, 0, 1]
    line_3_y_int = [-1, 0, 1]

    # ignore
    """
              /
            /
          /|
        /  |
      /    |
    """
    line_branch_x_int = [3, 3, 3] # closest point falls within the base_line
    line_branch_y_int = [3, 2.5, 2.0] # closest point falls within the base_line

    # TODO - we still need to handle the case where there could be two points that are the same distance apart
    """
              /
            /______
          /
        /
      /
    """
    line_branch_no_solution_x_int = [3, 4, 5] # Hard as there are two closes points (4,4) -> (3,4) and (3,3) -> (3,4)
    line_branch_no_solution_y_int = [3, 3, 3] # Hard as there are two closes points

    expected_result_1 = [[1.0, 2.0, 3.0, 4.0, 5.0], [1.0, 2.0, 3.0, 4.0, 5.0]]
    expected_result_2 = [[-1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0], [-1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0]]
    expected_result_3 = [[1.0, 2.0, 3.0, 4.0], [1.0, 2.0, 3.0, 4.0]]

    @testset "Test basic merge" begin
        @test merge_lines([
            [line_1_x_int, line_1_y_int],
            [line_2_x_int, line_2_y_float]
        ]) == expected_result_1
    end

    @testset "Test sorting of lines by length" begin
        @test merge_lines([
            [line_2_x_int, line_2_y_float],
            [line_1_x_int, line_1_y_int]
        ]) == expected_result_1
    end

    @testset "Test merge same line twice" begin
        @test merge_lines([
            [line_1_x_int, line_1_y_int],
            [line_2_x_int, line_2_y_float],
            [line_1_x_int, line_1_y_int]
        ]) == expected_result_1
    end

    @testset "Test merge to front and aft of longest line" begin
        @test merge_lines([
            [line_1_x_int, line_1_y_int],
            [line_2_x_int, line_2_y_float],
            [line_3_x_int, line_3_y_int]
        ]) == expected_result_2
    end

    @testset "Test reverse order of merge lines" begin
        @test merge_lines([
            [line_1_x_int, line_1_y_int],
            reverse([line_2_x_int, line_2_y_float]),
            reverse([line_3_x_int, line_3_y_int])
        ]) == expected_result_2
    end

    @testset "Test ignore branch" begin
        @test merge_lines([
            [line_1_x_int, line_1_y_int],
            [line_branch_x_int, line_branch_y_int]
        ]) == expected_result_3
    end
    @testset "Throws when branches should not be ignored" begin
        @test_throws ArgumentError merge_lines([
                [line_1_x_int, line_1_y_int],
                [line_branch_x_int, line_branch_y_int]
            ], ignore_branches=false)
    end

    @testset "Ignores when it cannot differentiate between branch or root" begin
        @test merge_lines([
                [line_1_x_int, line_1_y_int],
                [line_branch_no_solution_x_int, line_branch_no_solution_y_int]
            ], ignore_branches=true) == expected_result_3
    end

    @testset "Test large area_ratio_threshold" begin
        @test merge_lines([
                [line_1_x_int, line_1_y_int],
                [line_2_x_int, line_2_y_float]
            ], area_ratio_threshold=2.0) == expected_result_3
    end

    @testset "Test large diff_buffer" begin
        @test merge_lines([
                [line_1_x_int, line_1_y_int],
                [line_2_x_int, line_2_y_float]
            ], line_buffer=2.0) == expected_result_3
    end

    # ignore as there is no intersection
    """
          /    \\
        /       \\
      /          \\
    """
    line_1_no_overlap_x_int = [1, 2, 3]
    line_1_no_overlap_y_int = [1, 2, 3]
    line_2_no_overlap_x_int = [5, 6, 7]
    line_2_no_overlap_y_int = [3, 2, 1]
    expected_result_4 = [[1.0, 2.0, 3.0], [1.0, 2.0, 3.0]]
    @testset "Test lines do not merge when there is no overlap" begin
        @test merge_lines(
            [
                [line_1_no_overlap_x_int, line_1_no_overlap_y_int],
                [line_2_no_overlap_x_int, line_2_no_overlap_y_int]
            ],
            line_buffer=0.1
        ) == expected_result_4
    end

    expected_result_5 = [[1.0, 2.0, 3.0, 5.0, 6.0, 7.0], [1.0, 2.0, 3.0, 3.0, 2.0, 1.0]]
    @testset "Test lines merge when there is no overlap but a large enough buffer" begin
        @test merge_lines(
            [
                [line_1_no_overlap_x_int, line_1_no_overlap_y_int],
                [line_2_no_overlap_x_int, line_2_no_overlap_y_int]
            ],
            line_buffer=1.0 # polygons just touch
        ) == expected_result_5
    end
end

@testset "Test merge_lines '[[[x1,y1],[x2,y2], ...], [[x1', y2'],[x2', y2'],...], ...]'" begin
    line_1_int = [[1 1], [2 2], [3 3], [4 4]] # longest line
    line_2_float = [[3 3], [4 4], [5 5]]
    line_3_int = [[-1 -1], [0 0], [1 1]]

    expected_result_1 = [[1 1], [2 2], [3 3], [4 4], [5 5]]
    expected_result_2 = [[-1 -1], [0 0], [1 1], [2 2], [3 3], [4 4], [5 5]]
    @testset "Test basic merge" begin
        @test merge_lines([line_1_int, line_2_float]) == expected_result_1
    end

    @testset "Test merge to front and aft of longest line" begin
        @test merge_lines([line_1_int, line_2_float, line_3_int]) == expected_result_2
    end
    # coverage for branches is covered in the tests above
end

@testset "Test merge_lines '[dataframe_1, dataframe_2, ...]'" begin
    line_1_x_int = [1, 2, 3, 4] # longest/base line
    line_1_y_int = [1, 2.0, 4, 5] # longest/base line

    # append at the end
    line_2_x_int = [3, 4, 5]
    line_2_y_float = [4.0, 5.0, 6]

    # append in the front
    line_3_x_int = [-1, 0, 1]
    line_3_y_int = [-1, 0, 1]

    line_df_1 = DataFrame(x=line_1_x_int, y=line_1_y_int, z=[1, 1, 1, 1])
    line_df_2 = DataFrame(x=line_2_x_int, y=line_2_y_float, z=[1, 1, 1])
    line_df_3 = DataFrame(x=line_3_x_int, y=line_3_y_int)
    line_df_4 = DataFrame(a=line_1_x_int, b=line_1_y_int, z=[1, 1, 1, 1])
    line_df_5 = DataFrame(a=line_2_x_int, b=line_2_y_float, z=[1, 1, 1])
    line_df_6 = DataFrame(a=line_3_x_int, b=line_3_y_int)

    expected_result_1 = DataFrame(x=[1.0, 2.0, 3.0, 4.0, 5.0], y=[1.0, 2.0, 4.0, 5.0, 6.0])
    expected_result_2 = DataFrame(x=[-1, 0, 1, 2, 3, 4, 5], y=[-1, 0, 1, 2, 4, 5, 6])
    expected_result_3 = DataFrame(a=[-1, 0, 1, 2, 3, 4, 5], b=[-1, 0, 1, 2, 4, 5, 6])
    @testset "Test basic merge" begin
        @test merge_lines([line_df_1, line_df_2], x_column="x", y_column="y") == expected_result_1
    end

    @testset "Test merge to front and aft of longest line" begin
        @test merge_lines([line_df_1, line_df_2, line_df_3], x_column="x", y_column="y") == expected_result_2
    end

    @testset "Test correct column names are returned" begin
        @test merge_lines([line_df_4, line_df_5, line_df_6], x_column="a", y_column="b") == expected_result_3
    end
    # coverage for branches is covered in the tests above
end
