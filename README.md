# Fertility Rate and Energy Consumption Analysis
### BUS32100 Final Project

## Overview
End-to-end data science project analyzing global fertility trends 
across 206 countries (1990–2023), integrating demographic data 
from the World Bank Indicators API with energy consumption data 
from Our World in Data.

## Research question
Is higher energy consumption associated with lower fertility rates, 
independently of economic development?

## Key findings
- Global median fertility fell from 3.44 (1990) to 1.98 (2023), 
  crossing the replacement rate around 2019
- Below-replacement countries consume 9× more energy per capita 
  than above-replacement countries (28,264 vs 3,111 kWh)
- Energy per capita correlates with fertility at ρ = −0.73, 
  comparable to GDP per capita (ρ = −0.76)
- Energy TYPE is irrelevant: renewables share shows ρ = 0.07 
  with fertility
- Simplified linear regression: R² = 0.71; 
  Logistic regression: AUC = 0.925

## Files
| File | Description |
|---|---|
| `BUS32100_Final_Fertility_Energy_IDC.ipynb` | Main analysis notebook |
| `fertility_energy_sql_queries.sql` | Standalone SQL script (10 queries) |
| `countries_processed.csv` | World Bank fertility dataset (processed) |
| `dfm_processed.csv` | Merged analytical dataset |
| `energy_processed.csv` | OWID energy dataset (processed) |

## Data sources
- **World Bank Indicators API** — `https://api.worldbank.org/v2/`
- **Our World in Data Energy Dataset** — 
  `https://github.com/owid/energy-data`

## Tools
Python (pandas, numpy, matplotlib, seaborn, scikit-learn, sqlite3), 
SQLite
