create database Petro;
use Petro;

create table data(
WellboreName VARCHAR(20),Year YEAR,Month INT,Onstream INT,Oil INT,
Gas INT, Water INT,Oil_Rate FLOAT,Water_Cut FLOAT,GOR FLOAT
);

SET FOREIGN_KEY_CHECKS = 0;
SET sql_mode = '';
LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/DataSet.csv"
INTO TABLE data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
SET FOREIGN_KEY_CHECKS = 1;

-- 1.Field-Level Yearly Production & Depletion Trends
SELECT 
    Year,
    SUM(Oil) AS Total_Field_Oil_m3,
    SUM(Gas) AS Total_Field_Gas_m3,
    SUM(Water) AS Total_Field_Water_m3,
    AVG(Water_Cut) * 100 AS Field_Avg_Water_Cut_Pct
FROM 
    data
GROUP BY 
    Year
ORDER BY 
    Year ASC;

-- 2.Well Ranking by Ultimate Recovery & Uptime
SELECT 
    WellboreName,
    SUM(Onstream) AS Total_Days_Online,
    SUM(Oil) AS Cumulative_Oil_m3,
    SUM(Gas) AS Cumulative_Gas_m3,
    (SUM(Water) / NULLIF(SUM(Oil) + SUM(Water), 0)) * 100 AS Lifetime_Water_Cut_Pct
FROM 
    data
GROUP BY 
    WellboreName
ORDER BY 
    Cumulative_Oil_m3 DESC;

-- 3. Identifying High-Risk Wells (Water Breakthrough & Gas Coning)
SELECT 
    WellboreName,
    Year,
    Month,
    Oil_Rate AS Avg_Daily_Oil_m3,
    Water_Cut * 100 AS Water_Cut_Pct,
    GOR AS Gas_Oil_Ratio
FROM 
    data
WHERE 
    Onstream > 15 
    AND (Water_Cut > 0.85 OR GOR > 250) 
ORDER BY 
    Year DESC, Month DESC, Water_Cut DESC;
    
-- 4. Month-over-Month Production Decline (Rate Transient Analysis Prep)
WITH Monthly_Rates AS (
    SELECT 
        WellboreName,
        Year,
        Month,
        Oil_Rate,
        LAG(Oil_Rate) OVER (PARTITION BY WellboreName ORDER BY Year, Month) AS Prev_Month_Rate
    FROM 
        data
    WHERE 
        Onstream > 20 
)
SELECT 
    WellboreName,
    Year,
    Month,
    Oil_Rate,
    Prev_Month_Rate,
    ROUND(((Oil_Rate - Prev_Month_Rate) / NULLIF(Prev_Month_Rate, 0)) * 100, 2) AS MoM_Rate_Change_Pct
FROM 
    Monthly_Rates
WHERE 
    Prev_Month_Rate IS NOT NULL
ORDER BY 
    WellboreName, Year, Month;    

-- 5. Operational Downtime Audit
SELECT 
    WellboreName,
    Year,
    Month,
    Onstream AS Days_Flowing,
    Oil,
    Water
FROM 
    data
WHERE 
    Onstream > 0 
    AND Onstream < 10
ORDER BY 
    Year DESC, Month DESC, Onstream ASC;
    
-- 6. The "Water-Out" Alarm (Crossing Economic Limits)
SELECT 
    WellboreName,
    Year,
    Month,
    Onstream AS Days_Active,
    ROUND(Water_Cut * 100, 2) AS Water_Cut_Percentage,
    CASE 
        WHEN Water_Cut >= 0.95 THEN 'CRITICAL: >95% Water'
        WHEN Water_Cut >= 0.90 THEN 'WARNING: >90% Water'
        ELSE 'Normal'
    END AS Well_Health_Status
FROM 
    data
WHERE 
    Onstream > 15 
    AND Water_Cut >= 0.90 
ORDER BY 
    Water_Cut DESC;