# TODO: Allow for override capacity

# https://www.atap.gov.au/parameter-values/road-transport/3-travel-time
# NOTE: This is a placeholder designed to match with VOC reference and has been simplified
"""
This is the delay cost scaling for vehicles:

- occ: people/vehicle
- cost: \$/person-hour
- freight: \$/vehicle-hour
"""
const CC_DELAY_REFERENCE = Dict(
    "Private Car" => Dict(:occ_rur => 1.7, :cost_rur => 14.99, :occ_urb => 1.6, :cost_urb => 14.99),
    "Business Car" => Dict(:occ_rur => 1.3, :cost_rur => 48.63, :occ_urb => 1.4, :cost_urb => 48.63),
    "Courier Van-Utility" => Dict(:occ_rur => 1.0, :cost_rur => 25.41, :occ_urb => 1.0, :cost_urb => 25.41),
    "4WD Mid Size Petrol" => Dict(:occ_rur => 1.5, :cost_rur => 25.41, :occ_urb => 1.5, :cost_urb => 25.41),
    "Light Rigid" => Dict(:occ_rur => 1.3, :cost_rur => 25.41, :occ_urb => 1.3, :cost_urb => 25.41, :freight_rur => 0.78, :freight_urb => 1.53),
    "Medium Rigid" => Dict(:occ_rur => 1.2, :cost_rur => 25.72, :occ_urb => 1.3, :cost_urb => 25.72, :freight_rur => 2.11, :freight_urb => 4.15),
    "Heavy Rigid" => Dict(:occ_rur => 1.0, :cost_rur => 26.19, :occ_urb => 1.0, :cost_urb => 26.19, :freight_rur => 7.22, :freight_urb => 14.20),
    "Heavy Bus (driver)" => Dict(:occ_rur => 1.0, :cost_rur => 25.72, :occ_urb => 1.0, :cost_urb => 25.72),
    "Heavy Bus (passenger)" => Dict(:occ_rur => 20.0, :cost_rur => 14.99, :occ_urb => 20.0, :cost_urb => 14.99),
    "Artic 4 Axle" => Dict(:occ_rur => 1.0, :cost_rur => 26.81, :occ_urb => 1.0, :cost_urb => 26.81, :freight_rur => 15.53, :freight_urb => 30.59),
    "Artic 5 Axle" => Dict(:occ_rur => 1.0, :cost_rur => 26.81, :occ_urb => 1.0, :cost_urb => 26.81, :freight_rur => 19.80, :freight_urb => 39.01),
    "Artic 6 Axle" => Dict(:occ_rur => 1.0, :cost_rur => 26.81, :occ_urb => 1.0, :cost_urb => 26.81, :freight_rur => 21.36, :freight_urb => 42.06),
    "Rigid and 5 Axle Dog" => Dict(:occ_rur => 1.0, :cost_rur => 27.20, :occ_urb => 1.0, :cost_urb => 27.20, :freight_rur => 30.53, :freight_urb => 62.99),
    "B-Double" => Dict(:occ_rur => 1.0, :cost_rur => 27.20, :occ_urb => 1.0, :cost_urb => 27.20, :freight_rur => 31.46, :freight_urb => 64.91),
    "Twin steer and 5 Axle Dog" => Dict(:occ_rur => 1.0, :cost_rur => 27.20, :occ_urb => 1.0, :cost_urb => 27.20, :freight_rur => 29.50, :freight_urb => 60.89),
    "A-Double" => Dict(:occ_rur => 1.0, :cost_rur => 27.98, :occ_urb => 1.0, :cost_urb => 27.98, :freight_rur => 41.31, :freight_urb => 85.25),
    "B Triple" => Dict(:occ_rur => 1.0, :cost_rur => 27.98, :occ_urb => 1.0, :cost_urb => 27.98, :freight_rur => 42.17, :freight_urb => 87.01),
    "A B Combination" => Dict(:occ_rur => 1.0, :cost_rur => 27.98, :occ_urb => 1.0, :cost_urb => 27.98, :freight_rur => 50.79, :freight_urb => 104.80),
    "A-Triple" => Dict(:occ_rur => 1.0, :cost_rur => 28.45, :occ_urb => 1.0, :cost_urb => 28.45, :freight_rur => 60.89, :freight_urb => 125.64),
    "Double B-Double" => Dict(:occ_rur => 1.0, :cost_rur => 28.45, :occ_urb => 1.0, :cost_urb => 28.45, :freight_rur => 61.59, :freight_urb => 127.09),
)

# https://www.atap.gov.au/parameter-values/road-transport/5-vehicle-operating-cost-voc-models
"""
This is the vehicle operation cost scaling for vehicles which, when applied, should result in a cost of type:

    - cents/vehicle-km
"""
const CC_VOC_REFERENCE = Dict(
    "Small Car" => Dict(:A => 12.5242, :B => 838.2969, :C0 => 25.7952, :C1 => -0.1253, :C2 => 0.0010),
    "Medium Car" => Dict(:A => 12.6514, :B => 1315.5178, :C0 => 35.0470, :C1 => -0.1751, :C2 => 0.0012),
    "Large Car" => Dict(:A => 14.4297, :B => 1838.4754, :C0 => 46.1765, :C1 => -0.2221, :C2 => 0.0014),
    "Courier Van-Utility" => Dict(:A => 15.9354, :B => 1357.1233, :C0 => 38.4920, :C1 => -0.1840, :C2 => 0.0014),
    "4WD Mid Size Petrol" => Dict(:A => 21.0481, :B => 1328.7944, :C0 => 40.5580, :C1 => -0.1540, :C2 => 0.0013),
    "Light Rigid" => Dict(:A => 33.9697, :B => 1543.5546, :C0 => 51.5092, :C1 => -0.2481, :C2 => 0.0025),
    "Medium Rigid" => Dict(:A => 35.8038, :B => 2259.9048, :C0 => 62.6793, :C1 => -0.3002, :C2 => 0.0026),
    "Heavy Rigid" => Dict(:A => 57.1600, :B => 2556.0769, :C0 => 82.2900, :C1 => -0.5525, :C2 => 0.0053),
    "Heavy Bus" => Dict(:A => 64.5569, :B => 4632.1535, :C0 => 124.7014, :C1 => -0.6467, :C2 => 0.0047),
    "Artic 4 Axle" => Dict(:A => 84.5711, :B => 3323.0102, :C0 => 111.6621, :C1 => -0.7240, :C2 => 0.0072),
    "Artic 5 Axle" => Dict(:A => 91.1303, :B => 3688.6095, :C0 => 119.8994, :C1 => -0.6800, :C2 => 0.0066),
    "Artic 6 Axle" => Dict(:A => 98.6903, :B => 3991.2764, :C0 => 128.6879, :C1 => -0.6878, :C2 => 0.0066),
    "Rigid and 5 Axle Dog" => Dict(:A => 122.5511, :B => 3729.8458, :C0 => 136.1620, :C1 => -0.6403, :C2 => 0.0065),
    "B-Double" => Dict(:A => 122.9920, :B => 4592.1836, :C0 => 151.4716, :C1 => -0.7228, :C2 => 0.0068),
    "Twin steer and 5 Axle Dog" => Dict(:A => 127.1973, :B => 4379.9716, :C0 => 149.9310, :C1 => -0.6911, :C2 => 0.0067),
    "A-Double" => Dict(:A => 143.9930, :B => 5692.0036, :C0 => 183.5354, :C1 => -0.8330, :C2 => 0.0074),
    "B Triple" => Dict(:A => 149.4138, :B => 7134.4573, :C0 => 214.1429, :C1 => -0.9878, :C2 => 0.0081),
    "A B Combination" => Dict(:A => 170.3213, :B => 6257.8473, :C0 => 208.7075, :C1 => -0.9017, :C2 => 0.0080),
    "A-Triple" => Dict(:A => 190.6482, :B => 7134.9278, :C0 => 237.0682, :C1 => -1.0131, :C2 => 0.0086),
    "Double B-Double" => Dict(:A => 199.5704, :B => 6976.3148, :C0 => 238.7248, :C1 => -0.9882, :C2 => 0.0086),
)

const CC_VOC_PROP_VEHICLES = Dict(
    "Small Car" => 26.9,
    "Medium Car" => 26.9,
    "Large Car" => 26.9,
    "Courier Van-Utility" => 15.68,
    "4WD Mid Size Petrol" => 0.0,
    "Light Rigid" => 0.89,
    "Medium Rigid" => 0.83,
    "Heavy Rigid" => 0.70,
    "Heavy Bus" => 0.42,
    "Artic 4 Axle" => 0.05,
    "Artic 5 Axle" => 0.05,
    "Artic 6 Axle" => 0.05,
    "Rigid and 5 Axle Dog" => 0.05,
    "B-Double" => 0.21,
    "Twin steer and 5 Axle Dog" => 0.38,
    "A-Double" => 0.00,
    "B Triple" => 0.00,
    "A B Combination" => 0.00,
    "A-Triple" => 0.00,
    "Double B-Double" => 0.00,
)

const CC_DELAY_PROP_VEHICLES = Dict(
    "Private Car" => 50.03,
    "Business Car" => 30.66,
    "Courier Van-Utility" => 15.68,
    "4WD Mid Size Petrol" => 0.00,
    "Light Rigid" => 0.89,
    "Medium Rigid" => 0.83,
    "Heavy Rigid" => 0.70,
    "Heavy Bus (driver)" => 0.42,
    "Heavy Bus (passenger)" => 0.42,
    "Artic 4 Axle" => 0.05,
    "Artic 5 Axle" => 0.05,
    "Artic 6 Axle" => 0.05,
    "Rigid and 5 Axle Dog" => 0.05,
    "B-Double" => 0.21,
    "Twin steer and 5 Axle Dog" => 0.38,
    "A-Double" => 0.00,
    "B Triple" => 0.00,
    "A B Combination" => 0.00,
    "A-Triple" => 0.00,
    "Double B-Double" => 0.00,
)

const CC_VOC_ORDER = [
    "Small Car",
    "Medium Car",
    "Large Car",
    "Courier Van-Utility",
    "4WD Mid Size Petrol",
    "Light Rigid",
    "Medium Rigid",
    "Heavy Rigid",
    "Heavy Bus",
    "Artic 4 Axle",
    "Artic 5 Axle",
    "Artic 6 Axle",
    "Rigid and 5 Axle Dog",
    "B-Double",
    "Twin steer and 5 Axle Dog",
    "A-Double",
    "B Triple",
    "A B Combination",
    "A-Triple",
    "Double B-Double",
]

const CC_DELAY_ORDER = [
    "Private Car",
    "Business Car",
    "Courier Van-Utility",
    "4WD Mid Size Petrol",
    "Light Rigid",
    "Medium Rigid",
    "Heavy Rigid",
    "Heavy Bus (driver)",
    "Heavy Bus (passenger)",
    "Artic 4 Axle",
    "Artic 5 Axle",
    "Artic 6 Axle",
    "Rigid and 5 Axle Dog",
    "B-Double",
    "Twin steer and 5 Axle Dog",
    "A-Double",
    "B Triple",
    "A B Combination",
    "A-Triple",
    "Double B-Double",
]

const CC_VOC_CATEGORY = Dict(
    "Small Car" => :passenger,
    "Medium Car" => :passenger,
    "Large Car" => :passenger,
    "Courier Van-Utility" => :commercial,
    "4WD Mid Size Petrol" => :passenger,
    "Light Rigid" => :commercial,
    "Medium Rigid" => :commercial,
    "Heavy Rigid" => :commercial,
    "Heavy Bus" => :commercial,
    "Artic 4 Axle" => :commercial,
    "Artic 5 Axle" => :commercial,
    "Artic 6 Axle" => :commercial,
    "Rigid and 5 Axle Dog" => :commercial,
    "B-Double" => :commercial,
    "Twin steer and 5 Axle Dog" => :commercial,
    "A-Double" => :commercial,
    "B Triple" => :commercial,
    "A B Combination" => :commercial,
    "A-Triple" => :commercial,
    "Double B-Double" => :commercial,
)

const CC_DELAY_CATEGORY = Dict(
    "Private Car" => nothing,
    "Business Car" => nothing,
    "Courier Van-Utility" => nothing,
    "4WD Mid-Size Petrol" => nothing,
    "Light Rigid" => nothing,
    "Medium Rigid" => nothing,
    "Heavy Rigid" => nothing,
    "Heavy Bus (driver)" => nothing,
    "Heavy Bus (passenger)" => nothing,
    "Artic 4 Axle" => nothing,
    "Artic 5 Axle" => nothing,
    "Artic 6 Axle" => nothing,
    "Rigid and 5 Axle Dog" => nothing,
    "B-Double" => nothing,
    "Twin steer and 5 Axle Dog" => nothing,
    "A-Double" => nothing,
    "B Triple" => nothing,
    "A B Combination" => nothing,
    "A-Triple" => nothing,
    "Double B-Double" => nothing,
)

const CC_PROP_VEHICLES_MAPPING = Dict(
    :delay => CC_DELAY_PROP_VEHICLES,
    :voc => CC_VOC_PROP_VEHICLES
)

const CC_ORDER_MAPPING = Dict(
    :delay => CC_DELAY_ORDER,
    :voc => CC_VOC_ORDER
)


# TODO: Allow regeneration of Vehicle vectors and constants for economic modelling of network
const DOLLAR_VEHICLE_OCCUPANCY = [CC_DELAY_REFERENCE[name][:cost_urb] for name in CC_DELAY_ORDER]  # TODO: Split to urb/rur/freight
const DOLLAR_VEHICLE_TIME = [get(CC_DELAY_REFERENCE[name], :freight_urb, 0.0) for name in CC_DELAY_ORDER]  # TODO: Split to urb/rur/freight
const TOTAL_VEHICLE_OCCUPANCY = [CC_DELAY_REFERENCE[name][:occ_urb] for name in CC_DELAY_ORDER]  # TODO: Split to urb/rur/freight
const COST_TO_VEHICLE_A =  [CC_VOC_REFERENCE[name][:A]  for name in CC_VOC_ORDER]
const COST_TO_VEHICLE_B =  [CC_VOC_REFERENCE[name][:B]  for name in CC_VOC_ORDER]
const COST_TO_VEHICLE_C0 = [CC_VOC_REFERENCE[name][:C0] for name in CC_VOC_ORDER]
const COST_TO_VEHICLE_C1 = [CC_VOC_REFERENCE[name][:C1] for name in CC_VOC_ORDER]
const COST_TO_VEHICLE_C2 = [CC_VOC_REFERENCE[name][:C2] for name in CC_VOC_ORDER]

const CRITICAL_V_FOR_OPERATION_COST = 60.0
const DELTA_T = 300.0 # 5 min in S

const DELAY_INFLATION_MULTIPLIER = 1.253
const VOC_INFLATION_MULITPLIER_PASSENGER = 1.242
const VOC_INFLATION_MULITPLIER_COMMERCIAL = 1.176
const VOC_INFLATION_MULTIPLIER = [CC_VOC_CATEGORY[name] == :passenger ? VOC_INFLATION_MULITPLIER_PASSENGER : VOC_INFLATION_MULITPLIER_COMMERCIAL for name in CC_VOC_ORDER]