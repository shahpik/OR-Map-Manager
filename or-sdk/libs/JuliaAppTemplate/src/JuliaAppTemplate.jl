module JuliaAppTemplate

using TOML
using Unicode
using UUIDs

"""
    generate(name, port; location=pwd(), force=false)

Generate a new skeleton for a microservice.

See the README for full description of what the skeleton contains.

# Arguments
- `name`: app name in UpperCamelCase.
- `port`: port which app will run on (can be string or integer).
- `location=pwd()`: location to put app skeleton.
- `force=false`: set to true to overwrite new app location.
- `workers=:simple`: set to `:complex` to include `Workers.@threads`
    functionality with three thread groups, and to `:single` to only
    include `Workers.@async`.
"""
function generate(name, port; location=pwd(), force=false, workers=:simple)
    # Copy file
    new_app_dir = joinpath(location, name)
    @info "Creating app at $new_app_dir"
    template_dir = joinpath(dirname(@__DIR__), "TemplateApp")
    cp(template_dir, new_app_dir, force=force)
    chmod(new_app_dir, 0o755, recursive=true)

    # Pick workers file
    choose_workers_option(new_app_dir, workers)

    # Do regex of name and port
    files_with_port = ["docker-compose.yaml", r"Dockerfile", "Resource.jl", r"(values).*(.yaml)"]
    for (root, dirs, files) in walkdir(new_app_dir)
        sub_dir = relpath(root, new_app_dir)
        for file in files
            filepath = joinpath(root, file)
            txt = read(filepath, String)
            txt = replace(txt, "JuliaAppTemplate" => name)
            txt = replace(txt, "julia-template-app" => get_kebab_case(name))
            txt = replace(txt, "JULIA_TEMPLATE_APP" => get_caps_separated(name))
            txt = replace(txt, "#juliaapptemplate" => "#$(lowercase(name))")
            if any(occursin.(files_with_port, Ref(file)))
                # Only regex in certain files for port, in case the number is elswhere
                txt = replace(txt, "5082" => port)
            end
            open(filepath, "w") do f
                write(f, txt)
            end
        end
    end

    # Rename source
    mv(joinpath(new_app_dir, "src", "JuliaAppTemplate.jl"), joinpath(new_app_dir, "src", "$name.jl"), force=force)

    # Generate UUID and set everywhere
    new_uuid = string(UUIDs.uuid4())

    # Main Project.toml
    update_project_uuid(new_app_dir, new_uuid)

    # Deploy Project.toml
    update_deploy_uuid(new_app_dir, name, new_uuid)
    
    # Docs Project.toml
    update_docs_uuid(new_app_dir, name, new_uuid)

    append_version_to_readme(new_app_dir)

    @info "Finished. Enjoy your new app!"
end

"""
    generate_library(name; location=pwd(), force=false)

Generate a new skeleton for a Julia library.

See the README for full description of what the skeleton contains.

# Arguments
- `name`: lib name in UpperCamelCase.
- `location=pwd()`: location to put lib skeleton.
- `force=false`: set to true to overwrite new lib location.
"""
function generate_library(name; location=pwd(), force=false)
    # Copy file
    new_lib_dir = joinpath(location, name)
    @info "Creating lib at $new_lib_dir"
    template_dir = joinpath(dirname(@__DIR__), "TemplateLibrary")
    cp(template_dir, new_lib_dir, force=force)
    chmod(new_lib_dir, 0o755, recursive=true)

    # Do regex of name 
    for (root, dirs, files) in walkdir(new_lib_dir)
        sub_dir = relpath(root, new_lib_dir)
        for file in files
            filepath = joinpath(root, file)
            txt = read(filepath, String)
            txt = replace(txt, "JuliaLibraryTemplate" => name)
            txt = replace(txt, "#julialibrarytemplate" => "#$(lowercase(name))")
            open(filepath, "w") do f
                write(f, txt)
            end
        end
    end

    # Rename source
    mv(joinpath(new_lib_dir, "src", "JuliaLibraryTemplate.jl"), joinpath(new_lib_dir, "src", "$name.jl"), force=force)

    # Generate UUID and set everywhere
    new_uuid = string(UUIDs.uuid4())

    # Main Project.toml
    update_project_uuid(new_lib_dir, new_uuid)
    
    # Docs Project.toml
    update_docs_uuid(new_lib_dir, name, new_uuid)

    append_version_to_readme(new_lib_dir)

    @info "Finished. Enjoy your new library!"
end

"""
    get_kebab_case(name)

Converts UpperCamelCase to snake-case.
"""
function get_kebab_case(name)
    capitals = findall(map(x -> isuppercase(x), collect(name)))
    deleteat!(capitals, 1)
    chars = collect(name)
    for i in reverse(capitals)
        insert!(chars, i, '-')
    end
    return lowercase(join(chars))
end

"""
    get_caps_separated(name)

Converts UpperCamelCase to CAPS_SEPARATED_CASE.
"""
function get_caps_separated(name)
    capitals = findall(map(x -> isuppercase(x), collect(name)))
    deleteat!(capitals, 1)
    chars = collect(name)
    for i in reverse(capitals)
        insert!(chars, i, '_')
    end
    return uppercase(join(chars))
end

function append_version_to_readme(new_app_dir)
    readme = joinpath(new_app_dir, "README.md")
    template_project_toml = TOML.parsefile(joinpath(dirname(@__DIR__), "Project.toml"))
    template_version = template_project_toml["version"]
    open(readme, "a") do file
        write(file, "\n\nThis application generated with or-sdk JuliaAppTemplate v$template_version")
    end
end

function update_project_uuid(dir, new_uuid)
    project_toml_file = joinpath(dir, "Project.toml")
    project_toml = TOML.parsefile(project_toml_file)
    project_toml["uuid"] = new_uuid
    open(project_toml_file, "w") do io
        TOML.print(io, project_toml)
    end
end

function update_docs_uuid(dir, name, new_uuid)
    docs_toml_file = joinpath(dir, "docs", "Project.toml")
    docs_toml = TOML.parsefile(docs_toml_file)
    docs_toml["deps"][name] = new_uuid
    open(docs_toml_file, "w") do io
        TOML.print(io, docs_toml)
    end
end

function update_deploy_uuid(dir, name, new_uuid)
    deploy_toml_file = joinpath(dir, "deploy", "Project.toml")
    deploy_toml = TOML.parsefile(deploy_toml_file)
    deploy_toml["deps"][name] = new_uuid
    open(deploy_toml_file, "w") do io
        TOML.print(io, deploy_toml)
    end
end

"""
    choose_workers_option(new_app_dir, workers)

Sets up JuliaAppTemplate to use the simple or complex worker files.

Simple only has `Workers.@async`, complex additionally has `Workers.@threads`.
Because `Workers.@threads` requires `ThreadPools.jl`, the `Project.toml` must
also be updated.
"""
function choose_workers_option(new_app_dir, workers)
    if !(workers in (:simple, :complex))
        throw(ArgumentError("workers option must be either :simple or :complex"))
    end

    # Setup filepaths
    simple_workers_file = joinpath(new_app_dir, "src", "Workers_simple.jl")
    simple_toml_file = joinpath(new_app_dir, "Project_simple_workers.toml")
    complex_workers_file = joinpath(new_app_dir, "src", "Workers_complex.jl")
    complex_toml_file = joinpath(new_app_dir, "Project_complex_workers.toml")
    workers_file = joinpath(new_app_dir, "src", "Workers.jl")
    toml_file = joinpath(new_app_dir, "Project.toml")

    # Copy files to final location
    if workers == :simple
        cp(simple_workers_file, workers_file)
        cp(simple_toml_file, toml_file)
    else
        cp(complex_workers_file, workers_file)
        cp(complex_toml_file, toml_file)
    end

    # Remove file options
    rm(simple_workers_file)
    rm(simple_toml_file)
    rm(complex_workers_file)
    rm(complex_toml_file)
    return
end

end # module