using JuMP, HiGHS, CSV, DataFrames

# --- Load and clean data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# Use first 100 in-sample scenarios
F = load_profiles[1:100, :]
N, T = size(F)             # N = number of scenarios (i), T = number of minutes (m)
epsilon = 0.1              # 10% violation tolerance

model = Model(HiGHS.Optimizer)

@variable(model, c_up >= 0)                         # Reserve capacity to bid
@variable(model, beta)                              # VaR threshold
@variable(model, xi[1:N, 1:T] >= 0)                  # Shortfall at (i, m)
@variable(model, zeta[1:N, 1:T] >= 0)                # Auxiliary for CVaR

# Constraints
@constraint(model, [i=1:N, m=1:T], c_up - F[i,m] <= xi[i,m])                    # Shortfall definition
@constraint(model, [i=1:N, m=1:T], zeta[i,m] >= xi[i,m] - beta)                # CVaR linearization
@objective(model, Max, c_up)                                                   # Maximize reserve bid

# CVaR constraint: Expected shortfall of worst 10% must be ≤ threshold
@constraint(model, beta + (1 / (epsilon * N * T)) * sum(zeta) <= 0)            # Enforce P90 via CVaR

optimize!(model)

println("Optimal Reserve Bid (c_up): ", value(c_up))
println("CVaR threshold (beta): ", value(beta))
