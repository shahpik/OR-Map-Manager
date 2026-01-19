#######################################################
### App that creates a configuration, subscribes to ###
### its results and then uses the results.          ###
#######################################################
using EMInterface

"""
    is_app1_finished(config)

Example function to get application data for app we are depending on and then
example to do something with it to check that it is finished.
"""
function is_app1_finished(config)
    # Do something with config, typically checking app data of required apps
    app_data = get_app_data(config, "APP_1")
    # Do something with app_data to check that app 1 has finished doing what we need it to do
    return !isempty(app_data.resultIds)
end

"""
    subscribe_to_app1(config)

Subscribe to app 1, checking the result of the subscription each time data is recieved.
"""
function subscribe_to_app1(config)
    subscribe_to_config(config.experimentName, "APP_1", application_output_fields=["name", "resultIds"]) do config_object
        Workers.@async do_something(config_object)
        is_app1_finished(config_object)
    end
    # We get here when is_app1_finished returns true
end

"""
    get_config_for_app(experiment_name)

Choose fields to query Expriment Manager interface for. We do this so we don't
unnecessarily query every field.
"""
function get_config_for_app(experiment_name)
    required_fields = ["experimentName", "simStartTime"]
    return get_configuration(experiment_name, output_fields=required_fields)
end

"""
    execute_app(experiment_name::String)
    execute_app(config::EMInterface.AbstractConfig)

Executes the app functionality. If `experiment_name` supplied, the config
is retrieved from the Experiment Manager by `get_config_for_app`.
"""
function execute_app(experiment_name::String)
    @info "Executing app with experiment $experiment_name"
    config = get_config_for_app(experiment_name)
    return execute_app(config)
end
function execute_app(config::EMInterface.AbstractConfig)
    if !is_app1_finished(config)
        # If apps that we rely on are not finished, subscribe to them until they are
        subscribe_to_app1(config)
    end

    data = load_data(config) # Placeholder
    result = use_data(data) # Placeholder
    save_result(result) # Placeholder

    # Update app data to indicate that it's finished
    update_app_data(experiment_name, "MY_APP", result_ids="1")
    return
end