# Update an existing dataset

using NveData
using DataFrames

save_folder = "/hdata/fou/jmg/flood_forecasting/model_input"

stat_list = readdir(save_folder)
stat_list = [replace(x, "_data", "") for x in stat_list]
stat_list = [replace(x, "_", ".") for x in stat_list]

@time update_dataset(stat_list, save_folder)
