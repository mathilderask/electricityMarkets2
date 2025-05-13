using JuMP, HiGHS, CSV, DataFrames

# This model treats each minute as a separate scenario (strict minute-wise)

# --- Load data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]  
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# Use first 100 in-sample profiles & Parameters
F = load_profiles[1:100, :]
N, T = size(F)
max_capacity = 600              # Maximum capacity of the reserve bid
eta = 0.1                       # 10% violation tolerance
q = floor(Int, eta * N * T)     # Total number of allowed violations
p_threshhold = 0.9              # P90 means at least 90% must satisfy constraint

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
