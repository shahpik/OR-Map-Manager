using Pkg

# Get precompile flag from command line arguments
option = ARGS[1]

# If option is ALREADY_BUILT, we are using an already built/downloaded image and Manifest
option == "ALREADY_BUILT" && exit(0)

# When in package compile, these keys prevent an error from AWS handled for "No Credentials"
# These keys just need to match the structure of an Access key id and Secret access key
ENV["AWS_ACCESS_KEY_ID"]="AKIAEXAMPLEKEYINHERE"
ENV["AWS_SECRET_ACCESS_KEY"]="example/of/a/secret/access/key/in/here/1"

Pkg.activate(@__DIR__) # Use the Project.toml in this folder
Pkg.develop(path=dirname(@__DIR__)) # Develop the local version of the package we are including in the sysimage
Pkg.instantiate()

using PackageCompiler

@info "OPTION is $option"

if option == "NONE"
    @info "Precompiling system image..."
    @info pwd()
    @info readdir()
    create_sysimage([:MapImporter];
        sysimage_path="MapImporter.so",
        precompile_execution_file=joinpath(@__DIR__, "precompile.jl"),
    )
elseif option == "APP"
    cd("..")
    create_app("MapImporter", "MapImporterCompiled", force=true)
end