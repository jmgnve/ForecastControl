# Load packages

using Vann
using PyPlot
using DataFrames
using ExcelReaders
using JLD
using CSV
using ProgressMeter

# Settings

opt = Dict("epot_choice" => :epot_monthly,
           "snow_choice" => :TinBasic,
           "hydro_choice" => :Gr4j,
           "force_states" => true,
           "tstep" => 24.0,
           "warmup" => 3*365,
           "path_save" => "/home/jmg/flood_forecasting/model_calib",
           "path_inputs" => "/home/jmg/flood_forecasting/model_input")

# Create folders for saving results

mkpath(opt["path_save"] * "/tables")
mkpath(opt["path_save"] * "/figures")
mkpath(opt["path_save"] * "/param_snow")
mkpath(opt["path_save"] * "/param_hydro")
mkpath(opt["path_save"] * "/model_data")

# Calibrate all stations for one experiment

function calib_all_stations(opt)

    # Empty dataframes for summary statistics

    df_calib = DataFrame(Station = String[], NSE = Float64[], KGE = Float64[])

    # Loop over all watersheds

    dir_all = readdir(opt["path_inputs"])

    @showprogress 1 "Calibrating models..." for dir_cur in dir_all

        # Load data

        date, tair, prec, q_obs, frac = 0, 0, 0, 0, 0

        try
            date, tair, prec, q_obs, frac = load_operational("$(opt["path_inputs"])/$dir_cur")
        catch
            info("Unable to read files in directory $(dir_cur)\n")
            continue
        end

        # Compute potential evapotranspiration

        epot = eval(Expr(:call, opt["epot_choice"], date))

        # Precipitation correction step

        if sum(~isnan(q_obs)) > (3*365)

            ikeep = ~isnan(q_obs)

            prec_tmp = sum(prec .* repmat(frac, 1, size(prec,2)), 1)

            prec_sum = sum(prec_tmp[ikeep])
            q_sum = sum(q_obs[ikeep])
            epot_sum = sum(epot[ikeep])

            pcorr = (q_sum + 0.5 * epot_sum) / prec_sum

            prec = pcorr * prec

        else

            warn("Not enough runoff data for calibration (see folder $dir_cur)")
            continue

        end

        # Initilize model

        st_snow = eval(Expr(:call, opt["snow_choice"], opt["tstep"], date[1], frac))
        st_hydro = eval(Expr(:call, opt["hydro_choice"], opt["tstep"], date[1]))

        # Run calibration

        param_snow, param_hydro = run_model_calib(st_snow, st_hydro, date, tair, prec, epot, q_obs;
                                                force_states = opt["force_states"], warmup = opt["warmup"])

        println("Snow model parameters: $param_snow")
        println("Hydro model parameters: $param_hydro")

        # Reinitilize model

        st_snow = eval(Expr(:call, opt["snow_choice"], opt["tstep"], date[1], param_snow, frac))
        st_hydro = eval(Expr(:call, opt["hydro_choice"], opt["tstep"], date[1], param_hydro))

        # Run model with best parameter set

        q_sim, st_snow, st_hydro = run_model(st_snow, st_hydro, date, tair, prec, epot; return_all = true)

        # Store results in data frame

        q_obs = round(q_obs, 2)
        q_sim = round(q_sim, 2)

        df_res = DataFrame(date = Dates.format(date,"yyyy-mm-dd"), q_sim = q_sim, q_obs = q_obs)

        # Save results to txt file

        file_save = dir_cur[1:end-5]

        writetable(string(opt["path_save"], "/tables/", file_save, "_station.txt"), df_res, quotemark = '"', separator = '\t')

        # Plot results

        ioff()

        file_name = string(opt["path_save"], "/figures/", file_save, "_hydro.png")

        plot_sim(st_hydro; q_obs = q_obs, file_name = file_name)

        file_name = string(opt["path_save"], "/figures/", file_save, "_snow.png")

        plot_sim(st_snow; file_name = file_name)

        # Compute summary statistics

        station = dir_cur[1:end-5]
        kge_res = kge(q_sim[opt["warmup"]:end], q_obs[opt["warmup"]:end])
        nse_res = nse(q_sim[opt["warmup"]:end], q_obs[opt["warmup"]:end])

        push!(df_calib, [station nse_res kge_res])

        # Save parameter values

        writedlm(opt["path_save"] * "/param_snow/" * file_save * "_param_snow.txt", param_snow)
        writedlm(opt["path_save"] * "/param_hydro/" * file_save * "_param_hydro.txt", param_hydro)

        st_snow = eval(Expr(:call, opt["snow_choice"], opt["tstep"], date[1], param_snow, frac))
        st_hydro = eval(Expr(:call, opt["hydro_choice"], opt["tstep"], date[1], param_hydro))

        jldopen(opt["path_save"] * "/model_data/" * file_save * "_modeldata.jld", "w") do file
            addrequire(file, Vann)
            write(file, "st_snow", st_snow)
            write(file, "st_hydro", st_hydro)
        end

    end

    writetable(string(opt["path_save"], "/summary_calib_period.txt"), df_calib, quotemark = '"', separator = '\t')

end

# Run the calibration

calib_all_stations(opt)




