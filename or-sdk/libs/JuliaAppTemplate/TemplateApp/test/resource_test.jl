@testset "Basic endpoints" begin
    # Live endoint
    live_req = HTTP.Request("GET","/live")
    resp = JuliaAppTemplate.Resource.requestHandler(live_req)
    @test resp isa HTTP.Response
    @test resp.status == 200
    @test String(resp.body) == "OK"

    # Ready endoint
    ready_req = HTTP.Request("GET","/ready")
    resp = JuliaAppTemplate.Resource.requestHandler(ready_req)
    @test resp isa HTTP.Response
    @test resp.status == 200 || resp.status == 503 # OK or not ready

    # Non existent endpoint
    non_existent_req = HTTP.Request("GET","/non_existent")
    resp = JuliaAppTemplate.Resource.requestHandler(non_existent_req)
    @test resp isa HTTP.Response
    @test resp.status == 404
end

@testset "format_response" begin
    # HTTP.response
    resp = HTTP.Response()
    @test JuliaAppTemplate.Resource.format_response(resp) == resp

    # Exception
    msg = "My Error"
    err = ArgumentError(msg)
    resp = JuliaAppTemplate.Resource.format_response(err)
    @test resp.status == 400
    @test String(resp.body) == string(err)

    # Response with no code
    str = "Done"
    resp = JuliaAppTemplate.Resource.format_response(str)
    @test resp.status == 200
    @test String(resp.body) == str
    dict = Dict("result" => "Done")
    resp = JuliaAppTemplate.Resource.format_response(dict)
    @test resp.status == 200
    @test String(resp.body) == """{"result":"Done"}"""

    # Response with code
    str = "Done"
    code = 401
    resp = JuliaAppTemplate.Resource.format_response((code, str))
    @test resp.status == code
    @test String(resp.body) == str
    dict = Dict("result" => "Done")
    resp = JuliaAppTemplate.Resource.format_response((code, dict))
    @test resp.status == code
    @test String(resp.body) == """{"result":"Done"}"""
end
