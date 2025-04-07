import Pkg, JuMP, GLPK, DataFrames, CSV, Plots, Random
using Pkg, JuMP, GLPK, DataFrames, CSV, Plots, Random

p_real_DF = CSV.read("windscenarios_zone2.csv", DataFrame;  delim=',')
### IMPORTANT: df_DA is not with correct data ###
lambda_DA_DF = CSV.read("DA_hourly_price_scenarios.csv", DataFrame;  delim=',')
scenarios_DF = CSV.read("scenario_combinations.csv", DataFrame; delim=',')
system_status_DF = CSV.read("power_system_conditions.csv", DataFrame; delim=',')

scenario_ID = scenarios_DF[:, 1]


function scenario_generator(no_of_scenarios)
    scenarios_indices = randperm(length(scenario_ID))[1:no_of_scenarios]
    #print(scenarios_indices)
    p_real_indices = p_real_DF[scenarios_indices, 2]
    print(p_real_indices)
    lambda_DA_indices = 
    system_status_indices = 
    #return p_real, lamda_DA, system_status
    return p_real_indices
end
print(scenario_generator(5))

function optimise_bidding_quantity(p_real, lambda_DA, system_status) # later add the input: "pricing_scheme", where it will be either "one-price" or "two-price"
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
