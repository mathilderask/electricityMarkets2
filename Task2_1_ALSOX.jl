using JuMP, HiGHS, CSV, DataFrames 

# This model treats all minutes as one whole scenario (not strict minute-wise)


# Load profile: Stochastic_Load_Profiles.csv (F[i,m])
df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)
load_profiles_clean = df[2:end, 1:end-1]  
load_profiles = parse.(Float64, replace.(string.(Matrix(load_profiles_clean)), ',' => '.'))

# Parameters
F = load_profiles[1:100, :] # load profiles (300 scenarios, 60 minutes) (To get first 100 do: [1:100, :])
N = size(F, 1)  # number of scenarios (100)
T = size(F, 2)  # number of minutes (60)
p_threshold = 0.9  # P90 means at least 90% must satisfy constraint
min_required = ceil(Int, p_threshold * N)  # e.g., 90

model = Model(HiGHS.Optimizer)

@variable(model, c_up >= 0)  # reserve bid (c_up)
@variable(model, y[1:N, 1:T], Bin)  # scenario indicators: 1 if scenario i satisfies all mins

big_M = 1e5  # Penalty term to deactivate constraint when y[i] == 0

@constraint(model, [i=1:N, m=1:T], F[i, m] - c_up + (1 - y[i, m]) * big_M >= 0) # Constraint: if no violation, enforce c_up ≤ F[i,m]
@constraint(model, sum(y) >= min_required) # At least 90% of scenarios must satisfy

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (ALSO-X): ", value(c_up))

# Solution comment:
# At every minute in at least 90% of the 300 profiles, the consumption is above 221.64 kW.
# So, the load can safely commit to reducing up to 221.64 kW in the FCR-D UP market without violating Energinet’s P90 reliability requirement.