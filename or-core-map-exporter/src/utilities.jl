todays_date() = replace(string(today()), "-" => "")

function snake_to_camel(str::String)
    words = split(str, "_")
    camel_list = [idx != 1 ? titlecase(words[idx]) : lowercase(words[idx]) for idx in eachindex(words)]

    return join(camel_list)
end
snake_to_camel(str) = snake_to_camel(string(str))

function get_exporter_file_name()
    # Extracting current year, month, and day
    melbourne_time = now(tz"Australia/Melbourne")
    year = Dates.year(melbourne_time)
    month = Dates.month(melbourne_time)
    day = Dates.day(melbourne_time)
    
    # Format the file name as "YYYY/MM/DD/osm_export.json"
    return "$year/$(lpad(month, 2, '0'))/$(lpad(day, 2, '0'))/dtp_osm_road_network.json"
end
