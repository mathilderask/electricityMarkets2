# Assignment 2
Renewables in Electricity Markets Assignment 2.
# Wind Farm Offering Strategy Optimization — Assignment 2 (Course 46755)

This repository contains the Julia code used for Assignment 2 of the DTU course **Renewables in Electricity Markets (46755)**. The objective is to develop and analyze optimal day-ahead offering strategies for a 500 MW wind farm under different market settlement schemes and risk preferences, using stochastic scenario-based optimization.

## 📁 Contents

| File | Description |
|------|-------------|
| `functions.jl` | Core functions for scenario generation, optimization, and profit evaluation. Used in all tasks |
| `Task1_1_and1_2.jl` | Solves the offering strategy problem under one- and two-price balancing schemes |
| `Task1_3.jl` | Performs 8-fold cross-validation for in-sample vs. out-of-sample profit analysis |
| `Task1_4_Risk.jl` | Implements a CVaR-based risk-averse offering strategy |
| `Task2_1&2_ALSOX.jl` | Reserve capacity optimization using the ALSO-X model |
| `Task2_1&2_CVaR.jl` | Reserve capacity optimization using CVaR |
| `Task2_2.jl` | Validates P90 compliance using out-of-sample data |
| `Task2_3.jl` | Analyzes impact of varying the P-threshold on optimal reserve bids |

## 📂 Required Input Data

These CSV files must be placed in the same directory:

- `windscenarios_zone2.csv` – Hourly wind production scenarios
- `DA_hourly_price_scenarios.csv` – Hourly day-ahead price scenarios (DK2)
- `power_system_conditions.csv` – Binary indicator of system status (deficit/excess)
- `scenario_combinations.csv` – Index matrix combining scenario components
- `Stochastic_Load_Profiles.csv` – Minute-level flexible load profiles for reserve market tasks

## ▶️ How to Run the Code

1. Install Julia (v1.7 or higher).
2. Install required packages:

```julia
using Pkg
Pkg.add("JuMP")
Pkg.add("HiGHS")
Pkg.add("CSV")
Pkg.add("DataFrames")
Pkg.add("PyPlot")
Pkg.add("Random")
Pkg.add("Statistics")