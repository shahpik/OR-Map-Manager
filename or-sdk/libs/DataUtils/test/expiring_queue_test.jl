
@testset "expiring queue test" begin
    # TimedInt tests
    tq = Queue{TimedInt}()
    for i in 1:1000
        enqueue!(tq, TimedInt(i, i*2))
    end
    @test length(tq) == 1000
    expire_elements_by_ts!(tq, 500)
    @test length(tq) == 501
    @test first(tq) == TimedInt(500, 1000)
    # last(tq)
    @test DataUtils.queue_val_sum(tq)== sum(collect(500:1000)*2)  # values are 2x in test data
    @test DataUtils.queue_val_sum(tq)== sum(collect(500:1000)*2)  # values are 2x in test data

    expire_elements_by_ts!(tq, 1001)
    @test isempty(tq) == true
    expire_elements_by_ts!(tq, 0)  # run it again to ensure it works on empty queues
    @test isempty(tq) == true
    
    for i in 1:1000
        enqueue!(tq, TimedInt(i, i*2))
    end
    @test expiring_count!(tq, 500) == 501
    @test expiring_avg!(tq, 500) == sum(collect(500:1000)*2) / 501  # 501 elements
    @test expiring_sum!(tq, 500) == sum(collect(500:1000)*2)
    @test length(tq) == 501
    @test first(tq).val == 1000
    @test first(tq).ts == 500
    
    add_now!(tq, 1)
    @test last(tq).ts <= floor(Int, time()) 
    @test last(tq).val == 1
    # @error add_now!(tq, 0.2)  # this should fail/will generate error log if run

    
    # TimedFloat tests
    tqf = Queue{TimedFloat}()
    for i in 1:1000
        enqueue!(tqf, TimedFloat(i, i*1.1))
    end
    @test first(tqf).val == 1.1
    @test last(tqf).val == 1100.0
    @test expiring_sum!(tqf, 990) == sum(collect(990:1000).*1.1)
    @test expiring_avg!(tqf, 995) == (sum(collect(995:1000).*1.1) / length(tqf))
    @test expiring_avg!(tqf, 1001) == 0.0  # if empty, return 0
    @test expiring_count!(tqf) == 0 
    
    add_now!(tqf, 0.1)
    add_now!(tqf, 0.2)
    @test length(tqf) == 2 
    @test first(tqf).val == 0.1
    
end


@testset "Expiring queue - using real time" begin
    tq = Queue{TimedInt}()
    for i in 1:1000
        enqueue!(tq, TimedInt(floor(Int, time()) - 500 + i, i))  # put half in the past
    end
    @test first(tq).ts < floor(Int, time())
    @test last(tq).ts > floor(Int, time())
    expire_elements_by_ts!(tq, floor(Int, time()))
    @test expiring_count!(tq) <= 501  # should be less than 501 remaining
    # 501 due to current time not expiring, if this runs in less than 1 sec (should be expected)
    expire_elements_by_ts!(tq, floor(Int, time()) + 501)
    @test isempty(tq) == true
    
    for i in 1:1000
        enqueue!(tq, TimedInt(floor(Int, time()) - 500 + i, i))  # put half in the past
    end
    @test expiring_sum!(tq) == sum(collect(500:1000))
    sleep(1)
    @test expiring_sum!(tq) == sum(collect(501:1000))  # 1 sec later should have 1 less val
end
