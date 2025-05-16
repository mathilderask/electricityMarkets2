import Pkg, JuMP, GLPK, DataFrames, CSV, Random, HiGHS
using Pkg, JuMP, GLPK, DataFrames, CSV, Random, HiGHS


p_real_DF = CSV.read("windscenarios_zone2.csv", DataFrame;  delim=',', header=true)
lambda_DA_DF = CSV.read("DA_hourly_price_scenarios.csv", DataFrame;  delim=',', header=true)
scenarios_DF = CSV.read("scenario_combinations.csv", DataFrame; delim=',', header=true)
system_status_DF = CSV.read("power_system_conditions.csv", DataFrame; delim=',', header=true)

scenario_ID = scenarios_DF[:, 1]
global capacity = 500 # Installed capacity in MW
Random.seed!(8) #Makes the random number generation reproducible

function scenario_generator(no_of_scenarios)
#### Returns a random selection of defined number of scenarios in.
#### Returns 3 dataframes for the three variables where each column is corresponding data for a randomly selected scenario
#### Each dataframe has 24 rows for the 24 hours of the day
    scenarios_indices = randperm(length(scenario_ID))[1:no_of_scenarios]
    p_real_indices = scenarios_DF[scenarios_indices, 2]
    lambda_DA_indices = scenarios_DF[scenarios_indices, 3]
    system_status_indices = scenarios_DF[scenarios_indices, 4]

    # need it in dataframe format because otherwise it freaks out about indexing with duplicates
    p_real_cols = [p_real_DF[:, i+1] for i in p_real_indices]
    col_names = Symbol.("selected_scenario_", 1:length(p_real_cols))  # custom unique names
    p_real = DataFrame(p_real_cols, col_names)

    lambda_DA_cols = [lambda_DA_DF[:, i+1] for i in lambda_DA_indices]
    lambda_DA = DataFrame(lambda_DA_cols, col_names)

    system_status_cols = [system_status_DF[:, i+1] for i in system_status_indices]
    system_status = DataFrame(system_status_cols, col_names)

    
    p_real_matrix = Matrix(p_real) * capacity # scale for 500MW wind farm
    lambda_DA_matrix = Matrix(lambda_DA)
    system_status_matrix = Matrix(system_status)
    return p_real_matrix, lambda_DA_matrix, system_status_matrix
end

function optimise_bidding_quantity(p_real, lambda_DA, system_status, pricing_scheme)
# these inputs are data frames with all the scenarios as columns and hours as rows
    m = Model(HiGHS.Optimizer)
    set_silent(m) # suppress output from the solver
    T = 1:size(p_real, 1) # hours
    S = 1:size(p_real, 2)  # scenarios
    no_scenarios = size(p_real, 2)

    @variable(m, 0 <= p[T] <= capacity)
    @variable(m, t_up[T, S] >= 0)
    @variable(m, t_down[T, S] >= 0)
    @variable(m, t_delta[T, S])
    
    @constraint(m, [t in T, s in S], t_delta[t, s] == p_real[t, s] - p[t])
    @constraint(m, [t in T, s in S], t_delta[t, s] == t_up[t, s] - t_down[t, s])


    # Generate balancing prices per scenario
    # 1 means system in excess, 0 means system in deficit
    if pricing_scheme == "one-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    elseif pricing_scheme == "two-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 1 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    else
        error("Invalid pricing scheme. Use 'one-price' or 'two-price'.")
    end
    @objective(m, Max, sum( 1/no_scenarios * (
            lambda_DA[t, s] * p[t] + up_price[t, s] * t_up[t, s] - down_price[t, s] * t_down[t, s])
            for  t in T, s in S
        )
    )
    optimize!(m)
    opt_production = JuMP.value.(p)
    expected_profit = JuMP.objective_value(m)
    return opt_production, expected_profit
end



function evaluate_profit_per_scenario(p_opt, p_real, lambda_DA, system_status, pricing_scheme)
    profit_list = []
    T = 1:size(p_real, 1)
    S = 1:size(p_real, 2)

    t_delta = [p_real[t, s] - p_opt[t] for t in T, s in S]
    t_up = [max(t, 0) for t in t_delta]
    t_down = [max(-t, 0) for t in t_delta]

    if pricing_scheme == "one-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    elseif pricing_scheme == "two-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 1 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    end
    for s in S
        expected_profit = sum(lambda_DA[t, s] * p_opt[t] + up_price[t, s] * t_up[t, s] - down_price[t, s] * t_down[t, s]
                          for t in T)
        push!(profit_list, expected_profit)
    end
    return profit_list
end

no_of_scenarios = 200
p_real, lambda_DA, system_status = scenario_generator(no_of_scenarios)

opt_production, expected_profit = optimise_bidding_quantity(p_real, lambda_DA, system_status, "one-price")
println( "Optimal production quantity: ", opt_production)
println("Expected average profit: ", expected_profit)



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

production_values = collect(opt_production)
profit_per_scenario = evaluate_profit_per_scenario(production_values, p_real, lambda_DA, system_status, "one-price")
using PyPlot
figure()
hist(profit_per_scenario ./ 1e6, bins=30, edgecolor="black")
#title("Profit Distribution for One-Price Scheme")
xlabel("Profit (EURm)")
ylabel("Number of Observations")
grid(true)
show()
display(gcf())


opt_production_twoprice, expected_profit_twoprice = optimise_bidding_quantity(p_real, lambda_DA, system_status, "two-price")
println( "Optimal production quantity: ", opt_production_twoprice)
println("Expected average profit: ", expected_profit_twoprice)
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

production_values = collect(opt_production_twoprice)
profit_per_scenario = evaluate_profit_per_scenario(production_values, p_real, lambda_DA, system_status, "two-price")
using PyPlot
figure()
hist(profit_per_scenario  ./ 1e6, bins=30, edgecolor="black")
#title("Profit Distribution for Two-Price Scheme")
xlabel("Profit (EURm)")
ylabel("Number of Observations")
grid(true)
show()
display(gcf())