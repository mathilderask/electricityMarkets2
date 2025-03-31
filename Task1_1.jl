using Pkg, JuMP, GLPK, DataFrames, CSV, Plots

# Load the data
data = CSV.read("Task1_1.csv", DataFrame)

p_real = CSV.read("WindFarmData.csv", DataFrame;  delim=';')
### IMPORTANT: df_DA is not with correct data ###
lambda_DA = CSV.read("DA_price.csv", DataFrame;  delim=';')


println(p_real)

m = Model(GLPK.Optimizer)

t = 1:length(p_real)

@variable(m, W[t])
@variable(m, t_up[t])
@variable(m, t_down[t])
@variable(m, t_delta[t])

@constraint(m, t_up[t] .>= 0)
@constraint(m, t_down[t] .>= 0)
@constraint(m, W[t] .>= 0)
@constraint(m, W[t] .<= 500)
@constraint(m, t_delta[t]= p_real[t] - W[t])
@constraint(m, t_delta[t] = t_up[t] - t_down[t])

@objective(m, Max, sum(lambda_DA[k]*W[k]+0.85*lambda_DA[k]*t_up[k]-1.25*lambda_DA[k]*t_down[k] for k in t)) 