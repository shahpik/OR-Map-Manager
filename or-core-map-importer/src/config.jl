"""
    load_config()

Takes a config file location (local for now) and produces a configuration file as per a ConfigStruct.
Config structs are defined in config_struct.
"""
function load_source_config(;path="../config/config.yaml")
    config_dir =  joinpath(@__DIR__, path)
    config_data = YAML.load_file(config_dir, dicttype=Dict{Symbol,Any})

    config_list = Dict{Symbol, SourceConfig}()
    for (source_name, source_data) in config_data
        # Load dict into a SourceConfig struct
        local source_config::SourceConfig
        try
            source_config = StructTypes.constructfrom(SourceConfig, source_data)
        catch
            @warn "Failed to load config for $source_name, check that the config has all required fields! Error details below:"
            rethrow()
        end

        source_config.name = source_name

        # Add env vars to headers
        if !isnothing(source_config.download_rest_config)
            for (k, v) in source_config.download_rest_config.headers
                #=
                Search for a string that starts with "{" and ends with "}", then return 
                the text between the brackets if found.
                - (?<=): Lookbehind. Match should occur after something matching this.
                  - ^: Start of string.
                  - {: Match this text for the lookbehind.
                - .*: Any character, any number of times. This is the matched string.
                - (?<=): Lookahead. Match should occur before something matching this.
                  - }: Match this text for the lookahead.
                  - $: End of string.
                =#
                m = match(r"(?<=^{).*(?=}$)", v)
                isnothing(m) && continue

                if !haskey(ENV, m.match)
                    @warn "Environment variable $(m.match) not found!"
                    continue
                end
                source_config.download_rest_config.headers[k] = ENV[m.match]
            end
        end

        config_list[source_name] = source_config
    end
    return config_list
end
