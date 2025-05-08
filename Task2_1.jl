using JuMP, HiGHS 
using CSV, DataFrames

# Load profile: Stochastic_Load_Profiles.csv (F[i,m])
load_profiles_df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)

# USE 300 PROFILES -------
# Drop the last column which contains "In-sample" labels
load_profiles_clean = load_profiles_df[:, 2:end-1]  # Exclude the first and last column

# Convert load_profiles to a matrix of Float64 values
 for j in 1:size(load_profiles_clean, 2)
    col = load_profiles_clean[!, j]
    load_profiles[:, j] = [x isa Float64 ? x : parse(Float64, replace(string(x), ',' => '.')) for x in col]
end

# Parameters
F = load_profiles[1:100, :] # load profiles (100 out of 300 scenarios, 60 minutes)
N = size(F, 1)  # number of scenarios (100)
T = size(F, 2)  # number of minutes (60)
p_threshold = 0.9  # P90 means at least 90% must satisfy constraint
min_required = ceil(Int, p_threshold * N)  # e.g., 90

model = Model(HiGHS.Optimizer)

@variable(model, c_up >= 0)  # reserve bid (R), FCR-D UP
@variable(model, z[1:N], Bin)  # scenario indicators: 1 if scenario i satisfies all mins

big_M = 1e5  # Penalty term to deactivate constraint when z[i] == 0

for i in 1:N
    for m in 1:T
        @constraint(model, F[i, m] - c_up + (1 - z[i]) * big_M >= 0)
    end
end

# At least 90% of scenarios must satisfy
@constraint(model, sum(z) >= min_required)

@objective(model, Max, c_up)

optimize!(model)

println("Optimal Reserve Bid (ALSO-X): ", value(c_up))

# Solution comment:
# At every minute in at least 90 of the 100 in-sample profiles, the consumption is above 221.64 kW.
# So, the load can safely commit to reducing up to 221.64 kW in the FCR-D UP market without violating Energinet’s P90 reliability requirement.