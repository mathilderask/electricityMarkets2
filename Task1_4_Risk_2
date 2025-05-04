import Pkg, JuMP, GLPK, DataFrames, CSV, Random
using Pkg, JuMP, GLPK, DataFrames, CSV, Random

p_real_DF = CSV.read("windscenarios_zone2.csv", DataFrame;  delim=',', header=true)
lambda_DA_DF = CSV.read("DA_hourly_price_scenarios.csv", DataFrame;  delim=',', header=true)
scenarios_DF = CSV.read("scenario_combinations.csv", DataFrame; delim=',', header=true)
system_status_DF = CSV.read("power_system_conditions.csv", DataFrame; delim=',', header=true)

scenario_ID = scenarios_DF[:, 1]
Random.seed!(8) #Makes the random number generation reproducible

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

    p_real_matrix = Matrix(p_real) * 500 # scale for 500MW wind farm
    lambda_DA_matrix = Matrix(lambda_DA)
    system_status_matrix = Matrix(system_status)
    return p_real_matrix, lambda_DA_matrix, system_status_matrix
end

function optimise_bidding_quantity(p_real, lambda_DA, system_status, pricing_scheme) # later add the input: "pricing_scheme", where it will be either "one-price" or "two-price"
# now these inputs are data frames with all the scenarios as columns and hours as rows
# this is to enable stochastic modelling
    m = Model(GLPK.Optimizer)

    T = 1:size(p_real, 1) # hours
    S = 1:size(p_real, 2)  # scenarios

    @variable(m, p[T])
    @variable(m, t_up[T, S] >= 0)
    @variable(m, t_down[T, S] >= 0)
    @variable(m, t_delta[T, S])

    @constraint(m, [t in T], p[t] >= 0)
    @constraint(m, [t in T], p[t] <= 500)
    @constraint(m, [t in T, s in S], t_delta[t, s] == p_real[t, s] - p[t])
    @constraint(m, [t in T, s in S], t_delta[t, s] == t_up[t, s] - t_down[t, s])
    @constraint(m, [t in T, s in S], t_up[t, s] >= 0)

    @variable(m, z[T, S], Bin)  # binary variable to switch between up and down regulation

    @constraint(m, [t in T, s in S], t_up[t, s] <= 500 * z[t, s]) # make max production a variable instead of 500
    @constraint(m, [t in T, s in S], t_down[t, s] <= 500 * (1 - z[t, s]))

    # One-pricing scheme
    # Generate balancing prices per scenario
    if pricing_scheme == "one-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    elseif pricing_scheme == "two-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 1 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    else
        error("Invalid pricing scheme. Use 'one-price' or 'two-price'.")
    end
    @objective(m, Max, sum(
            lambda_DA[t, s] * p[t] + up_price[t, s] * t_up[t, s] - down_price[t, s] * t_down[t, s]
            for  t in T, s in S
        )
    )
    optimize!(m)
    #println(value.(t_up))
    #println(value.(t_down))
    #println(value.(t_delta))
    #println(p_real)
    
    #println(down_price)
    opt_production = JuMP.value.(p)
    expected_profit = JuMP.objective_value(m)
    return opt_production, expected_profit
end

no_of_scenarios = 10
p_real, lambda_DA, system_status = scenario_generator(no_of_scenarios)

opt_production, expected_profit = optimise_bidding_quantity(p_real, lambda_DA, system_status, "one-price")
println( "Optimal production quantity: ", opt_production)
println("Expected cumulative profit: ", expected_profit)
production_values = collect(opt_production)

using PyPlot

hours = 1:24
production_values = values(opt_production)

figure(figsize=(10, 5))
bar(hours, production_values, width=0.8)
for (h, p) in zip(hours, production_values)
    if p == 0.0
        scatter(h, 5, color="blue", marker="o", s=20) 
    end
end
xlabel("Hour of the Day")
ylabel("Offered Production (MW)")
title("Optimal Day-Ahead Production Offers for One-Price Scheme")
grid(true, axis="y")
xticks(hours)
tight_layout()
show()

opt_production_twoprice, expected_profit_twoprice = optimise_bidding_quantity(p_real, lambda_DA, system_status, "two-price")
println( "Optimal production quantity: ", opt_production_twoprice)
println("Expected cumulative profit: ", expected_profit_twoprice)
production_values = collect(opt_production_twoprice)


hours = 1:24
figure(figsize=(10, 5))
bar(hours, production_values, width=0.8)
for (h, p) in zip(hours, production_values)
    if p == 0.0
        scatter(h, 0.5, color="blue", marker="o", s=20) 
        # marker at small height (e.g., y=0.5) so it's visible
    end
end
xlabel("Hour of the Day")
ylabel("Offered Production (MW)")
title("Optimal Day-Ahead Production Offers for two price scheme")
grid(true, axis="y")
xticks(hours)
tight_layout()
show()