# Load packages

using Vann
using ExcelReaders
using DataFrames
using PyPlot
using JLD



function run_operational(opt)

    # Loop over all watersheds

    dir_all = readdir(opt["path_inputs"])

    for dir_cur in dir_all

        try

        # Load data

        date, tair, prec, q_obs, frac = load_data("$(opt["path_inputs"])/$dir_cur")

        # Compute potential evapotranspiration

        epot = eval(Expr(:call, opt["epot_choice"], date))

        # Load initial states

        tmp = load(joinpath(opt["path_calib"], "model_data", replace(dir_cur, "data", "modeldata.jld")))

        st_snow = tmp["st_snow"]
        st_hydro = tmp["st_hydro"]

        # Run model

        q_res = eval(Expr(:call, opt["filter_choice"], st_snow, st_hydro, prec, tair, epot, q_obs, opt["nens"]))





        # Add results to dataframe

        q_obs = round(q_obs, 2)
        q_sim = round(q_res[:, 1], 2)
        q_min = round(q_res[:, 2], 2)
        q_max = round(q_res[:, 3], 2)

        df_res = DataFrame(date = date, q_obs = q_obs, q_sim = q_sim, q_min = q_min, q_max = q_max)

        # Save results to txt file

        file_name = joinpath(opt["path_save"], "tables", dir_cur[1:end-5] * "_station.txt")

        writetable(file_name, df_res, quotemark = '"', separator = '\t')

        
        # Plot results for forecast period

        disp_period = 70

        fig = plt[:figure](figsize = (12,7))

        plt[:style][:use]("ggplot")
        
        plt[:axvline](x=now(), color = "r", linestyle = "dashed")
        plt[:plot](date[end-disp_period:end], q_obs[end-disp_period:end], linewidth = 1.2, color = "k", label = "Observed", zorder = 1)
        plt[:fill_between](date[end-disp_period:end], q_max[end-disp_period:end], q_min[end-disp_period:end], facecolor = "b", edgecolor = "b", label = "Simulated", alpha = 0.55, zorder = 2)
        plt[:ylabel]("Runoff (mm/day)")

        plt[:legend]()
        
        file_name = joinpath(opt["path_save"], "figures", dir_cur[1:end-5] * "_forecast.png")
        
        savefig(file_name, dpi = 600)
        close(fig)

        catch

            info("Unable to run for station $(replace(dir_cur, "_data", ""))\n")

        end

    end

end



# Settings

opt = Dict("epot_choice" => :oudin,
           "path_inputs" => "/hdata/fou/jmg/flood_forecasting/model_input",
           "path_save" =>   "/hdata/fou/jmg/flood_forecasting/model_input",
           "path_calib" =>  "/hdata/fou/jmg/flood_forecasting/model_input")

# Create folders for saving results

opt["path_save"] = joinpath(opt["path_save"], Dates.format(now(), "yyyymmddHHMM"))

mkpath(opt["path_save"] * "/tables")
mkpath(opt["path_save"] * "/figures")

# Run over all stations

# Run operational

run_operational(opt)

