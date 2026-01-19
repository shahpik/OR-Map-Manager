using Documenter
using JedisCluster

makedocs(
    sitename="JedisCluster.jl Documentation",
    # format = Documenter.HTML(prettyurls = false),
    pages=[
        "Home" => "index.md",
        "Client" => "client.md",
        "Commands" => "commands.md",
        "Pipelining" => "pipeline.md",
        "Pub/Sub" => "pubsub.md",
        "Locks" => "lock.md"
    ],
    modules=[JedisCluster]
)

deploydocs(
    repo="github.com/captchanjack/JedisCluster.jl.git",
    devbranch="main",
    devurl="docs"
)