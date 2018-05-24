# Load packages

using VannModels
using CSV
using DataFrames
using PyPlot
using JLD


""" Run seasonal forecast. """
function run_season(model, date, tair, prec, epot, ndays)
    
    # Time period for seasonal forecast

    date_season = (date[end] + Dates.Day(1)):(date[end] + Dates.Day(ndays+1))

    # Start month and day of forecast period

    month = Dates.month(date_season[1])
    
    day = Dates.day(date_season[1])

    # Unique year in historic period (skip first and last)
    
    year_unique = unique(Dates.year.(date))
    
    year_unique = year_unique[2:end-1]

    # Loop over historic years
    
    df = DataFrame(Time = date_season)

    for year in year_unique
    
        # Find period in historic data
    
        date_start = DateTime(year, month, day)
        date_stop  = date_start + Dates.Day(ndays)
        
        # Crop data
        
        istart = find(date .== date_start)
        istop = find(date .== date_stop)
        
        tair_cropped = tair[:, istart[1]:istop[1]]
        prec_cropped = prec[:, istart[1]:istop[1]]
        epot_cropped = epot[istart[1]:istop[1]]
    
        # Create input object
        
        input = InputPTE(prec_cropped, tair_cropped, epot_cropped)
    
        # Run season forecast
    
        model_tmp = deepcopy(model)
    
        q_sim = run_model(model_tmp, input)

        q_sim = round.(q_sim, 2)

        df[Symbol(year)] = q_sim
        
    end

    return df

end





""" Run forecast for selected model """
function run_operational(opt_path, opt_model, forecast_issued; plot_res = true)

    # Create folders for saving results

    path_save = joinpath(opt_path["path_save"], forecast_issued, string(opt_model["model_choice"]))

    mkpath(joinpath(path_save, "tables_short_forecast"))
    mkpath(joinpath(path_save, "tables_season_forecast"))
    mkpath(joinpath(path_save, "figures_short_forecast"))

    # Loop over all watersheds

    dir_all = readdir(opt_path["path_inputs"])

    for dir_cur in dir_all

        try

            # Print progress

            stat_name = dir_cur[1:end-5]

            println("  Running $(stat_name)")

            # Load data

            path = joinpath(opt_path["path_inputs"], dir_cur)
            
            date, tair, prec, q_obs, frac_lus, frac_area, elev = load_data(path)
                        
            # Compute potential evapotranspiration
        
            lat = 60.0   # TODO: Read latitude in NveData, and read in load_data
            
            epot = oudin(date, tair, lat, frac_area)

            # Initilize input object

            input = InputPTE(date, prec, tair, epot)

            # Load initial states
            
            file_name = joinpath(opt_path["path_calib"], string(opt_model["model_choice"]), "model_data", "$(stat_name)_modelobj.jld")
            
            tmp = load(file_name)
          
            model = tmp["model"]

            # Run model

            init_states!(model, date[1])   # THIS MIGHT BE WRONG
            
            q_sim = run_model(model, input)

            # Add results to dataframe

            q_obs = round.(q_obs, 2)
            q_sim = round.(q_sim, 2)

            df_res = DataFrame(date = date, q_obs = q_obs, q_sim = q_sim)

            df_res = df_res[end-100:end,:]

            # Save results to txt file

            file_name = joinpath(path_save, "tables_short_forecast", "$(stat_name)_data.txt")

            CSV.write(file_name, df_res, quotechar = '"', delim = '\t', dateformat = "yyyy-mm-ddTHH:MM:SS")
            
            # Plot results for forecast period

            if plot_res

                ioff()

                disp_period = 70

                fig = plt[:figure](figsize = (8, 6))

                plt[:style][:use]("ggplot")
                
                plt[:axvline](x = now(), color = "r", linestyle = "dashed")
                plt[:plot](date[end-disp_period:end], q_obs[end-disp_period:end], linewidth = 1.2, color = "k", label = "Observed")
                plt[:plot](date[end-disp_period:end], q_sim[end-disp_period:end], linewidth = 1.2, color = "r", label = "Simulated")
                plt[:ylabel]("Runoff (mm/day)")

                plt[:legend]()
                
                file_name = joinpath(path_save, "figures_short_forecast", "$(stat_name)_data.png")
                            
                savefig(file_name, dpi = 100)
                
                close(fig)

            end

            # # Run seasonal forecast

            # df_season = run_season(model, date, tair, prec, epot, opt_model["ndays"])

            # file_name = joinpath(path_save, "tables_season_forecast", "$(stat_name)_data.txt")
            
            # writetable(file_name, df_season, quotemark = '"', separator = '\t')

        catch

            stat_name = dir_cur[1:end-5]

            info("Failed to run station $(stat_name)\n")

        end

    end

end



tic()

# Update input data

println("Update input datasets")

include("update_dataset.jl")

# Time for issuing the forecast

forecast_issued = Dates.format(now(), "yyyymmddHHMM")

# Options for paths

opt_path = Dict("path_inputs" =>  "/hdata/fou/jmg/flood_forecasting/model_input",
                "path_save" =>    "/hdata/fou/jmg/flood_forecasting/res_forecast",
                "path_calib" =>   "/hdata/fou/jmg/flood_forecasting/model_calib")

# Run for gr4j

opt_model = Dict("epot_choice" => :oudin,
                 "model_choice" => :model_gr4j,
                 "ndays" => 100)

println("Running model $(opt_model["model_choice"])")

@time run_operational(opt_path, opt_model, forecast_issued, plot_res = false)

# Run for hbv_light

opt_model = Dict("epot_choice" => :oudin,
                 "model_choice" => :model_hbv_light,
                 "ndays" => 100)

println("Running model $(opt_model["model_choice"])")

@time run_operational(opt_path, opt_model, forecast_issued, plot_res = false)

toc()