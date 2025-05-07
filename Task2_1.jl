using JuMP, HiGHS 
using CSV, DataFrames

# Load profile: Stochastic_Load_Profiles.csv
load_profiles_df = CSV.read("Stochastic_Load_Profiles.csv", DataFrame)

# Drop the last column which contains "In-sample" labels
load_profiles_clean = load_profiles_df[:, 2:end-1]  # Exclude the first and last column

# Safely convert all entries to Float64
load_profiles = Array{Float64}(undef, size(load_profiles_clean)...)

for j in 1:size(load_profiles_clean, 2)
    col = load_profiles_clean[!, j]
    load_profiles[:, j] = [x isa Float64 ? x : parse(Float64, replace(string(x), ',' => '.')) for x in col]
end


N = size(load_profiles, 1)  # number of scenarios (100)
T = size(load_profiles, 2)  # number of minutes (60)
p_threshold = 0.9  # P90 means at least 90% must satisfy constraint
min_required = ceil(Int, p_threshold * N)  # e.g., 90

model = Model(HiGHS.Optimizer)

@variable(model, R >= 0)  # reserve bid
@variable(model, z[1:N], Bin)  # scenario indicators: 1 if scenario i satisfies all mins

big_M = 1e5  # Penalty term to deactivate constraint when z[i] == 0

for i in 1:N
    for t in 1:T
        @constraint(model, load_profiles[i, t] - R + (1 - z[i]) * big_M >= 0)
    end
end

# At least 90% of scenarios must satisfy
@constraint(model, sum(z) >= min_required)

@objective(model, Max, R)

optimize!(model)

println("Optimal Reserve Bid (ALSO-X): ", value(R))
