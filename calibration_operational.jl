
# Load packages

using VannModels
using PyPlot
using DataFrames
using JLD
using CSV
using ProgressMeter


# Calibrate all stations for one experiment

function calib_all_stations(opt)

    # Create folders for saving results
    
    mkpath(joinpath(opt["path_save"], string(opt["model_choice"]), "figures"))
    mkpath(joinpath(opt["path_save"], string(opt["model_choice"]), "tables"))
    mkpath(joinpath(opt["path_save"], string(opt["model_choice"]), "model_data"))
    
    # Empty dataframes for summary statistics

    df_calib = DataFrame(Station = String[], NSE = Float64[], KGE = Float64[])

    # Loop over all watersheds

    dir_all = readdir(opt["path_inputs"])
    
    @showprogress 1 "Calibrating $(opt["model_choice"])..." for dir_cur in dir_all

        # Load data

        date, tair, prec, q_obs, frac_lus, frac_area, elev = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

        try
            
            path = joinpath(opt["path_inputs"], dir_cur)

            date, tair, prec, q_obs, frac_lus, frac_area, elev = load_data(path)
            
        catch

            info("Unable to read files in directory $(dir_cur)\n")
            continue

        end

        # Compute potential evapotranspiration
        
        lat = 60.0   # TODO: Read latitude in NveData, and read in load_data
        
        epot = oudin(date, tair, lat, frac_area)

        # Rough precipitation correction step   TODO: This will not be consistent with the calibrated pcorr

        #= if sum(~isnan.(q_obs)) > (3*365)

            ikeep = .~isnan.(q_obs)

            prec_tmp = sum(prec .* repmat(frac_area, 1, size(prec,2)), 1)

            prec_sum = sum(prec_tmp[ikeep])
            q_sum = sum(q_obs[ikeep])
            epot_sum = sum(epot[ikeep])

            pcorr = (q_sum + 0.5 * epot_sum) / prec_sum

            prec = pcorr * prec

        else

            warn("Not enough runoff data for calibration (see folder $dir_cur)")
            continue

        end =#

        # Initilize input object

        input = InputPTE(date, prec, tair, epot)

        # Initilize model object

        model = eval(Expr(:call, opt["model_choice"], opt["tstep"], date[1], frac_lus))

        # Run calibration

        param_tuned = run_model_calib(model, input, q_obs, warmup = opt["warmup"], verbose = :verbose)

        # Rerun model with optimized parameters

        init_states!(model, date[1])

        set_params!(model, param_tuned)

        # Run model with best parameter set

        q_sim = run_model(model, input)

        # Store results in dataframe

        q_obs = round.(q_obs, 2)
        q_sim = round.(q_sim, 2)

        df_res = DataFrame(date = Dates.format(date,"yyyy-mm-dd"), q_sim = q_sim, q_obs = q_obs)

        # Save dataframe to txt file

        stat_name = dir_cur[1:end-5]
        
        file_save = joinpath(opt["path_save"], string(opt["model_choice"]), "tables", "$(stat_name)_station.txt")

        writetable(file_save, df_res, quotemark = '"', separator = '\t')
        
        # Plot results

        ioff()

        file_save = joinpath(opt["path_save"], string(opt["model_choice"]), "figures", "$(stat_name)_runoff.png")

        fig = plt[:figure](figsize = (12,7))

        plt[:style][:use]("ggplot")
        
        ikeep = opt["warmup"]:length(date)

        plt[:plot](date[ikeep], q_sim[ikeep], linewidth = 1.2, color = "r", label = "Sim")
        plt[:title]("Station: $(stat_name)")
        plt[:ylabel]("Runoff (mm/day)")

        if ~isempty(q_obs)
            kge_res = kge(q_sim[ikeep], q_obs[ikeep])
            nse_res = nse(q_sim[ikeep], q_obs[ikeep])
            kge_res = round(kge_res, 2)
            nse_res = round(nse_res, 2)
            plt[:plot](date[ikeep], q_obs[ikeep], linewidth = 1.2, color = "b", label = "Obs")
            plt[:legend]()
            plt[:title]("Station: $(stat_name) | KGE = $(kge_res) | NSE = $(nse_res)")
        else
            kge_res = 0.0
            nse_res = 0.0
        end

        savefig(file_save)        

        close(fig)

        # Add to dataframe

        push!(df_calib, [stat_name nse_res kge_res])

        # Save model object (including parameter values)

        init_states!(model, date[1])

        file_save = joinpath(opt["path_save"], string(opt["model_choice"]), "model_data", "$(stat_name)_modelobj.jld")

        jldopen(file_save, "w") do file
            addrequire(file, VannModels)
            write(file, "model", model)
        end

    end

    file_save = joinpath(opt["path_save"], string(opt["model_choice"]), "summary_calib.txt")

    writetable(file_save, df_calib, quotemark = '"', separator = '\t')

end


# Settings for gr4j

opt = Dict("epot_choice" => :oudin,
           "model_choice" => :model_gr4j,
           "tstep" => 24.0,
           "warmup" => 3*365,
           "path_save" => "/hdata/fou/jmg/flood_forecasting/model_calib",
           "path_inputs" => "/hdata/fou/jmg/flood_forecasting/model_input")
          
# Run the calibration

calib_all_stations(opt)


# Settings for hbv_ligt

opt = Dict("epot_choice" => :oudin,
           "model_choice" => :model_hbv_light,
           "tstep" => 24.0,
           "warmup" => 3*365,
           "path_save" => "/hdata/fou/jmg/flood_forecasting/model_calib",
           "path_inputs" => "/hdata/fou/jmg/flood_forecasting/model_input")

# Run the calibration

calib_all_stations(opt)
