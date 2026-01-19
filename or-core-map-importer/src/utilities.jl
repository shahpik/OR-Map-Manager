todays_date() = replace(string(today()), "-" => "")

function snake_to_camel(str::String)
    words = split(str, "_")
    camel_list = [idx != 1 ? titlecase(words[idx]) : lowercase(words[idx]) for idx in eachindex(words)]

    return join(camel_list)
end
snake_to_camel(str) = snake_to_camel(string(str))
