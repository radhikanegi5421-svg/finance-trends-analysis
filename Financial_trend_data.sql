/* =====================================================================
   Project : Investor Behaviour & Finance Trends Analysis
   Author  : Radhika Negi
   Tool    : PostgreSQL
   Data    : Finance_Trends survey (12,000 responses, 24 columns)
   Goal    : Understand where people invest, why, and how they decide
   ===================================================================== */


---STEP 1: Create raw table and load data
   
DROP TABLE IF EXISTS finance_data;

CREATE TABLE finance_data (
    respondent_id       INT,
    gender              VARCHAR(50),
    age                 INT,
    investment_avenues  VARCHAR(100),
    mutual_funds        INT,      
    equity_market       INT,
    debentures          INT,
    government_bonds    INT,
    fixed_deposits      INT,
    ppf                 INT,
    gold                INT,
    stock_market        VARCHAR(100),
    factor              VARCHAR(100),
    objective           VARCHAR(100),
    purpose             VARCHAR(100),
    duration            VARCHAR(100),
    invest_monitor      VARCHAR(100),
    expect              VARCHAR(100),
    avenue              VARCHAR(100),
    savings_objective   VARCHAR(100),
    reason_equity       VARCHAR(100),
    reason_mutual       VARCHAR(100),
    reason_bonds        VARCHAR(100),
    reason_fd           VARCHAR(100),
    source              VARCHAR(100),
	age_group           VARCHAR(100)
);



---load data
COPY 
	finance_data (respondent_id, gender, age, investment_avenues, mutual_funds, equity_market, debentures, government_bonds, fixed_deposits,
	ppf, gold, stock_market, factor, objective, purpose,  duration, invest_monitor,  expect, avenue, savings_objective, reason_equity,
	reason_mutual, reason_bonds,  reason_fd,  source , age_group)
	FROM'C:\sql_data\Financial_trend_data.csv'
	DELIMITER','
	CSV HEADER ;
	
-- 2.1 Total rows
SELECT COUNT(*) AS total_rows FROM finance_data;

-- 2.2 NULL check on key columns
SELECT
    COUNT(*) FILTER (WHERE gender IS NULL)  AS null_gender,
    COUNT(*) FILTER (WHERE age IS NULL)     AS null_age,
    COUNT(*) FILTER (WHERE avenue IS NULL)  AS null_avenue,
    COUNT(*) FILTER (WHERE source IS NULL)  AS null_source
FROM finance_data;

-- 2.3 Exact duplicate rows (survey has no ID, so compare every column)
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY gender, age, investment_avenues,
           mutual_funds, equity_market, debentures, government_bonds,
           fixed_deposits, ppf, gold, stock_market, factor, objective, purpose,
           duration, invest_monitor, expect, avenue, savings_objective,
           reason_equity, reason_mutual, reason_bonds, reason_fd, source) AS rn
    FROM finance_data
) t
WHERE rn > 1;

-- 2.4 Age range sanity check
SELECT MIN(age) AS min_age, MAX(age) AS max_age, ROUND(AVG(age), 1) AS avg_age
FROM finance_data;



---   STEP 3: Clean table
--   - remove exact duplicates
--   - add respondent_id
--   - add age_group for segment analysis

DROP TABLE IF EXISTS finance_clean;

CREATE TABLE finance_clean AS
SELECT
    ROW_NUMBER() OVER () AS respondent_id,
    d.*,
    CASE
        WHEN age BETWEEN 18 AND 24 THEN '18-24'
        WHEN age BETWEEN 25 AND 29 THEN '25-29'
        WHEN age BETWEEN 30 AND 34 THEN '30-34'
        ELSE '35-38'
    END AS age_group
FROM (SELECT DISTINCT * FROM finance_data) d;

SELECT COUNT(*) AS rows_after_cleaning FROM finance_clean;   -- 10,389




-- Q1. Who are the respondents? (gender split)
SELECT
    gender,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM finance_clean
GROUP BY gender;

-- Q2. Which age group has the most investors?
SELECT
    age_group,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM finance_clean
GROUP BY age_group
ORDER BY age_group;

-- Q3. What share of people invest, and how many trade in the stock market?
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE investment_avenues = 'Yes') / COUNT(*), 1) AS pct_invest,
    ROUND(100.0 * COUNT(*) FILTER (WHERE stock_market = 'Yes') / COUNT(*), 1)       AS pct_stock_market
FROM finance_clean;

-- Q4. Most preferred investment avenue overall
SELECT
    avenue,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS popularity_rank
FROM finance_clean
GROUP BY avenue;

-- Q5. Average preference rank of each instrument (lower = more preferred)
SELECT instrument, ROUND(AVG(rank_given), 2) AS avg_rank
FROM finance_clean
CROSS JOIN LATERAL (VALUES
    ('PPF', ppf), ('Mutual Funds', mutual_funds), ('Equity Market', equity_market),
    ('Fixed Deposits', fixed_deposits), ('Government Bonds', government_bonds),
    ('Debentures', debentures), ('Gold', gold)
) AS v(instrument, rank_given)
GROUP BY instrument
ORDER BY avg_rank;

-- Q6. Which avenue do men and women prefer?
SELECT
    gender,
    avenue,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY gender), 1) AS pct_within_gender
FROM finance_clean
GROUP BY gender, avenue
ORDER BY gender, respondents DESC;

-- Q7. What matters most when choosing an investment?
SELECT
    factor,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM finance_clean
GROUP BY factor
ORDER BY respondents DESC;

-- Q8. What are people saving for?
SELECT
    savings_objective,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM finance_clean
GROUP BY savings_objective
ORDER BY respondents DESC;

-- Q9. Where do investors get information? (by age group)
SELECT
    age_group,
    source,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY age_group), 1) AS pct_within_age_group
FROM finance_clean
GROUP BY age_group, source
ORDER BY age_group, respondents DESC;

-- Q10. Investment horizon vs return expectation
SELECT
    duration,
    expect,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY duration), 1) AS pct_within_duration
FROM finance_clean
GROUP BY duration, expect
ORDER BY duration, expect;

-- Q11. How often do investors monitor their investments?
SELECT
    invest_monitor,
    COUNT(*) AS respondents,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM finance_clean
GROUP BY invest_monitor
ORDER BY respondents DESC;

-- Q12. Why do people choose equity / mutual funds / fixed deposits?
SELECT 'Equity' AS product, reason_equity AS reason, COUNT(*) AS respondents
FROM finance_clean GROUP BY reason_equity
UNION ALL
SELECT 'Mutual Fund', reason_mutual, COUNT(*)
FROM finance_clean GROUP BY reason_mutual
UNION ALL
SELECT 'Fixed Deposit', reason_fd, COUNT(*)
FROM finance_clean GROUP BY reason_fd
ORDER BY product, respondents DESC;


-- Q13. Top information source in each age group (CTE + RANK)
WITH source_counts AS (
    SELECT age_group, source, COUNT(*) AS respondents
    FROM finance_clean
    GROUP BY age_group, source
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY age_group ORDER BY respondents DESC) AS rnk
    FROM source_counts
)
SELECT age_group, source AS top_source, respondents
FROM ranked
WHERE rnk = 1
ORDER BY age_group;

-- Q14. Risk-focused vs return-focused investors: how do they differ?
SELECT
    factor,
    ROUND(AVG(age), 1) AS avg_age,
    ROUND(AVG(ppf), 2) AS avg_rank_ppf,
    ROUND(AVG(equity_market), 2) AS avg_rank_equity,
    ROUND(AVG(fixed_deposits), 2) AS avg_rank_fd
FROM finance_clean
WHERE factor IN ('Risk', 'Returns')
GROUP BY factor;

-- Q15. Share of each avenue within every age group
SELECT
    age_group,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avenue = 'Equity') / COUNT(*), 1)                 AS equity_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avenue = 'Mutual Fund') / COUNT(*), 1)            AS mutual_fund_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avenue = 'Fixed Deposits') / COUNT(*), 1)         AS fd_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE avenue = 'Public Provident Fund') / COUNT(*), 1)  AS ppf_pct
FROM finance_clean
GROUP BY age_group
ORDER BY age_group;