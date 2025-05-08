using JuMP, HiGHS
using CSV, DataFrames

# --- Load and clean data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[:, 2:end-1]
load_profiles = Matrix{Float64}(undef, size(load_profiles_clean)...)

for j in 1:size(load_profiles_clean, 2)
    col = load_profiles_clean[!, j]
    load_profiles[:, j] = [x isa Float64 ? x : parse(Float64, replace(string(x), ',' => '.')) for x in col]
end

# Use first 100 in-sample scenarios
F = load_profiles[1:100, :]
N, T = size(F)             # N = number of scenarios (i), T = number of minutes (m)
epsilon = 0.1              # 10% violation tolerance

model = Model(HiGHS.Optimizer)

@variable(model, c_up >= 0)                        # Reserve capacity to bid
@variable(model, beta <= 0)                        # CVaR VaR-threshold
@variable(model, xi[1:N, 1:T] >= 0)                 # Shortfall at (i, m)

# Constraint 1: c_up - F[i, m] ≤ xi[i, m]
for i in 1:N
    for m in 1:T
        @constraint(model, c_up - F[i, m] <= xi[i, m])
    end
end

# Constraint 2: average of all xi[i,m] ≤ (1 - epsilon) * beta
@constraint(model, (1 / (N * T)) * sum(xi) <= (1 - epsilon) * beta)

# Constraint 3: beta ≤ xi[i, m] ∀ i, m
for i in 1:N
    for m in 1:T
        @constraint(model, beta <= xi[i, m])
    end
end

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (c_up): ", value(c_up))
println("VaR threshold (beta): ", value(beta))