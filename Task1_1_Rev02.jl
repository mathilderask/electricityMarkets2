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

function optimise_bidding_quantity(p_real, lambda_DA, up_price, down_price)
    m = Model(GLPK.Optimizer)

    t = 1:length(p_real)

    @variable(m, p[t])
    @variable(m, t_up[t])
    @variable(m, t_down[t])
    @variable(m, t_delta[t])

    @constraint(m, [i in t], t_up[i] >= 0)
    @constraint(m, [i in t], t_up[i] <= 500 - p[i])
    @constraint(m, [i in t], t_down[i] >= 0)
    @constraint(m, [i in t], t_down[i] <= p[i])
    @constraint(m, [i in t], p[i] >= 0)
    @constraint(m, [i in t], p[i] <= 500)
    @constraint(m, [i in t], t_delta[i] == p_real[i] - p[i])
    @constraint(m, [i in t], t_delta[i] == t_up[i] - t_down[i])

    @objective(m, Max, sum(lambda_DA[k] * p[k] + up_price[k] * t_up[k] - down_price[k] * t_down[k] for k in t)) 
    optimize!(m)
    opt_production = JuMP.value.(p) # should this be p_real or p? Thinking p is the forecasted production and p_real is the actual production (incl. up and down regulation)
    opt_t_up = JuMP.value.(t_up)
    opt_t_down = JuMP.value.(t_down)
    expected_profit = JuMP.objective_value(m)
    return opt_production, opt_t_up, opt_t_down, expected_profit
end


function compute_prices(lambda_DA, system_status)
    up_price_one = Float64[]
    down_price_one = Float64[]
    up_price_two = Float64[]
    down_price_two = Float64[]

    for i in eachindex(lambda_DA)
        if system_status[i] == 0 # deficit
            push!(up_price_one, 1.25 * lambda_DA[i])
            push!(down_price_one, 1.25 * lambda_DA[i])
            push!(up_price_two, 1.00 * lambda_DA[i])
            push!(down_price_two, 1.25 * lambda_DA[i])
        elseif system_status[i] == 1 # excess
            push!(up_price_one, 0.85 * lambda_DA[i])
            push!(down_price_one, 0.85 * lambda_DA[i])
            push!(up_price_two, 0.85 * lambda_DA[i])
            push!(down_price_two, 1.00 * lambda_DA[i])
        else
            error("System_status must be 0 (deficit) or 1 (excess)")
        end
    end

    return up_price_one, down_price_one, up_price_two, down_price_two
end


# RUN MODEL -------------------------------------------------------------------------------------------

# Scenario generation
no_of_scenarios = 1
p_real, lambda_DA, system_status = scenario_generator(no_of_scenarios)

# Optimal production and expected profit calculation
for i in 1:no_of_scenarios
    p_real_local = p_real[:, i]
    lambda_DA_local = lambda_DA[:, i]
    system_status_local = system_status[:, i]

    up_one, down_one, up_two, down_two = compute_prices(lambda_DA_local, system_status_local)

    opt_prod_one, t_up_one, t_down_one, profit_one = optimise_bidding_quantity(p_real_local, lambda_DA_local, up_one, down_one)
    opt_prod_two, t_up_two, t_down_two, profit_two = optimise_bidding_quantity(p_real_local, lambda_DA_local, up_two, down_two)

    # Convert from JuMP DenseAxisArray to plain Vector
    opt_prod_one = collect(opt_prod_one)
    opt_prod_two = collect(opt_prod_two)

    # For DEBUGGING - check up and down regulation
    t_up_one = max.(p_real_local .- opt_prod_one, 0.0)
    t_down_one = max.(opt_prod_one .- p_real_local, 0.0)

    t_up_two = max.(p_real_local .- opt_prod_two, 0.0)
    t_down_two = max.(opt_prod_two .- p_real_local, 0.0)

    # DEBUGGING
    debug_df = DataFrame(
        Hour = 1:24,
        p_real = p_real_local,
        lambda_DA = lambda_DA_local,
        system_status = system_status_local,    
        #up_price_one = up_one,
        #down_price_one = down_one,
        #up_price_two = up_two,
        #down_price_two = down_two,
        t_up_one = collect(t_up_one),
        t_down_one = collect(t_down_one),
        t_up_two = collect(t_up_two),
        t_down_two = collect(t_down_two),
        bid_prod_one = collect(opt_prod_one),
        bid_prod_two = collect(opt_prod_two)
    )

    println("DEBUG TABLE — Scenario $i")
    println(debug_df)
    println("-----------------------------------------")

    results_df = DataFrame(
        Hour = 1:24,
        Opt_Production_OnePrice = opt_prod_one,
        Opt_Production_TwoPrice = opt_prod_two
    )

    println("Scenario ", i)
    println(results_df)
    println("Expected profit under one-price scheme: ", profit_one)
    println("Expected profit under two-price scheme: ", profit_two)
end
