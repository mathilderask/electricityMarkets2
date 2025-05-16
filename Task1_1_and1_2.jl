import Pkg, JuMP, GLPK, DataFrames, CSV, Random, HiGHS
using Pkg, JuMP, GLPK, DataFrames, CSV, Random, HiGHS, PyPlot
include("functions.jl")

p_real_DF = CSV.read("windscenarios_zone2.csv", DataFrame;  delim=',', header=true)
lambda_DA_DF = CSV.read("DA_hourly_price_scenarios.csv", DataFrame;  delim=',', header=true)
scenarios_DF = CSV.read("scenario_combinations.csv", DataFrame; delim=',', header=true)
system_status_DF = CSV.read("power_system_conditions.csv", DataFrame; delim=',', header=true)

scenario_ID = scenarios_DF[:, 1]
global capacity = 500 # Installed capacity in MW
Random.seed!(8) #Makes the random number generation reproducible
no_of_scenarios = 200
p_real, lambda_DA, system_status = scenario_generator(no_of_scenarios)

## Find one price optimal production and expected average profit for 200 scenarios
opt_production, expected_profit = optimise_bidding_quantity(p_real, lambda_DA, system_status, "one-price")
println( "Optimal production quantity: ", opt_production)
println("Expected average profit: ", expected_profit)


## Plot the optimal production offers for one-price scheme for each hour of the day
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

# Evaluate the profit for each scenario in one-price scheme and plot the histogram 
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

## Find two price optimal production and expected average profit for 200 scenarios
opt_production_twoprice, expected_profit_twoprice = optimise_bidding_quantity(p_real, lambda_DA, system_status, "two-price")
println( "Optimal production quantity: ", opt_production_twoprice)
println("Expected average profit: ", expected_profit_twoprice)
production_values = collect(opt_production_twoprice)

##Plot the optimal production offers for each hour of the day on two-price scheme
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

# Evaluate the profit for each scenario in two-price scheme and plot the histogram
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