# ========== Functions for Task 1 ========== #
# Function from 1.4

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

    global capacity = 500 # Installed capacity in MW
    p_real_matrix = Matrix(p_real) * capacity # scale for 500MW wind farm
    lambda_DA_matrix = Matrix(lambda_DA)
    system_status_matrix = Matrix(system_status)
    return p_real_matrix, lambda_DA_matrix, system_status_matrix
end

function optimise_bidding_quantity_extended(p_real, lambda_DA, system_status; alpha=0.9, beta=0.0, pricing_scheme)

    m = Model(HiGHS.Optimizer)
    set_silent(m)

    T = 1:size(p_real, 1)  # hours
    S = 1:size(p_real, 2)  # scenarios
    pi = fill(1 / length(S), length(S))  # equal scenario probabilities
    no_scenarios = size(p_real, 2)

    @variable(m, 0 <= p[T] <= 500)
    @variable(m, t_up[T, S] >= 0)
    @variable(m, t_down[T, S] >= 0)
    @variable(m, t_delta[T, S])

    @variable(m, zeta)
    @variable(m, eta[S] >= 0)

    @constraint(m, [t in T, s in S], t_delta[t, s] == p_real[t, s] - p[t])
    @constraint(m, [t in T, s in S], t_delta[t, s] == t_up[t, s] - t_down[t, s])


    # Pricing scheme
    if pricing_scheme == "one-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    elseif pricing_scheme == "two-price"
        up_price = [system_status[t, s] == 1 ? 0.85 * lambda_DA[t, s] : 1 * lambda_DA[t, s] for t in T, s in S]
        down_price = [system_status[t, s] == 1 ? 1 * lambda_DA[t, s] : 1.25 * lambda_DA[t, s] for t in T, s in S]
    else
        error("Invalid pricing scheme. Use 'one-price' or 'two-price'.")
    end

    # Define profit per scenario
    @expression(m, Profit[s in S], sum(
        lambda_DA[t, s] * p[t] + up_price[t, s] * t_up[t, s] - down_price[t, s] * t_down[t, s]
        for t in T
    ))
    
    # CVaR constraints using Profit[s]
    @constraint(m, [s in S], eta[s] >= zeta - Profit[s])


    # Objective using Profit[s]
    @objective(m, Max,
        (1 - beta) * sum(1/no_scenarios * Profit[s] for s in S)
        + beta * (zeta - (1 / (1 - alpha)) * sum(1/no_scenarios * eta[s] for s in S))
    )

    
    optimize!(m)    
    opt_production = JuMP.value.(p)
    scenario_profits = [JuMP.value(Profit[s]) for s in S]
    expected_profit = sum(pi[s] * scenario_profits[s] for s in S)
    cvar = JuMP.value(zeta) - (1 / (1 - alpha)) * sum(pi[s]*JuMP.value(eta[s]) for s in S)

    return opt_production, expected_profit, cvar
end

# ========== Functions for Task 2 ========== #

function add_p90_passrate_line!(c_up, test_profiles, p_threshold)
    N_test, T = size(test_profiles)
    min_required_minutes = ceil(Int, p_threshold * T)  # E.g. 54 out of 60 minutes

    # Count compliant profiles (i.e., those with ≥ 54 minutes above c_up)
    passed_count = count(i -> sum(test_profiles[i, :] .>= c_up) >= min_required_minutes, 1:N_test)
    pass_rate = passed_count / N_test * 100
    return pass_rate
end

function compute_pass_rate(c_up, test_profiles; p_threshold=0.9)
    N_test, T = size(test_profiles)
    count_pass = 0
    for i in 1:N_test
        covered_minutes = sum(c_up .<= test_profiles[i, :])
        if covered_minutes / T >= p_threshold
            count_pass += 1
        end
    end
    return 100 * count_pass / N_test
end


function evaluate_bid(test_profiles, bid, label)
    margin_matrix = test_profiles .- bid  # Same shape as test_profiles
    # Count how many minutes are satisfied for each profile
    compliance = sum(margin_matrix .>= 0, dims=2)  # Compute sums for each row
    compliance = vec(compliance)  # Ensure it's a vector, not a matrix
    
    # Compare compliance with the threshold (min_required_minutes)
    passed_count = sum(compliance .>= min_required_minutes)
    
    p90_ratio = passed_count / N_test * 100
    println("P90 Verification for ", label)
    println("Compliant profiles: ", passed_count, " out of ", N_test)
    println("Compliance rate: ", round(p90_ratio, digits=2), "%")


    return margin_matrix
end