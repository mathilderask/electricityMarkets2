# removed from 1.4

function scenario_generator(no_of_scenarios)
#### Returns a random selection of defined number of scenarios in.
#### Returns 3 dataframes for the three variables where each column is corresponding data for a randomly selected scenario
#### Each dataframe has 24 rows for the 24 hours of the day
    scenarios_indices = randperm(length(scenario_ID))[1:no_of_scenarios]
    p_real_indices = scenarios_DF[scenarios_indices, 2]
    lambda_DA_indices = scenarios_DF[scenarios_indices, 3]
    system_status_indices = scenarios_DF[scenarios_indices, 4]

    # need it in dataframe format because otherwise it freaks out about indexing with duplicates
    p_real_cols = [p_real_DF[:, i+1] for i in p_real_indices]
    col_names = Symbol.("selected_scenario_", 1:length(p_real_cols))  # custom unique names
    p_real = DataFrame(p_real_cols, col_names)

    lambda_DA_cols = [lambda_DA_DF[:, i+1] for i in lambda_DA_indices]
    lambda_DA = DataFrame(lambda_DA_cols, col_names)

    system_status_cols = [system_status_DF[:, i+1] for i in system_status_indices]
    system_status = DataFrame(system_status_cols, col_names)

    global capacity = 500 # Installed capacity in MW
    p_real_matrix = Matrix(p_real) * capacity # scale for 500MW wind farm
    lambda_DA_matrix = Matrix(lambda_DA)
    system_status_matrix = Matrix(system_status)
    return p_real_matrix, lambda_DA_matrix, system_status_matrix
end



