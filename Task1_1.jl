import Pkg, JuMP, GLPK, DataFrames, CSV, Plots, Random
using Pkg, JuMP, GLPK, DataFrames, CSV, Plots, Random

p_real_DF = CSV.read("windscenarios_zone2.csv", DataFrame;  delim=',')
lambda_DA_DF = CSV.read("DA_hourly_price_scenarios.csv", DataFrame;  delim=',')
scenarios_DF = CSV.read("scenario_combinations.csv", DataFrame; delim=',')
system_status_DF = CSV.read("power_system_conditions.csv", DataFrame; delim=',')

scenario_ID = scenarios_DF[:, 1]


function scenario_generator(no_of_scenarios)
#### Returns a random selection of defined number of scenarios in.
#### Returns 3 dataframes for the three variables where each column is corresponding data for a randomly selected scenario
#### Each dataframe has 24 rows for the 24 hours of the day
    scenarios_indices = randperm(length(scenario_ID))[1:no_of_scenarios]
    p_real_indices = scenarios_DF[scenarios_indices, 2]
    lambda_DA_indices = scenarios_DF[scenarios_indices, 3]
    system_status_indices = scenarios_DF[scenarios_indices, 4]

    p_real_cols = [p_real_DF[:, i+1] for i in p_real_indices]
    col_names = Symbol.("selected_scenario_", 1:length(p_real_cols))  # custom unique names
    p_real = DataFrame(p_real_cols, col_names)

    lambda_DA_cols = [lambda_DA_DF[:, i+1] for i in lambda_DA_indices]
    lambda_DA = DataFrame(lambda_DA_cols, col_names)

    system_status_cols = [system_status_DF[:, i+1] for i in system_status_indices]
    system_status = DataFrame(system_status_cols, col_names)
    
    return p_real, lambda_DA, system_status
end

function optimise_bidding_quantity(p_real, lambda_DA, system_status) # later add the input: "pricing_scheme", where it will be either "one-price" or "two-price"
    m = Model(GLPK.Optimizer)

    t = 1:length(p_real)

    @variable(m, p[t])
    @variable(m, t_up[t])
    @variable(m, t_down[t])
    @variable(m, t_delta[t])


    #@constraint(m, t_up[t] >= 0)
    #@constraint(m, p[t] >= 0)
    #@constraint(m, p[t] <= 500)
    #@constraint(m, t_delta[t] == p_real[t] - p[t])
    #@constraint(m, t_delta[t] == t_up[t] - t_down[t])

    @constraint(m, [i in t], t_up[i] >= 0)
    @constraint(m, [i in t], p[i] >= 0)
    @constraint(m, [i in t], p[i] <= 500)
    @constraint(m, [i in t], t_delta[i] == p_real[i] - p[i])
    @constraint(m, [i in t], t_delta[i] == t_up[i] - t_down[i])

    up_price = Vector{Float64}(undef, 24)
    down_price = Vector{Float64}(undef, 24)
    # One-pricing scheme
    for i in t
        if system_status[i] == 1   # randomly assigned 1 to deficit and 0 to excess here
            up_price[i] = 1.25 * lambda_DA[i]
            down_price[i] = 1.25 * lambda_DA[i]
        elseif system_status[i] == 0 # randomly assigned 1 to deficit and 0 to excess here
            up_price[i] = 0.85 * lambda_DA[i]
            down_price[i] = 0.85 * lambda_DA[i]
        else
            println("Error: system_status must be either 'deficit' or 'excess'")
        end
    end

    @objective(m, Max, sum(lambda_DA[k]*p[k]+up_price[k]*t_up[k]-down_price[k]*t_down[k] for k in t)) 
    optimize!(m)
    opt_production = JuMP.value.(p)
    expected_profit = JuMP.objective_value(m)
    return opt_production, expected_profit
    ### we want: optimal hourly proudction quanitity offers, and expected profit
end


no_of_scenarios = 1
p_real, lambda_DA, system_status = scenario_generator(no_of_scenarios)
for i in no_of_scenarios
    p_real_local = p_real[:, i]
    lambda_DA_local = lambda_DA[:, i]
    system_status_local = system_status[:, i]
    opt_production, expected_profit = optimise_bidding_quantity(p_real_local, lambda_DA_local, system_status_local)
    println("For scenario ", i, " optimal production quantity: ", opt_production)
    println("For scenario ", i, " expected profit: ", expected_profit)
end