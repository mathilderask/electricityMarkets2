using Pkg, JuMP, GLPK, DataFrames, CSV, Plots

# Load the data
data = CSV.read("Task1_1.csv", DataFrame)

p_real = CSV.read("WindFarmData.csv", DataFrame;  delim=';')
### IMPORTANT: df_DA is not with correct data ###
lambda_DA = CSV.read("DA_price.csv", DataFrame;  delim=';')


println(p_real)

function scenario_generator(no_of_scenarios)
    production_index = 
    DA_price_index = 
    system_status_index = 
    return p_real[production_index], lambda_DA[DA_price_index], system_status[system_status_index]
end


function optimise_bidding_quantity(system_status, p_real, lambda_DA) # later add the input: "pricing_scheme", where it will be either "one-price" or "two-price"
    m = Model(GLPK.Optimizer)

    t = 1:length(p_real)

    @variable(m, p[t])
    @variable(m, t_up[t])
    @variable(m, t_down[t])
    @variable(m, t_delta[t])


    @constraint(m, t_up[t] >= 0)
    @constraint(m, t_down[t] >= 0)
    @constraint(m, p[t] >= 0)
    @constraint(m, p[t] <= 500)
    @constraint(m, t_delta[t] = p_real[t] - p[t])
    @constraint(m, t_delta[t] = t_up[t] - t_down[t])

    # One-pricing scheme
    if system_status == "deficit"
        up_price = 1.25 * lambda_DA[t]
        down_price = 1.25 * lambda_DA[t]
    elseif system_status == "excess"
        up_price = 0.85 * lambda_DA[t]
        down_price = 0.85 * lambda_DA[t]
    else
        println("Error: system_status must be either 'deficit' or 'excess'")
    end

    @objective(m, Max, sum(lambda_DA[k]*W[k]+up_price*lambda_DA[k]*t_up[k]-down_price*lambda_DA[k]*t_down[k] for k in t)) 
end
