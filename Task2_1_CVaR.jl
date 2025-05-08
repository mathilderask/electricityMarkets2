using JuMP, HiGHS
using CSV, DataFrames

# --- Load and prepare data (same as before) ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[:, 2:end-1]
load_profiles = Matrix{Float64}(undef, size(load_profiles_clean)...)

for j in 1:size(load_profiles_clean, 2)
    col = load_profiles_clean[!, j]
    load_profiles[:, j] = [x isa Float64 ? x : parse(Float64, replace(string(x), ',' => '.')) for x in col]
end

# Use first 100 in-sample scenarios
F = load_profiles[1:100, :]
N, T = size(F)

# --- CVaR model parameters ---
α = 0.90
β = 1.0  # Risk-aversion weight (try 0, 0.5, 1.0, 2.0 for experimentation)

model = Model(HiGHS.Optimizer)

@variable(model, R >= 0)           # reserve bid
@variable(model, s[1:N] >= 0)      # max shortfall in each scenario
@variable(model, ξ)                # VaR threshold
@variable(model, u[1:N] >= 0)      # CVaR auxiliary vars

# --- Constraints ---

# Shortfall definition: s[i] ≥ R - F[i, m] for all m
for i in 1:N
    for m in 1:T
        @constraint(model, s[i] >= R - F[i, m])
    end
end

# CVaR auxiliary constraint
for i in 1:N
    @constraint(model, u[i] >= s[i] - ξ)
end

# --- Objective: maximize reserve bid while penalizing tail risk (CVaR) ---
@objective(model, Max, R - β * (ξ + (1 / ((1 - α) * N)) * sum(u)))

optimize!(model)

println("Optimal Reserve Bid (CVaR): ", value(R))
println("CVaR Term: ", value(ξ + (1 / ((1 - α) * N)) * sum(value.(u))))
