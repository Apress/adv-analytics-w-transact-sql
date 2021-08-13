-- Advanced Analytics with Transact-SQL
-- Chapter 06: Time-Oriented Analyses  

/* 1) Time-Oriented Analyses
	  Demo Data
   2) Exponential Moving Averages
      Calculating EMA Efficiently
      Forecasting with EMA
   3) ABC Analysis
      Relational Division
	  Top Customers and Products
   4) Duration of Loyalty
      Survival Analysis
	  Hazard Analysis
 */

/* Time-Oriented Analyses */

-- Demo data
USE AdventureWorksDW2017;
GO

-- Finding orders distribution by year of the order date
WITH od AS
(
SELECT OrderDate
FROM dbo.FactInternetSales
UNION ALL 
SELECT OrderDate
FROM dbo.FactResellerSales
)
SELECT YEAR(OrderDate) AS OrderYear, 
  MIN(OrderDate) AS minO, 
  MAX(OrderDate) AS maxO,
  COUNT(*) AS NumOrders
FROM od
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
-- Very few orders in years 2010 (dec only) and 2014 (jan only)

-- Views for orders without years 2010 and 2014
DROP VIEW IF EXISTS dbo.vInternetSales;
GO
CREATE VIEW dbo.vInternetSales
AS
SELECT *
FROM dbo.FactInternetSales
WHERE YEAR(OrderDate) BETWEEN 2011 AND 2013;
GO
DROP VIEW IF EXISTS dbo.vResellersales;
GO
CREATE VIEW dbo.vResellerSales
AS
SELECT *
FROM dbo.FactResellerSales
WHERE YEAR(OrderDate) BETWEEN 2011 AND 2013;
GO
-- Check the data
WITH od AS
(
SELECT OrderDate
FROM dbo.vInternetSales
UNION ALL 
SELECT OrderDate
FROM dbo.vResellerSales
)
SELECT YEAR(OrderDate) AS OrderYear, 
  MIN(OrderDate) AS minO, 
  MAX(OrderDate) AS maxO,
  COUNT(*) AS NumOrders
FROM od
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
GO


/* Exponential Moving Averages */

-- Time series
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(1.0*Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
GROUP BY TimeIndex
)
SELECT TimeIndex, Quantity
FROM TSAggCTE
ORDER BY TimeIndex;
GO

-- Exponential - cursor
DECLARE @CurrentEMA AS FLOAT, @PreviousEMA AS FLOAT, 
 @t AS INT, @q AS FLOAT,
 @A AS FLOAT;
DECLARE @EMA AS TABLE(TimeIndex INT, Quantity FLOAT, EMA FLOAT);
SET @A = 0.7;

DECLARE EMACursor CURSOR FOR 
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(1.0*Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
GROUP BY TimeIndex
)
SELECT TimeIndex, Quantity
FROM TSAggCTE
ORDER BY TimeIndex;

OPEN EMACursor;

FETCH NEXT FROM EMACursor 
 INTO @t, @q;
SET @CurrentEMA = @q;
SET @PreviousEMA = @CurrentEMA;

WHILE @@FETCH_STATUS = 0
BEGIN
 SET @CurrentEMA = @A*@q + (1-@A)*@PreviousEMA;
 INSERT INTO @EMA (TimeIndex, Quantity, EMA)
  VALUES(@t, @q, @CurrentEMA);
  SET @PreviousEMA = @CurrentEMA;
 FETCH NEXT FROM EMACursor 
  INTO @t, @q;
END;

CLOSE EMACursor;
DEALLOCATE EMACursor;

SELECT TimeIndex, Quantity, EMA
FROM @EMA;
GO

-- Calculating EMA efficiently
-- Calculating the exponent
DECLARE @A AS FLOAT = 0.7, @B AS FLOAT;
SET @B = 1 - @A; 
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(1.0*Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier
GROUP BY TimeIndex
),
EMACTE AS
(
SELECT TimeIndex, Quantity,
  ROW_NUMBER() OVER (ORDER BY TimeIndex) - 1 AS Exponent 
FROM TSAggCTE
) 
SELECT TimeIndex, Quantity, Exponent
FROM EMACTE;
GO

-- Full query
DECLARE @A AS FLOAT = 0.7;
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(1.0*Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier
GROUP BY TimeIndex
),
EMACTE AS
(
SELECT TimeIndex, Quantity,
  ROW_NUMBER() OVER (ORDER BY TimeIndex) - 1 AS Exponent 
FROM TSAggCTE
) 
SELECT TimeIndex, Quantity, 
 ROUND(
  SUM(CASE WHEN Exponent = 0 THEN 1 
           ELSE @A 
	  END 
	  * POWER((1 - @A), -Exponent) 
	  * Quantity 
	 )
  OVER (ORDER BY TimeIndex) 
  * POWER((1 - @A), Exponent)
 , 2) AS EMA 
FROM EMACTE; 
GO


-- Forecating with EMA
-- Storing the results of the previous query in a table
DROP TABLE IF EXISTS dbo.EMA;
DECLARE @A AS FLOAT = 0.7;
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 CAST(SUM(1.0*Quantity*2) - 200 AS FLOAT) AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    
GROUP BY TimeIndex
),
EMACTE AS
(
SELECT TimeIndex, Quantity,
  ROW_NUMBER() OVER (ORDER BY TimeIndex) - 1 AS Exponent 
FROM TSAggCTE
) 
SELECT 
 ROW_NUMBER() OVER(ORDER BY TimeIndex) AS TimeRN,
 TimeIndex, Quantity, 
 ROUND(
  SUM(CASE WHEN Exponent = 0 THEN 1 
           ELSE @A 
	  END 
	  * POWER((1 - @A), -Exponent) 
	  * Quantity 
	 )
  OVER (ORDER BY TimeIndex) 
  * POWER((1 - @A), Exponent)
 , 2) AS EMA 
INTO dbo.EMA
FROM EMACTE; 
GO

-- Selecting the last row
DECLARE @t AS INT,  @v AS FLOAT, @e AS FLOAT;
DECLARE @A AS FLOAT = 0.7, @r AS INT = 36;
SELECT @t = TimeIndex, @v = Quantity, @e = EMA
FROM dbo.EMA
WHERE TimeIndex =
      (SELECT MAX(TimeIndex) FROM dbo.EMA);
-- SELECT @t, @v, @e;
-- First forecast time point
SET @t = 201401;
SET @r = 37;
-- Forecasting in a loop
WHILE @t <= 201406
BEGIN
 SET @v = ROUND(@A * @v + (1 - @A) * @e, 2);
 SET @e = ROUND(@A * @v + (1 - @A) * @e, 2);
 INSERT INTO dbo.EMA
 SELECT @r, @t, @v, @e;
 SET @t += 1;
 SET @r += 1;
END
SELECT TimeRN, TimeIndex, Quantity, EMA
FROM dbo.EMA
ORDER BY TimeIndex;
GO



/* ABC Analysis */

-- Relational division
-- Product categories
SELECT ProductCategoryKey, EnglishProductCategoryName
FROM dbo.DimProductCategory;
GO

-- Customers and number of distinct product categories they purchased
SELECT s.CustomerKey AS cid,
  COUNT(DISTINCT pc.EnglishProductCategoryName) AS cnt
FROM dbo.FactInternetSales AS s
 INNER JOIN dbo.DimProduct AS p
  ON p.ProductKey = s.ProductKey
 INNER JOIN dbo.DimProductSubcategory AS ps
  ON ps.ProductSubcategoryKey = p.ProductSubcategoryKey
 INNER JOIN dbo.DimProductCategory AS pc
  ON pc.ProductCategoryKey = ps.ProductCategoryKey
WHERE pc.EnglishProductCategoryName <> N'Components'   
GROUP BY s.CustomerKey
ORDER BY s.CustomerKey;

-- Customers who purchased products from all categories
SELECT s.CustomerKey AS cid,
  MIN(c.LastName + N', ' + c.FirstName) AS cnm
FROM dbo.FactInternetSales AS s
 INNER JOIN dbo.DimProduct AS p
  ON p.ProductKey = s.ProductKey
 INNER JOIN dbo.DimProductSubcategory AS ps
  ON ps.ProductSubcategoryKey = p.ProductSubcategoryKey
 INNER JOIN dbo.DimProductCategory AS pc
  ON pc.ProductCategoryKey = ps.ProductCategoryKey
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = s.CustomerKey
WHERE pc.EnglishProductCategoryName <> N'Components'
GROUP BY s.CustomerKey
HAVING COUNT(DISTINCT pc.EnglishProductCategoryName) =
  (SELECT COUNT(*) FROM dbo.DimProductCategory
   WHERE EnglishProductCategoryName <> N'Components')   
ORDER BY s.CustomerKey;
GO

-- Adding the time
SELECT s.CustomerKey AS cid,
  MIN(c.LastName + N', ' + c.FirstName) AS cnm
FROM dbo.FactInternetSales AS s
 INNER JOIN dbo.DimProduct AS p
  ON p.ProductKey = s.ProductKey
 INNER JOIN dbo.DimProductSubcategory AS ps
  ON ps.ProductSubcategoryKey = p.ProductSubcategoryKey
 INNER JOIN dbo.DimProductCategory AS pc
  ON pc.ProductCategoryKey = ps.ProductCategoryKey
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = s.CustomerKey
 INNER JOIN dbo.DimDate AS d
  ON d.DateKey = s.OrderDateKey
WHERE pc.EnglishProductCategoryName <> N'Components'
  AND YEAR(d.FullDateAlternateKey) = 2012
GROUP BY s.CustomerKey
HAVING COUNT(DISTINCT pc.EnglishProductCategoryName) =
  (SELECT COUNT(*) FROM dbo.DimProductCategory
   WHERE EnglishProductCategoryName <> N'Components')   
ORDER BY s.CustomerKey;
GO


-- Top customers and products
-- Customers frequencies by number of order lines
WITH freqCTE AS
(
SELECT CustomerKey AS cid,
 COUNT(*) AS abf,
 CAST(ROUND(100. * (COUNT(*)) /
       (SELECT COUNT(*) FROM dbo.vInternetSales), 5)
	   AS NUMERIC(8,5)) AS abp
FROM dbo.vInternetSales
GROUP BY CustomerKey
)
SELECT cid,
 abf,
 SUM(abf) 
  OVER(ORDER BY abf DESC 
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS cuf,
 abp,
 CAST(REPLICATE('*', ROUND(100 * abp, 0)) AS VARCHAR(50)) AS hst,
 SUM(abp)
  OVER(ORDER BY abf DESC
       ROWS BETWEEN UNBOUNDED PRECEDING
        AND CURRENT ROW) AS cup
FROM freqCTE
ORDER BY abf DESC;

-- Top product models
-- Product models ranked by sales amount
WITH psalesCTE AS
(
SELECT ProductKey AS pid, SalesAmount AS sls
FROM dbo.vInternetSales
UNION 
SELECT ProductKey, SalesAmount
FROM dbo.vResellerSales
),
psalsaggCTE AS
(
SELECT P.ModelName AS pmo, 
 SUM(s.sls) AS sls
FROM psalesCTE AS s
 INNER JOIN dbo.DimProduct AS p
  ON s.pid = p.ProductKey
GROUP BY P.ModelName
)
SELECT pmo, 
 ROUND(sls, 2) AS sls,
 RANK() OVER(ORDER BY sls DESC) AS rnk,
 SUM(ROUND(sls, 2)) OVER(ORDER BY sls DESC) runtot,
 ROUND( 100 * 
  SUM(sls) OVER(ORDER BY sls DESC) /
  SUM(sls) OVER(), 2) AS runpct
FROM psalsaggCTE
ORDER BY sls DESC;


/* Duration of Loyalty */

-- Customers that were not active in the last year
SELECT s.CustomerKey AS cid, 
 MIN(c.LastName + N', ' + c.FirstName) AS cnm,
 MAX(CAST(s.OrderDate AS DATE)) AS lod,
 DATEDIFF(day, MAX(s.OrderDate),
 (SELECT DATEADD(year, -1, MAX(OrderDate)) + 1 
  FROM dbo.vInternetSales)) AS ddif
FROM dbo.vInternetSales AS s
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = s.CustomerKey
GROUP BY s.CustomerKey
HAVING MAX(s.OrderDate) < 
 (SELECT DATEADD(year, -1, MAX(OrderDate)) + 1 
  FROM dbo.vInternetSales)
ORDER BY lod;

-- Customers that stopped purchasing after some cutoff date
SELECT i.CustomerKey AS cid,
 MIN(c.LastName + N', ' + c.FirstName) AS cnm,
 CAST(MIN(i.OrderDate) AS DATE) AS startDate,
 CAST(MAX(i.OrderDate) AS DATE) AS stopDate,
 DATEDIFF(day, MIN(i.OrderDate), MAX(i.OrderDate)) AS tenureDays
FROM dbo.vInternetSales AS i
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = i.CustomerKey
GROUP BY i.CustomerKey
HAVING MAX(i.OrderDate) < '20130301'
   AND DATEDIFF(day, MIN(i.OrderDate), MAX(i.OrderDate)) > 0
ORDER BY tenureDays DESC;
-- 414 customers had more than one order and no purchase after 20130228
-- Define those as succumbed to risk, not customers anymore

-- Survival analysis
-- Creating a table for the survival analysis
-- Part 1: customers succumbed to risk
-- Adding also the reason 
-- Making 1/3 invountary and 2/3 voluntary
DROP TABLE IF EXISTS dbo.CustomerSurvival;
SELECT i.CustomerKey AS cId,
 MIN(c.LastName + N', ' + c.FirstName) AS cName,
 CAST(MIN(i.OrderDate) AS DATE) AS startDate,
 CAST(MAX(i.OrderDate) AS DATE) AS stopDate,
 DATEDIFF(day, MIN(i.OrderDate), MAX(i.OrderDate)) AS tenureDays,
 CASE WHEN i.CustomerKey % 3 = 0 THEN MIN(N'I') -- involuntary
      ELSE MIN(N'V')                            -- voluntary
 END AS stopReason    
INTO dbo.CustomerSurvival
FROM dbo.vInternetSales AS i
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = i.CustomerKey
GROUP BY i.CustomerKey
HAVING MAX(i.OrderDate) < '20130301'
   AND DATEDIFF(day, MIN(i.OrderDate), MAX(i.OrderDate)) > 0;
-- 414

-- Part 2: Inserting active customers
INSERT INTO dbo.CustomerSurvival
SELECT i.CustomerKey AS cId,
 MIN(c.LastName + N', ' + c.FirstName) AS cName,
 CAST(MIN(i.OrderDate) AS DATE) AS startDate,
 NULL AS stopDate,
 DATEDIFF(day, MIN(i.OrderDate), '20130228') AS tenureDays,
 NULL AS stopReason    
FROM dbo.vInternetSales AS i
 INNER JOIN dbo.DimCustomer AS c
  ON c.CustomerKey = i.CustomerKey
WHERE i.CustomerKey NOT IN
 (SELECT cId FROM dbo.CustomerSurvival)
GROUP BY i.CustomerKey
HAVING MIN(i.OrderDate) < '20130301';
GO
-- 6442

-- Adding the PK and checking the data
ALTER TABLE dbo.customerSurvival ADD CONSTRAINT PK_CustSurv
 PRIMARY KEY (cId);
GO
SELECT *
FROM dbo.CustomerSurvival
ORDER BY NEWID();
SELECT MIN(startDate), MAX(startDate),
 MIN(stopDate), MAX(stopDate)
FROM dbo.CustomerSurvival;
GO

-- Survival: customers that survived at least 365 days
SELECT 365 AS tenureCutoff,
 COUNT(*) AS populationAtRisk,
 SUM(CASE WHEN tenureDays < 365 AND stopReason IS NOT NULL 
     THEN 1 ELSE 0 END) AS succIn1Year,
 SUM(CASE WHEN tenureDays >= 365 AND stopReason IS NOT NULL 
     THEN 1 ELSE 0 END) AS succAfter1Year,
 SUM(CASE WHEN tenureDays >= 365 AND stopReason IS NULL 
     THEN 1 ELSE 0 END) AS numActive,
 CAST(
  ROUND(
   AVG(CASE WHEN tenureDays >= 365 AND stopReason IS NULL 
       THEN 100.0 ELSE 0 END), 2)
  AS NUMERIC(5,2)) AS pctActive
FROM dbo.CustomerSurvival
WHERE startDate <= DATEADD(day, -365, '20130228');
GO


-- Hazard analysis

-- Hazard probability up to 365 days
SELECT 365 AS tenureCutoff,
 COUNT(*) AS populationAtRisk,
 SUM(CASE WHEN tenureDays <= 365 AND stopReason IS NOT NULL 
     THEN 1 ELSE 0 END) AS succumbedToRisk,
 CAST(
  ROUND(
   AVG(CASE WHEN tenureDays <= 365 AND stopReason IS NOT NULL 
       THEN 100.0 ELSE 0 END)
   , 2)
  AS NUMERIC(5,2)) AS pctSuccumbed
FROM dbo.CustomerSurvival;

-- Hazard for every single tenure length in days
SELECT tenureDays, 
 COUNT(*) AS populationAtRisk,
 SUM(CASE WHEN stopReason IS NOT NULL 
     THEN 1 ELSE 0 END) AS succumbedAtTenure
FROM dbo.CustomerSurvival
GROUP BY tenureDays
ORDER BY succumbedAtTenure DESC;

-- Cumulative hazard and survival
WITH tenCTE AS
(
SELECT tenureDays, 
 COUNT(*) AS popAtRisk,
 SUM(CASE WHEN stopReason IS NOT NULL 
     THEN 1 ELSE 0 END) AS succAtTenure
FROM dbo.CustomerSurvival
GROUP BY tenureDays
)
SELECT tenureDays,
 popAtRisk,
 SUM(popAtRisk) OVER() AS totPop,
 succAtTenure,
 SUM(succAtTenure)
  OVER(ORDER BY tenureDays
       ROWS BETWEEN UNBOUNDED PRECEDING 
	   AND CURRENT ROW) AS succUpToTenure,
 SUM(100.0 * succAtTenure)
  OVER(ORDER BY tenureDays
       ROWS BETWEEN UNBOUNDED PRECEDING 
	   AND CURRENT ROW) /
 SUM(popAtRisk) OVER() AS pctSuccUpToTenure,
 SUM(popAtRisk) OVER() - 
 SUM(succAtTenure)
  OVER(ORDER BY tenureDays
       ROWS BETWEEN UNBOUNDED PRECEDING 
	   AND CURRENT ROW) AS survUpToTenure,
 100.0 - 
 SUM(100.0 * succAtTenure)
  OVER(ORDER BY tenureDays
       ROWS BETWEEN UNBOUNDED PRECEDING 
	   AND CURRENT ROW) /
 SUM(popAtRisk) OVER() AS pctSurvUpToTenure
FROM tenCTE
ORDER BY tenureDays;
GO


-- Analysis of the customers that succumbed to risk
-- Part 1: By stop reason
SELECT c.stopReason,
 COUNT(DISTINCT i.SalesOrderNumber) AS cntOrders,
 COUNT(*) AS cntOrderDetals,
 SUM(i.SalesAmount - i.TotalProductCost) AS profitTot,
 100 * SUM(i.SalesAmount - i.TotalProductCost) / SUM(i.SalesAmount) AS profitPct
FROM dbo.CustomerSurvival AS c
 INNER JOIN dbo.vInternetSales AS i
  ON c.cId = i.CustomerKey
WHERE c.stopReason IS NOT NULL
GROUP BY c.stopReason;

-- Part 2: By region and number of cars owned
SELECT v.NumberCarsOwned, v.Region,
 COUNT(DISTINCT i.SalesOrderNumber) AS cntOrders,
 COUNT(*) AS cntOrderDetals,
 SUM(i.SalesAmount) AS amountTot,
 SUM(i.SalesAmount - i.TotalProductCost) AS profitTot,
 100 * SUM(i.SalesAmount - i.TotalProductCost) / SUM(i.SalesAmount) AS profitPct
FROM dbo.CustomerSurvival AS c
 INNER JOIN dbo.vInternetSales AS i
  ON c.cId = i.CustomerKey
 INNER JOIN dbo.vTargetMail AS v
  ON c.cId = v.CustomerKey
WHERE c.stopReason IS NOT NULL
GROUP BY v.NumberCarsOwned, v.Region
ORDER BY v.NumberCarsOwned, v.Region;

-- Part 3: By region and number of cars owned pivoted
SELECT NumberCarsOwned,
 [Europe], [North America], [Pacific]
FROM
(SELECT v.NumberCarsOwned, v.Region,
  i.SalesAmount
 FROM dbo.CustomerSurvival AS c
  INNER JOIN dbo.vInternetSales AS i
   ON c.cId = i.CustomerKey
  INNER JOIN dbo.vTargetMail AS v
   ON c.cId = v.CustomerKey
 WHERE c.stopReason IS NOT NULL) AS p
 PIVOT (SUM(SalesAmount) FOR Region
    IN ([Europe], [North America], [Pacific])) AS p
ORDER BY NumberCarsOwned;
GO


-- Clean up
USE AdventureWorksDW2017;
DROP TABLE IF EXISTS dbo.EMA;
DROP VIEW IF EXISTS dbo.vInternetSales;
DROP VIEW IF EXISTS dbo.vResellersales;
DROP TABLE IF EXISTS dbo.CustomerSurvival;
GO
