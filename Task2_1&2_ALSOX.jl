using JuMP, HiGHS, CSV, DataFrames

# This model treats each minute as a separate scenario (strict minute-wise)

# --- Load data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]  
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# --- TASK 2.1 ---
# Use first 100 in-sample profiles & Parameters
F = load_profiles[1:100, :]
test_profiles = load_profiles[end-199:end, :]  # Access the last 200 rows (out-of-sample data)
N, T = size(F)
max_capacity = 600              # Maximum capacity of the reserve bid
p_threshold = 0.9              # P90 means at least 90% must satisfy constraint

# --- Define the model ---
model = Model(HiGHS.Optimizer)

@variable(model, 0 <= c_up <= max_capacity)     # reserve bid
#@variable(model, 0 <= y[1:N, 1:T] <= 1)         # relaxed binary variable
@variable(model, y[1:N, 1:T], Bin)              # binary variable (non-relaxed) 

M = 600     # big-M to deactivate constraint when violation is allowed

@constraint(model, [i=1:N, m=1:T], c_up - F[i, m] <= y[i, m] * M)   # Constraint: if no violation, enforce c_up ≤ F[i,m]
@constraint(model, [i=1:N], sum(y[i, :]) <= floor((1 - p_threshold) * T)) # Total violations across all scenario-minutes must be ≤ eta

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (strict minute-wise ALSO-X): ", value(c_up))
println("Total violation weight (relaxed): ", sum(value.(y)))


# --- TASK 2.2 ---
# --- Calculate pass rate for out-of-sample ---
function add_p90_passrate_line!(c_up, test_profiles, p_threshold)
    N_test, T = size(test_profiles)
    min_required_minutes = ceil(Int, p_threshold * T)  # E.g. 54 out of 60 minutes

    # Count compliant profiles (i.e., those with ≥ 54 minutes above c_up)
    passed_count = count(i -> sum(test_profiles[i, :] .>= c_up) >= min_required_minutes, 1:N_test)
    pass_rate = passed_count / N_test * 100
    return pass_rate
end


# --- Plotting ---
using Plots, Statistics

# --- Calculate out-of-sample overbid frequencies ---
N_test, T = size(test_profiles)
overbid_frequencies = [100 * sum(value(c_up) .> test_profiles[i, :]) / T for i in 1:N_test]
pass_rate = add_p90_passrate_line!(value(c_up), test_profiles,p_threshhold)


# --- Define histogram bins ---
bins = 0:2.5:60

# --- Plot histogram with purple tone for ALSO-X ---
histogram(overbid_frequencies,
    bins=bins,
    xlabel="Frequency of reserve shortfall [%]",
    ylabel="Count of test profiles",
    label="ALSO-X",
    legend=:topright,
    color=:slategray1,  # deep purple
    lw=0.5,
    linecolor=:black,
    alpha=0.85,
    title="ALSO-X Out-of-Sample Results")

# --- Reference lines: target and exclusion ---
vline!([10], color=:red, linestyle=:dash, linewidth=2, label="P10 target line (10%)")
vline!([mean(overbid_frequencies)], color=:green, linestyle=:dot, linewidth=2,
    label="Mean = $(round(mean(overbid_frequencies), digits=2))%")
vline!([100-pass_rate], color=:blue, linestyle=:dash, linewidth=2,
    label="Shortfall rate = $(round((100-pass_rate), digits=2))%")