using JuMP, HiGHS
using CSV, DataFrames

# This model treats each minute as a separate scenario (strict minute-wise)

# --- Load data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[:, 2:end-1]
load_profiles = Matrix{Float64}(undef, size(load_profiles_clean)...)

for j in 1:size(load_profiles_clean, 2)
    col = load_profiles_clean[!, j]
    load_profiles[:, j] = [x isa Float64 ? x : parse(Float64, replace(string(x), ',' => '.')) for x in col]
end

# Use first 100 in-sample profiles
F = load_profiles[1:100, :]
N, T = size(F)
eta = 0.1  # 10% violation tolerance
q = floor(Int, eta * N * T)  # total number of allowed violations
max_capacity = 600  # maximum capacity of the reserve bid

model = Model(HiGHS.Optimizer)

@variable(model, 0 <= c_up <= max_capacity)  # reserve bid
#@variable(model, y[1:N, 1:T], Bin)  # binary variable - violation flags per minute and scenario
@variable(model, 0 <= y[1:N, 1:T] <= 1) # relaxed binary variable, if this is used change M = 600

M = 600 #1e5  # big-M to deactivate constraint when violation is allowed, if relaxed binary variable is used, change M = 600

# Constraint: if no violation, enforce c_up ≤ F[i,m]
for i in 1:N
    for m in 1:T
        @constraint(model, c_up - F[i, m] <= y[i, m] * M)
    end
end

# Total violations across all scenario-minutes must be ≤ q
@constraint(model, sum(y) <= q)

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (strict minute-wise ALSO-X): ", value(c_up))
