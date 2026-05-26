
-- ============================================================
-- BUS32100 Final Project — SQL Analysis Script
-- Fertility Rate and Energy Consumption Analysis
-- Author: IDC
-- Database: SQLite (in-memory)
-- Tables: fertility (World Bank), energy (OWID), merged
-- ============================================================

-- Query 1: Global fertility trend by year
-- GROUP BY year to compute cross-country summary statistics
-- Shows the 34-year decline from avg 3.85 to 2.38
-- Requirement: GROUP BY (1 of 2 required)
SELECT
    year,
    COUNT(*)                            AS n_countries,
    ROUND(AVG(fertility_rate), 3)       AS avg_fertility,
    ROUND(MIN(fertility_rate), 3)       AS min_fertility,
    ROUND(MAX(fertility_rate), 3)       AS max_fertility,
    ROUND(MAX(fertility_rate) -
          MIN(fertility_rate), 3)       AS range_fertility
FROM fertility
WHERE is_aggregate = 0
  AND fertility_rate IS NOT NULL
GROUP BY year
ORDER BY year;

-- Query 2: Energy data coverage by year
-- Counts missing values per year using CASE WHEN inside SUM()
-- Confirms electricity coverage improved dramatically post-2000
-- fossil_share missing for ~63% of countries throughout (structural)
-- Requirement: GROUP BY (2 of 2 required)
SELECT
    year,
    COUNT(*)                                    AS total_rows,
    SUM(CASE WHEN energy_per_capita IS NULL
             THEN 1 ELSE 0 END)                 AS missing_energy,
    SUM(CASE WHEN per_capita_electricity IS NULL
             THEN 1 ELSE 0 END)                 AS missing_electricity,
    SUM(CASE WHEN fossil_share_energy IS NULL
             THEN 1 ELSE 0 END)                 AS missing_fossil,
    ROUND(100.0 * SUM(CASE WHEN energy_per_capita IS NULL
             THEN 1 ELSE 0 END) / COUNT(*), 1)  AS pct_missing_energy,
    ROUND(100.0 * SUM(CASE WHEN fossil_share_energy IS NULL
             THEN 1 ELSE 0 END) / COUNT(*), 1)  AS pct_missing_fossil
FROM energy
WHERE country_code IS NOT NULL
GROUP BY year
ORDER BY year;

-- Query 3: Core joined dataset (INNER JOIN)
-- Joins fertility and energy tables on country_code + year
-- Both keys must match simultaneously (composite join key)
-- Produces 6,846 rows across 204 countries, 1990-2023
-- This is the SQL equivalent of the Python merge in Section 2.6
-- Requirement: JOIN (1 of 3 required)
SELECT
    f.country_code,
    f.country_name,
    f.year,
    f.fertility_rate,
    f.life_expectancy,
    f.gdp_per_capita,
    e.energy_per_capita,
    e.per_capita_electricity,
    e.renewables_share_elec
FROM fertility    AS f
INNER JOIN energy AS e
    ON  f.country_code = e.country_code
    AND f.year         = e.year
WHERE f.is_aggregate = 0
  AND f.fertility_rate    IS NOT NULL
  AND e.energy_per_capita IS NOT NULL
ORDER BY f.country_name, f.year;

-- Query 4: Countries missing from energy dataset (LEFT JOIN)
-- Anti-join pattern: LEFT JOIN + WHERE right table IS NULL
-- Keeps ALL rows from fertility; fills NULLs where energy has no match
-- Identifies 11 small territories excluded from energy analysis
-- All have populations under 500,000 and poor data quality
-- Requirement: JOIN (2 of 3 required)
SELECT DISTINCT
    f.country_code,
    f.country_name
FROM fertility    AS f
LEFT JOIN energy  AS e
    ON f.country_code = e.country_code
WHERE f.is_aggregate  = 0
  AND e.country_code IS NULL
ORDER BY f.country_name;

-- Query 5: High energy, above-replacement outliers (INNER JOIN)
-- Finds countries simultaneously above median energy AND above
-- replacement fertility in 2022 — challenges the hypothesis
-- 18 countries found: dominated by oil-wealthy states and
-- cultural exceptions (Israel, Guam)
-- Requirement: JOIN (3 of 3 required)
SELECT
    f.country_name,
    f.year,
    ROUND(f.fertility_rate, 2)        AS fertility_rate,
    ROUND(f.gdp_per_capita, 0)        AS gdp_per_capita,
    ROUND(e.energy_per_capita, 0)     AS energy_per_capita,
    ROUND(e.renewables_share_elec, 1) AS renewables_share_elec
FROM fertility    AS f
INNER JOIN energy AS e
    ON  f.country_code = e.country_code
    AND f.year         = e.year
WHERE f.is_aggregate      = 0
  AND f.year              = 2022
  AND f.fertility_rate    > 2.1
  AND e.energy_per_capita > 14000
ORDER BY e.energy_per_capita DESC;

-- Query 6: Fertility ranking within each year (WINDOW FUNCTION - RANK)
-- RANK() OVER (PARTITION BY year ORDER BY fertility DESC)
-- PARTITION BY year restarts the ranking for each year
-- Unlike GROUP BY, all rows are kept -- rank added as new column
-- High-fertility top 5 dominated by same African cluster all decades
-- Low-fertility shifted from Southern Europe (1990) to East Asia (2022)
-- Requirement: Window function (1 of 2 required)
SELECT
    country_name,
    year,
    ROUND(fertility_rate, 2)    AS fertility_rate,
    RANK() OVER (
        PARTITION BY year
        ORDER BY fertility_rate DESC
    )                           AS fertility_rank
FROM fertility
WHERE is_aggregate   = 0
  AND fertility_rate IS NOT NULL
  AND year IN (1990, 2000, 2010, 2022)
ORDER BY year, fertility_rank;

-- Query 7: Year-over-year energy change per country (WINDOW FUNCTION - LAG)
-- LAG() retrieves the previous year value within each country partition
-- PARTITION BY country_code prevents comparing across countries
-- ORDER BY year ensures chronological processing
-- Reveals conflict collapse (Afghanistan -1,486 kWh in 1991),
-- resource booms (Qatar +107,580 kWh in 1992),
-- and industrial artifacts (US Virgin Islands refinery)
-- Requirement: Window function (2 of 2 required)
SELECT
    country_code,
    year,
    ROUND(energy_per_capita, 1)     AS energy_per_capita,
    ROUND(LAG(energy_per_capita) OVER (
        PARTITION BY country_code
        ORDER BY year
    ), 1)                           AS prev_year_energy,
    ROUND(energy_per_capita - LAG(energy_per_capita) OVER (
        PARTITION BY country_code
        ORDER BY year
    ), 1)                           AS energy_change_yoy
FROM energy
WHERE country_code IS NOT NULL
  AND energy_per_capita IS NOT NULL
ORDER BY country_code, year;

-- Query 8: Above-average energy AND below-replacement fertility (SUBQUERY)
-- Scalar subquery computes world average energy per capita for 2022
-- Outer query filters countries exceeding that threshold (24,568 kWh)
-- 58 of 117 below-replacement countries consume above-average energy
-- Spans full income spectrum: Qatar ($88,701) to Bosnia ($7,656)
-- Energy type irrelevant: Iceland 100% renewables vs Qatar 1.3%
-- Requirement: Subquery (1 of 2 required)
SELECT
    f.country_name,
    ROUND(f.fertility_rate, 2)          AS fertility_rate,
    ROUND(e.energy_per_capita, 0)       AS energy_per_capita,
    ROUND(f.gdp_per_capita, 0)          AS gdp_per_capita,
    ROUND(e.renewables_share_elec, 1)   AS renewables_pct
FROM fertility    AS f
INNER JOIN energy AS e
    ON  f.country_code = e.country_code
    AND f.year         = e.year
WHERE f.year           = 2022
  AND f.is_aggregate   = 0
  AND f.fertility_rate < 2.1
  AND e.energy_per_capita > (
        SELECT AVG(energy_per_capita)
        FROM energy
        WHERE year             = 2022
          AND energy_per_capita IS NOT NULL
  )
ORDER BY e.energy_per_capita DESC;

-- Query 9: Energy growth AND fertility decline 1990-2022 (SUBQUERY)
-- Self-joins compare each country to itself across 32 years
-- f1=1990 row, f2=2022 row joined on country_code
-- Same pattern for energy tables (e1=1990, e2=2022)
-- Subquery filters to countries with above-average energy growth
-- 25 countries show both trends simultaneously
-- Bhutan: +1,970% energy, -4.12 fertility -- standout case
-- India: -2.05 fertility, crossed below replacement around 2020
-- Requirement: Subquery (2 of 2 required)
SELECT
    f1.country_name,
    ROUND(f1.fertility_rate, 2)             AS fertility_1990,
    ROUND(f2.fertility_rate, 2)             AS fertility_2022,
    ROUND(f2.fertility_rate -
          f1.fertility_rate, 2)             AS fertility_change,
    ROUND(e1.energy_per_capita, 0)          AS energy_1990,
    ROUND(e2.energy_per_capita, 0)          AS energy_2022,
    ROUND(e2.energy_per_capita -
          e1.energy_per_capita, 0)          AS energy_change
FROM fertility AS f1
INNER JOIN fertility AS f2
    ON  f1.country_code = f2.country_code
    AND f2.year         = 2022
INNER JOIN energy AS e1
    ON  f1.country_code = e1.country_code
    AND e1.year         = 1990
INNER JOIN energy AS e2
    ON  f1.country_code = e2.country_code
    AND e2.year         = 2022
WHERE f1.year              = 1990
  AND f1.is_aggregate      = 0
  AND f2.fertility_rate    < f1.fertility_rate
  AND e2.energy_per_capita > e1.energy_per_capita
  AND (e2.energy_per_capita - e1.energy_per_capita) > (
        SELECT AVG(e_end.energy_per_capita - e_start.energy_per_capita)
        FROM energy AS e_start
        INNER JOIN energy AS e_end
            ON  e_start.country_code = e_end.country_code
            AND e_end.year           = 2022
        WHERE e_start.year              = 1990
          AND e_start.energy_per_capita IS NOT NULL
          AND e_end.energy_per_capita   IS NOT NULL
  )
ORDER BY fertility_change ASC
LIMIT 25;

-- Query 10: Energy and fertility by income group (GROUP BY + CASE WHEN)
-- CASE WHEN creates four income categories from continuous GDP
-- GROUP BY aggregates all metrics within each income category
-- HAVING excludes groups with fewer than 5 countries
-- Result: perfectly monotonic gradient across all metrics
-- 49x energy gap between low income (1,291 kWh) and
-- high income (63,186 kWh) groups
-- Renewables share flat across groups (~32-54%) confirming
-- energy TYPE does not vary with fertility -- only quantity
-- Requirement: GROUP BY + CASE WHEN + HAVING
SELECT
    CASE
        WHEN f.gdp_per_capita < 1500
            THEN '1. Low income (<$1,500)'
        WHEN f.gdp_per_capita < 7000
            THEN '2. Lower-middle ($1,500-$7,000)'
        WHEN f.gdp_per_capita < 25000
            THEN '3. Upper-middle ($7,000-$25,000)'
        ELSE
            '4. High income (>$25,000)'
    END                                     AS income_group,
    COUNT(DISTINCT f.country_name)          AS n_countries,
    ROUND(AVG(f.fertility_rate), 2)         AS avg_fertility,
    ROUND(AVG(e.energy_per_capita), 0)      AS avg_energy_per_capita,
    ROUND(AVG(e.per_capita_electricity), 0) AS avg_electricity,
    ROUND(AVG(e.renewables_share_elec), 1)  AS avg_renewables_pct,
    ROUND(AVG(f.life_expectancy), 1)        AS avg_life_expectancy,
    SUM(CASE WHEN f.fertility_rate < 2.1
             THEN 1 ELSE 0 END)             AS n_below_replacement
FROM fertility    AS f
INNER JOIN energy AS e
    ON  f.country_code = e.country_code
    AND f.year         = e.year
WHERE f.year               = 2022
  AND f.is_aggregate       = 0
  AND f.gdp_per_capita     IS NOT NULL
  AND e.energy_per_capita  IS NOT NULL
  AND f.fertility_rate     IS NOT NULL
GROUP BY income_group
HAVING COUNT(DISTINCT f.country_name) >= 5
ORDER BY income_group;
