using Pkg

# Get precompile flag from command line arguments
option = ARGS[1]

# If option is ALREADY_BUILT, we are using an already built/downloaded image and Manifest
option == "ALREADY_BUILT" && exit(0)

Pkg.activate(@__DIR__) # Use the Project.toml in this folder
Pkg.develop(path=dirname(@__DIR__)) # Develop the local version of the package we are including in the sysimage
Pkg.instantiate()

using PackageCompiler

@info "OPTION is $option"

if option == "NONE"
    @info "Precompiling system image..."
    create_sysimage([:MapExporter];
        sysimage_path="MapExporter.so",
        precompile_execution_file="deploy/precompile.jl",
        cpu_target="native",
    )
elseif option == "APP"
    cd("..")
    create_app("MapExporter", "MapExporterCompiled", force=true)
end