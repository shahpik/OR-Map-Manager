insert into map_manager.mm_custom_attribute (layer_id, s_name, ar_s_options, e_custom_attribute_type)
select 
    layer_id,
    s_name, 
    case when ar_s_options is not null then array[ar_s_options]
    else NULL
    end as ar_s_optison,
    e_custom_attribute_type
from map_manager.stg_custom_attribute
on conflict do nothing
;