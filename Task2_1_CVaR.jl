using JuMP, HiGHS, CSV, DataFrames

# --- Load and clean data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]  
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# Use first 100 in-sample scenarios
F = load_profiles[1:100, :]
test_profiles = load_profiles[end-199:end, :]  # Access the last 200 rows (out-of-sample data)
N, T = size(F)             # N = number of scenarios (i), T = number of minutes (m)
epsilon = 0.1              # 10% violation tolerance
M = 1e5                    # Big-M constant

model = Model(HiGHS.Optimizer)

@variable(model, c_up >= 0)                        # Reserve capacity to bid
@variable(model, beta <= 0)                        # CVaR VaR-threshold
@variable(model, xi[1:N, 1:T])                     # Shortfall at (i, m)
#@variable(model, y[1:N], Bin)                  # Binary variables for P90 # -----  solely for P90 constraint, maybe delete

# Constraints
@constraint(model, [i=1:N, m=1:T], c_up - F[i,m] <= xi[i,m])        # CVaR Constraint 1
@constraint(model, (1 / (N * T)) * sum(xi) <= (1 - epsilon) * beta) # CVaR Constraint 2
@constraint(model, [i=1:N, m=1:T], beta <= xi[i, m])                # CVaR Constraint 3

#@constraint(model, [i=1:N, m=1:T], c_up - F[i,m] <= M * y[i])       # P90 Big-M linking # -----  solely for P90 constraint, maybe delete
#@constraint(model, sum(y) <= epsilon * N)                           # P90 violation cap # -----  solely for P90 constraint, maybe delete

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (CVaR): ", value(c_up))
println("VaR threshold (beta): ", value(beta))


# --- Calculate pass rate for out-of-sample ---
function add_p90_passrate_line!(c_up, test_profiles; p_threshold=0.9)
    N_test, T = size(test_profiles)
    min_required_minutes = ceil(Int, p_threshold * T)  # E.g. 54 out of 60 minutes

    # Count compliant profiles (i.e., those with ≥ 54 minutes above c_up)
    passed_count = count(i -> sum(test_profiles[i, :] .>= c_up) >= min_required_minutes, 1:N_test)
    pass_rate = passed_count / N_test * 100

    return pass_rate
end


# --- Plotting ---
using Plots, Statistics


N_test, T = size(test_profiles)  # e.g., 200 × 60
overbid_frequencies = zeros(Float64, N_test)
pass_rate = add_p90_passrate_line!(value(c_up), test_profiles)

# Classify out-of-sample test scenarios
num_with_overbid = count(i -> any(value(c_up) .> test_profiles[i, :]), 1:N_test)
num_without_overbid = N_test - num_with_overbid

for i in 1:N_test
    shortfall_minutes = sum(value(c_up) .> test_profiles[i, :])  # count of minutes where shortfall occurs
    overbid_frequencies[i] = 100 * shortfall_minutes / T  # convert to %
end

# Define bins
bins = 0:2.5:60

# Create histogram
histogram(overbid_frequencies,
    bins=bins,
    xlabel="Frequency of reserve shortfall [%]",
    ylabel="Count of test profiles",
    label="CVaR",
    legend=:topright,
    color=:peru,
    lw=0.5,
    linecolor=:black,
    alpha=0.8,
    title="CVaR Out-of-Sample Results")

# Add vertical reference lines
vline!([10], color=:red, linestyle=:dash, linewidth=2, label="P10 target line (10%)")
vline!([mean(overbid_frequencies)], color=:green, linestyle=:dot, linewidth=2,
    label="Mean = $(round(mean(overbid_frequencies), digits=2))%")
vline!([100-pass_rate], color=:blue, linestyle=:dash, linewidth=2,
    label="Shortfall rate = $(round((100-pass_rate), digits=2))%")

