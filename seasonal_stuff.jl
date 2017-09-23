

using VannModels
using DataFrames

path = joinpath(Pkg.dir("VannModels"), "data", "atnasjo")

date, tair, prec, q_obs, frac_lus, frac_area, elev = load_data(path)

lat = 60.0

epot = oudin(date, tair, lat, frac_area)

input = InputPTE(prec, tair, epot)

tstep = 24.0

time = date[1]

model = model_hbv_light(tstep, time, frac_lus)

q_sim = run_model(model, input)



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

        df[Symbol(year)] = q_sim
        
    end

    return df

end

ndays = 100

df = run_season(model, date, tair, prec, epot, ndays)






