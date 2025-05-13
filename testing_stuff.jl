using JuMP, HiGHS, CSV, DataFrames

# --- Load and clean data ---
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]  
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# Use first 100 in-sample scenarios
F = load_profiles[1:100, :]
N, T = size(F)             # N = number of scenarios (i), T = number of minutes (m)
epsilon = 0.1              # 10% violation tolerance
M = 1e5                    # Big-M constant

model = Model(HiGHS.Optimizer)

@variable(model, c_up == 231.535)                        # Reserve capacity to bid
@variable(model, beta <= 0)                        # CVaR VaR-threshold
@variable(model, xi[1:N, 1:T])                     # Shortfall at (i, m)
@variable(model, y[1:N], Bin)                  # Binary variables for P90 # -----  solely for P90 constraint, maybe delete

# Constraints
@constraint(model, [i=1:N, m=1:T], c_up - F[i,m] <= xi[i,m])        # CVaR Constraint 1
@constraint(model, (1 / (N * T)) * sum(xi) <= (1 - epsilon) * beta) # CVaR Constraint 2
@constraint(model, [i=1:N, m=1:T], beta <= xi[i, m])                # CVaR Constraint 3

@constraint(model, [i=1:N, m=1:T], c_up - F[i,m] <= M * y[i])       # P90 Big-M linking # -----  solely for P90 constraint, maybe delete
@constraint(model, sum(y) <= epsilon * N)                           # P90 violation cap # -----  solely for P90 constraint, maybe delete

@objective(model, Max, 0) # Dummy objective since c_up is fixed

optimize!(model)

println("Optimal Reserve Bid (c_up): ", value(c_up))
println("VaR threshold (beta): ", value(beta))
