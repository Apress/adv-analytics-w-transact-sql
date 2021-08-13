-- Advanced Analytics with Transact-SQL
-- Chapter 07: Data Mining


/*
1)	Linear Regression
    Autoregression and Forecasting
2)	Market basket analysis
    Starting from the Negative Side
3)	Look-alike model
    Training and Test Data Sets
	Performing Predictions with LAM
4)	Naive Bayes
    Training the NB Model
	Performing Predictions with NB
*/

-- Demo data
USE AdventureWorksDW2017;
GO

-- Line items and orders
SELECT TOP 5 *
FROM dbo.vAssocSeqLineItems;
SELECT TOP 5 *
FROM dbo.vAssocSeqOrders;
GO

-- Creating a permanent table from dbo.vAssocSeqLineItems
DROP TABLE IF EXISTS dbo.tAssocSeqLineItems;
SELECT *
INTO dbo.tAssocSeqLineItems
FROM dbo.vAssocSeqLineItems;
GO
-- PK
ALTER TABLE dbo.tAssocSeqLineItems ADD CONSTRAINT PK_LI
 PRIMARY KEY CLUSTERED (OrderNumber, LineNumber);
GO

-- Creating a permanent table from dbo.vAssocSeqOrders
DROP TABLE IF EXISTS dbo.tAssocSeqOrders;
SELECT *
INTO dbo.tAssocSeqOrders
FROM dbo.vAssocSeqOrders;
GO
-- PK
ALTER TABLE dbo.tAssocSeqOrders ADD CONSTRAINT PK_O
 PRIMARY KEY CLUSTERED (OrderNumber);
GO

-- TargetMail
SELECT CommuteDistance, Region, 
 YearlyIncome, NumberCarsOwned,
 BikeBuyer
FROM dbo.vTargetMail
ORDER BY NEWID();
GO


-- Linear regression
WITH CoVarCTE AS
(
SELECT dispcc/100 as val1,
 AVG(dispcc/100) OVER () AS mean1,
 l100km AS val2,
 AVG(l100km) OVER() AS mean2
FROM dbo.mtcars
)
SELECT Slope =
        SUM((val1 - mean1) * (val2 - mean2))
        /SUM(SQUARE((val1 - mean1))),
       Intercept =
         MIN(mean2) - MIN(mean1) *
           (SUM((val1 - mean1)*(val2 - mean2))
            /SUM(SQUARE((val1 - mean1))))
FROM CoVarCTE;
GO


-- Forecating with EMA and linear regression
-- Storing the results in a table
DROP TABLE IF EXISTS dbo.EMA;
DECLARE @A AS FLOAT = 0.7;
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 CAST(SUM(1.0*Quantity*2) - 200 AS FLOAT) AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
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
 , 2) AS EMA,
 ROUND(CAST(0 AS FLOAT), 2) AS LR,
 CAST('Actual' AS CHAR(8)) AS ValueType
INTO dbo.EMA
FROM EMACTE; 
GO

-- Linear regression - using last 12 points only
DECLARE @Slope AS FLOAT, @Intercept AS FLOAT;
WITH CoVarCTE AS
(
SELECT 1.0*TimeRN as val1,
 AVG(1.0*TimeRN) OVER () AS mean1,
 1.0*Quantity AS val2,
 AVG(1.0*Quantity) OVER() AS mean2
FROM dbo.EMA
WHERE TimeRN BETWEEN 25 AND 36
)
SELECT @Slope =
        SUM((val1 - mean1) * (val2 - mean2))
        /SUM(SQUARE((val1 - mean1))),
       @Intercept =
         MIN(mean2) - MIN(mean1) *
           (SUM((val1 - mean1)*(val2 - mean2))
            /SUM(SQUARE((val1 - mean1))))
FROM CoVarCTE;
-- Updating last 12 rows
UPDATE dbo.EMA
   SET LR = ROUND(TimeRN * @Slope + @Intercept, 2)
WHERE TimeRN BETWEEN 25 AND 36;
-- Selecting the last row
DECLARE @t AS INT,  @v AS FLOAT, 
        @e AS FLOAT, @l AS FLOAT;
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
 SET @l = ROUND(@r * @Slope + @Intercept, 2);
 INSERT INTO dbo.EMA
 SELECT @r, @t, @v, @e, @l, 'Forecast';
 SET @t += 1;
 SET @r += 1;
END
SELECT TimeRN, TimeIndex, 
 Quantity, EMA, LR,
 ValueType
FROM dbo.EMA
ORDER BY TimeIndex;
GO


-- Association Rules
-- Frequency of itemsets with a single model
SELECT Model, COUNT(*) AS Support
FROM dbo.tAssocSeqLineItems
GROUP BY Model
ORDER BY Support DESC;
GO

-- Starting from the Negative Side
-- Which models have been purchased only once in a single order
-- Part 1: Customers bought the model and never anything else
WITH mdlCTE AS
(
SELECT o.CustomerKey AS cid, 
 MIN(i.Model) AS mdl,
 COUNT(DISTINCT i.OrderNumber) AS distor,
 COUNT(DISTINCT i.Model) AS distit
FROM dbo.tAssocSeqLineItems AS i
 INNER JOIN dbo.tAssocSeqOrders AS o
  ON i.OrderNumber = o.OrderNumber
GROUP BY o.CustomerKey
HAVING
 COUNT(DISTINCT i.OrderNumber) = 1 AND
 COUNT(DISTINCT i.Model) = 1
)
SELECT mdl AS Product, COUNT(*) AS Cnt
FROM mdlCTE
GROUP BY mdl
ORDER BY cnt DESC;
GO

-- Pivoting by region
WITH mdlCTE AS
(
SELECT MIN(o.Region) AS reg,
 MIN(i.Model) AS mdl,
 COUNT(DISTINCT i.Model) AS distit
FROM dbo.tAssocSeqLineItems AS i
 INNER JOIN dbo.tAssocSeqOrders AS o
  ON i.OrderNumber = o.OrderNumber
GROUP BY o.CustomerKey
HAVING
 COUNT(DISTINCT i.OrderNumber) = 1 AND
 COUNT(DISTINCT i.Model) = 1
)
SELECT mdl AS Model, 
 ISNULL([Europe], 0) AS Europe, 
 ISNULL([North America], 0) AS NorthAm, 
 ISNULL([Pacific], 0) AS Pacific
FROM mdlCTE
 PIVOT (SUM(distit) FOR reg
    IN ([Europe], [North America], [Pacific])) AS p
ORDER BY ISNULL([Europe], 0) + 
         ISNULL([North America], 0) +
		 ISNULL([Pacific], 0) DESC;
-- Pivoting by income group
WITH mdlCTE AS
(
SELECT MIN(o.IncomeGroup) AS reg,
 MIN(i.Model) AS mdl,
 COUNT(DISTINCT i.Model) AS distit
FROM dbo.tAssocSeqLineItems AS i
 INNER JOIN dbo.tAssocSeqOrders AS o
  ON i.OrderNumber = o.OrderNumber
GROUP BY o.CustomerKey
HAVING
 COUNT(DISTINCT i.OrderNumber) = 1 AND
 COUNT(DISTINCT i.Model) = 1
)
SELECT mdl AS Model, 
 ISNULL([Low], 0) AS LowIncome, 
 ISNULL([Moderate], 0) AS ModerateIncome, 
 ISNULL([High], 0) AS HighIncome
FROM mdlCTE
 PIVOT (SUM(distit) FOR reg
    IN ([Low], [Moderate], [High])) AS p
ORDER BY ISNULL([Low], 0) + 
         ISNULL([Moderate], 0) +
		 ISNULL([High], 0) DESC;
GO

-- Frequency of itemsets with two models
-- Using JOIN
SELECT t1.Model AS Model1, 
 t2.Model AS Model2,
 COUNT(*) AS Support
FROM dbo.tAssocSeqLineItems AS t1
 INNER JOIN dbo.tAssocSeqLineItems AS t2
  ON t1.OrderNumber = t2.OrderNumber
     AND t1.Model > t2.Model
GROUP BY t1.Model, t2.Model
ORDER BY Support DESC;
-- Using APPLY
WITH Pairs_CTE AS
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND Model > t1.Model) AS t2
)
SELECT Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
ORDER BY Support DESC;
GO

-- Frequency of itemsets with three models
WITH Pairs_CTE AS
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND Model > t1.Model) AS t2
),
Triples_CTE AS
(
SELECT t2.OrderNumber,
 t2.Model1, 
 t2.Model2,
 t3.Model3
FROM Pairs_CTE AS t2
 CROSS APPLY 
  (SELECT Model AS Model3
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t2.OrderNumber
     AND Model > t2.Model1
	 AND Model > t2.Model2) AS t3
)
SELECT Model1, Model2, Model3, COUNT(*) AS Support
FROM Triples_CTE
GROUP BY Model1, Model2, Model3
ORDER BY Support DESC;
GO

-- Association rules
-- Basic rules
WITH Pairs_CTE AS   -- All possible pairs
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND Model <> t1.Model) AS t2
)
SELECT Model1 + N' ---> ' + Model2 AS theRule,
 Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
ORDER BY Support DESC;
GO

-- Adding confidence 
WITH Pairs_CTE AS   -- All possible pairs
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND Model <> t1.Model) AS t2
),
rulesCTE AS
(
SELECT Model1 + N' ---> ' + Model2 AS theRule,
 Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
),
cntModelCTE AS
(
SELECT Model,
 COUNT(DISTINCT OrderNumber) AS ModelCnt
FROM dbo.tAssocSeqLineItems
GROUP BY Model
)
SELECT r.theRule,
 r.Support,
 CAST(100.0 * r.Support / a.numOrders AS NUMERIC(5, 2))
  AS SupportPct,
 CAST(100.0 * r.Support / c1.ModelCnt AS NUMERIC(5, 2))
  AS Confidence
FROM rulesCTE AS r 
 INNER JOIN cntModelCTE AS c1
  ON r.Model1 = c1.Model
 CROSS JOIN (SELECT COUNT(DISTINCT OrderNumber) 
             FROM dbo.tAssocSeqLineItems) AS a(numOrders)
ORDER BY Support DESC, Confidence DESC;
GO

-- Adding lift 
-- Lift(A,B) = P(A,B) / (P(A) * P(B))
WITH Pairs_CTE AS   -- All possible pairs
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND Model <> t1.Model) AS t2
),
rulesCTE AS
(
SELECT Model1 + N' ---> ' + Model2 AS theRule,
 Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
),
cntModelCTE AS
(
SELECT Model,
 COUNT(DISTINCT OrderNumber) AS ModelCnt
FROM dbo.tAssocSeqLineItems
GROUP BY Model
)
SELECT r.theRule,
 r.Support,
 CAST(100.0 * r.Support / a.numOrders AS NUMERIC(5, 2))
  AS SupportPct,
 CAST(100.0 * r.Support / c1.ModelCnt AS NUMERIC(5, 2))
  AS Confidence,
 CAST((1.0 * r.Support / a.numOrders) /
  ((1.0 * c1.ModelCnt / a.numOrders) * 
   (1.0 * c2.ModelCnt / a.numOrders)) AS NUMERIC(5, 2))
  AS Lift
FROM rulesCTE AS r 
 INNER JOIN cntModelCTE AS c1
  ON r.Model1 = c1.Model
 INNER JOIN cntModelCTE AS c2
  ON r.Model2 = c2.Model
 CROSS JOIN (SELECT COUNT(DISTINCT OrderNumber) 
             FROM dbo.tAssocSeqLineItems) AS a(numOrders)
--ORDER BY Support DESC, Confidence DESC;
ORDER BY Lift DESC, Confidence DESC;
GO

/* Manual calculation lift for
   Touring Tire, Touring Tire Tube
Support = 506
Touring Tire = 581
Touring Tire Tube = 895
Count (orders) = 13006
SELECT (1.0 * 506 / 13006) /
 ((1.0 * 581 / 13006) * (1.0 * 895 / 13006))
-- 12.6559960799579267072
*/

-- Adding sequence 
WITH Pairs_CTE AS   -- All possible pairs
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND t1.LineNumber < LineNumber      -- sequence
     AND Model <> t1.Model) AS t2
),
rulesCTE AS
(
SELECT Model1 + N' ---> ' + Model2 AS theRule,
 Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
),
cntModelCTE AS
(
SELECT Model,
 COUNT(DISTINCT OrderNumber) AS ModelCnt
FROM dbo.tAssocSeqLineItems
GROUP BY Model
)
SELECT r.theRule,
 r.Support,
 CAST(100.0 * r.Support / a.numOrders AS NUMERIC(5, 2))
  AS SupportPct,
 CAST(100.0 * r.Support / c1.ModelCnt AS NUMERIC(5, 2))
  AS Confidence
FROM rulesCTE AS r 
 INNER JOIN cntModelCTE AS c1
  ON r.Model1 = c1.Model
 CROSS JOIN (SELECT COUNT(DISTINCT OrderNumber) 
             FROM dbo.tAssocSeqLineItems) AS a(numOrders)
ORDER BY Support DESC, Confidence DESC;
GO

-- Adding Begin and End
SELECT MIN(LineNumber) as minLn, 
 MAX(LineNumber) AS maxLn
FROM dbo.tAssocSeqLineItems;
-- 8
SELECT DISTINCT OrderNumber
FROM dbo.tAssocSeqLineItems;
-- 13006 orders
SELECT *
FROM dbo.tAssocSeqLineItems;
-- 32,166 rows
INSERT INTO dbo.tAssocSeqLineItems
 (OrderNumber, LineNumber, Model)
SELECT DISTINCT OrderNumber, 0, N'Begin'
FROM dbo.tAssocSeqLineItems
UNION
SELECT DISTINCT OrderNumber, 9, N'End'
FROM dbo.tAssocSeqLineItems;
-- 26,012 inserted
SELECT *
FROM dbo.tAssocSeqLineItems;
-- 58,178 rows

-- Adding sequence with begin and end
WITH Pairs_CTE AS   -- All possible pairs
(
SELECT t1.OrderNumber,
 t1.Model AS Model1, 
 t2.Model2
FROM dbo.tAssocSeqLineItems AS t1
 CROSS APPLY 
  (SELECT Model AS Model2
   FROM dbo.tAssocSeqLineItems
   WHERE OrderNumber = t1.OrderNumber
     AND t1.LineNumber < LineNumber      -- sequence
     AND Model <> t1.Model) AS t2
),
rulesCTE AS
(
SELECT Model1 + N' ---> ' + Model2 AS theRule,
 Model1, Model2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Model1, Model2
),
cntModelCTE AS
(
SELECT Model,
 COUNT(DISTINCT OrderNumber) AS ModelCnt
FROM dbo.tAssocSeqLineItems
GROUP BY Model
)
SELECT r.theRule,
 r.Support,
 CAST(100.0 * r.Support / a.numOrders AS NUMERIC(5, 2))
  AS SupportPct,
 CAST(100.0 * r.Support / c1.ModelCnt AS NUMERIC(5, 2))
  AS Confidence
FROM rulesCTE AS r 
 INNER JOIN cntModelCTE AS c1
  ON r.Model1 = c1.Model
 CROSS JOIN (SELECT COUNT(DISTINCT OrderNumber) 
             FROM dbo.tAssocSeqLineItems) AS a(numOrders)
ORDER BY Support DESC, Confidence DESC;
GO


-- Look-Alike Model (LAM)
-- "Lazy classification trees | KNN classification"
-- Idea: join new case to old data based on few input discrete variables;
-- find the group; calculate average of the target variable and count of the group

-- Prepare the data
-- Create numerical index from string ordinal variables
-- Create numerical classes from nominals (look like above, but no meaning)
-- Discretize continuous variables with equal height binning
-- Create CHAR(1) variables from numeric ordinal variables
USE AdventureWorksDW2017;
GO
SELECT 
 CAST(
 CASE EnglishEducation 
  WHEN 'Partial High School' THEN '1'
  WHEN 'High School' THEN '2'
  WHEN 'Partial College' THEN '3'
  WHEN 'Bachelors' THEN '4'
  WHEN 'Graduate Degree' THEN '5'
  ELSE '0'         -- Handling possible NULLs
 END AS CHAR(1)) AS Education,
 CAST(
 CASE CommuteDistance 
  WHEN '0-1 Miles' THEN '1'
  WHEN '1-2 Miles' THEN '2'
  WHEN '2-5 Miles' THEN '3'
  WHEN '5-10 Miles' THEN '4'
  WHEN '10+ Miles' THEN '5'
  ELSE '0'         -- Handling possible NULLs
 END AS CHAR(1)) AS CommDist,
 CAST(
 CASE EnglishOccupation 
  WHEN 'Manual' THEN '1'
  WHEN 'Clerical' THEN '2'
  WHEN 'Skilled Manual' THEN '3'
  WHEN 'Professional' THEN '4'
  WHEN 'Management' THEN '5'
  ELSE '0'         -- Handling possible NULLs
 END AS CHAR(1)) AS Occupation,
 CAST(
  CASE Region 
   WHEN 'Europe' THEN '1'
   WHEN 'North America' THEN '2'
   WHEN 'Pacific' THEN '3'
   ELSE '0'         -- Handling possible NULLs
  END AS CHAR(1)) AS Reg,
 CAST(NTILE(5) OVER(ORDER BY Age) AS CHAR(1)) AS AgeEHB,
 CAST(NTILE(5) OVER(ORDER BY YearlyIncome) AS CHAR(1)) AS IncEHB,
 CAST(ISNULL(TotalChildren, 0) AS CHAR(1)) AS Children,
 CAST(
  CASE NumberCarsOwned
   WHEN 0 THEN '1'
   WHEN 1 THEN '1'
   WHEN 2 THEN '2'
   ELSE '3'
  END AS CHAR(1)) AS Cars,
 *
FROM dbo.vTargetMail;

-- Creating a new combined variable from the computed CHAR(1) variables
-- Calculating counts per group
-- Using less variables and less bins to create broader groups
WITH gfCTE AS
(
SELECT 
 CAST(
 CASE NumberCarsOwned
  WHEN 0 THEN '1'
  WHEN 1 THEN '1'
  WHEN 2 THEN '2'
  ELSE '3'
 END AS CHAR(1)) +
 CAST(
 CASE CommuteDistance 
  WHEN '0-1 Miles' THEN '1'
  WHEN '1-2 Miles' THEN '2'
  WHEN '2-5 Miles' THEN '2'
  WHEN '5-10 Miles' THEN '3'
  WHEN '10+ Miles' THEN '3'
  ELSE '0'
 END AS CHAR(1)) +
 CAST(
  CASE Region 
   WHEN 'Europe' THEN '1'
   WHEN 'North America' THEN '2'
   WHEN 'Pacific' THEN '3'
   ELSE '0'
  END AS CHAR(1)) +
 CAST(NTILE(3) OVER(ORDER BY YearlyIncome) AS CHAR(1))
 AS GF,     -- grouping factor
 *
FROM dbo.vTargetMail
)
SELECT GF, COUNT(*) AS Cnt
FROM gfCTE
GROUP BY GF
ORDER BY GF;
GO

-- Training and test sets
DROP TABLE IF EXISTS dbo.TMTest;
DROP TABLE IF EXISTS dbo.TMTrain;
GO
-- Test set
SELECT TOP 30 PERCENT
 CAST(
 CASE NumberCarsOwned
  WHEN 0 THEN '1'
  WHEN 1 THEN '1'
  WHEN 2 THEN '2'
  ELSE '3'
 END AS CHAR(1)) +
 CAST(
 CASE CommuteDistance 
  WHEN '0-1 Miles' THEN '1'
  WHEN '1-2 Miles' THEN '2'
  WHEN '2-5 Miles' THEN '2'
  WHEN '5-10 Miles' THEN '3'
  WHEN '10+ Miles' THEN '3'
  ELSE '0'
 END AS CHAR(1)) +
 CAST(
  CASE Region 
   WHEN 'Europe' THEN '1'
   WHEN 'North America' THEN '2'
   WHEN 'Pacific' THEN '3'
   ELSE '0'
  END AS CHAR(1)) +
 CAST(NTILE(3) OVER(ORDER BY YearlyIncome) AS CHAR(1)) 
 AS GF,     -- grouping factor
  CustomerKey, 
  NumberCarsOwned, CommuteDistance,
  Region, YearlyIncome AS Income,
  BikeBuyer, 2 AS TrainTest
INTO dbo.TMTest
FROM dbo.vTargetMail
ORDER BY CAST(CRYPT_GEN_RANDOM(4) AS INT);
-- 5546 rows

-- Training set
SELECT 
 CAST(
 CASE NumberCarsOwned
  WHEN 0 THEN '1'
  WHEN 1 THEN '1'
  WHEN 2 THEN '2'
  ELSE '3'
 END AS CHAR(1)) +
 CAST(
 CASE CommuteDistance 
  WHEN '0-1 Miles' THEN '1'
  WHEN '1-2 Miles' THEN '2'
  WHEN '2-5 Miles' THEN '2'
  WHEN '5-10 Miles' THEN '3'
  WHEN '10+ Miles' THEN '3'
  ELSE '0'
 END AS CHAR(1)) +
 CAST(
  CASE Region 
   WHEN 'Europe' THEN '1'
   WHEN 'North America' THEN '2'
   WHEN 'Pacific' THEN '3'
   ELSE '0'
  END AS CHAR(1)) +
 CAST(NTILE(3) OVER(ORDER BY YearlyIncome) AS CHAR(1)) 
 AS GF,     -- grouping factor
  CustomerKey, 
  NumberCarsOwned, CommuteDistance,
  Region, YearlyIncome AS Income,
  BikeBuyer, 1 AS TrainTest
INTO dbo.TMTrain
FROM dbo.vTargetMail AS v
WHERE NOT EXISTS
 (SELECT * FROM dbo.TMTest AS t
  WHERE v.CustomerKey = t.CustomerKey);
GO  
-- 12938 rows
ALTER TABLE dbo.TMTrain ADD CONSTRAINT PK_TMTrain
 PRIMARY KEY CLUSTERED (CustomerKey);
CREATE NONCLUSTERED INDEX NCL_TMTrain_gf
 ON dbo.TMTrain (GF, BikeBuyer);
GO

-- Check the distribution of bike buyers in groups
SELECT GF,
 AVG(1.0 * BikeBuyer) AS Prb,
 COUNT(*) AS Cnt
FROM dbo.TMTrain
GROUP BY GF
ORDER BY GF;
GO


-- Searching for look-alike cases from test into training set
-- and calculating the prediction for the target variable 
SELECT t.CustomerKey,
 t.GF,
 t.BikeBuyer,
 i.Prb,
 IIF(i.Prb > 0.5, 1, 0) AS BBPredicted,
 i.Cnt,
 t.NumberCarsOwned, t.CommuteDistance, 
 t.Region, t.Income
FROM dbo.TMTest AS t
 OUTER APPLY
  (SELECT AVG(1.0 * BikeBuyer) AS Prb,
    COUNT(*) AS Cnt
   FROM dbo.TMTrain
   WHERE GF = t.GF) AS i
ORDER BY t.CustomerKey;

-- Calculating accuracy
WITH predCTE AS
(
SELECT t.CustomerKey,
 t.GF,
 t.BikeBuyer,
 i.Prb,
 IIF(i.Prb > 0.5, 1, 0) AS BBPredicted,
 i.Cnt
FROM dbo.TMTest AS t
 OUTER APPLY
  (SELECT AVG(1.0 * BikeBuyer) AS Prb,
    COUNT(*) AS Cnt
   FROM dbo.TMTrain
   WHERE GF = t.GF) AS i
)
SELECT BikeBuyer, BBPredicted, COUNT(*) AS Cnt
FROM predCTE
GROUP BY BikeBuyer, BBPredicted;
/*
BikeBuyer	BBPredicted	cnt
0			0			1860
0			1			925
1			0			1129
1			1			1632
*/
SELECT 1.0 * (1737 + 1772) / (1737 + 1057 + 980 + 1772) AS Accuracy;
GO
-- 0.637688984881


-- Naive Bayes
-- Part 1: Initial queries
-- Look Alike Model created
-- TMTrain and TMTest tables exist already
SELECT 
 CustomerKey,
 GF,
 CommuteDistance,
 Region,
 NumberCarsOwned,
 BikeBuyer,
 TrainTest
FROM dbo.TMTrain
UNION
SELECT 
 CustomerKey,
 GF,
 CommuteDistance,
 Region,
 NumberCarsOwned,
 BikeBuyer,
 TrainTest
FROM dbo.TMTest
ORDER BY CustomerKey;

-- Training the NB Model
-- Calculating a single feature distribution
-- in the class of a target variable
SELECT Region,
 COUNT(*) AS RegCnt,
 1.0 * COUNT(*) / MIN(t1.tot) AS RegPct
FROM dbo.TMTrain
 CROSS JOIN (SELECT COUNT(*) 
             FROM dbo.TMTrain 
			 WHERE BikeBuyer = 1) AS t1(tot)
WHERE BikeBuyer = 1
GROUP BY Region;

-- Full calculation
SELECT 
 1 AS BikeBuyer,
 Region,
 NumberCarsowned,
 CommuteDistance,
 COUNT(*) AS Cnt,
 1.0 * COUNT(*) / MIN(t1.tot) AS Pct
FROM dbo.TMTrain
 CROSS JOIN (SELECT COUNT(*) 
             FROM dbo.TMTrain 
			 WHERE BikeBuyer = 1) AS t1(tot)
WHERE BikeBuyer = 1
GROUP BY 
 GROUPING SETS ((Region), (NumberCarsOwned), (CommuteDistance))
UNION ALL
SELECT 
 0 AS BikeBuyer,
 Region,
 NumberCarsowned,
 CommuteDistance,
 COUNT(*) AS Cnt,
 1.0 * COUNT(*) / MIN(t0.tot) AS Pct
FROM dbo.TMTrain
 CROSS JOIN (SELECT COUNT(*) 
             FROM dbo.TMTrain 
			 WHERE BikeBuyer = 0) AS t0(tot)
WHERE BikeBuyer = 0
GROUP BY 
 GROUPING SETS ((Region), (NumberCarsOwned), (CommuteDistance))
ORDER BY BikeBuyer, Region, NumberCarsOwned, CommuteDistance;

SELECT CustomerKey, Region, NumberCarsOwned, CommuteDistance
FROM dbo.TMTest
ORDER BY CustomerKey;
GO

-- Creating the model
DROP TABLE IF EXISTS dbo.TMNB;
SELECT 
 1 AS BikeBuyer,
 Region,
 NumberCarsowned,
 CommuteDistance,
 COUNT(*) AS Cnt,
 1.0 * COUNT(*) / MIN(t1.tot) AS Pct
INTO dbo.TMNB
FROM dbo.TMTrain
 CROSS JOIN (SELECT COUNT(*) 
             FROM dbo.TMTrain 
			 WHERE BikeBuyer = 1) AS t1(tot)
WHERE BikeBuyer = 1
GROUP BY 
 GROUPING SETS ((Region), (NumberCarsOwned), (CommuteDistance))
UNION ALL
SELECT 
 0 AS BikeBuyer,
 Region,
 NumberCarsowned,
 CommuteDistance,
 COUNT(*) AS Cnt,
 1.0 * COUNT(*) / MIN(t0.tot) AS Pct
FROM dbo.TMTrain
 CROSS JOIN (SELECT COUNT(*) 
             FROM dbo.TMTrain 
			 WHERE BikeBuyer = 0) AS t0(tot)
WHERE BikeBuyer = 0
GROUP BY 
 GROUPING SETS ((Region), (NumberCarsOwned), (CommuteDistance));
GO
-- Result for one combination of input values
SELECT *
FROM dbo.TMNB
WHERE Region = N'Pacific'
  OR NumberCarsOwned = 1
  OR CommuteDistance = N'2-5 Miles'
ORDER BY BikeBuyer, Region, NumberCarsOwned, CommuteDistance;


/* Calculation for customer 11002, two variables only
   NumberCarsOwned = 1, Region = Pacific
*/
SELECT
 (0.236962488563 * 0.148368405001) /
 ((0.236962488563 * 0.148368405001) +
  (0.293103448275 * 0.231661442006))
 AS P0,
 (0.293103448275 * 0.231661442006) /
 ((0.236962488563 * 0.148368405001) +
  (0.293103448275 * 0.231661442006))
 AS P1;
GO


-- Aggregate product
/*
SELECT 
  EXP(SUM(LOG(val))) AS product
FROM dbo.T1
*/

-- Prediction with variables
DECLARE @nPct AS DECIMAL(18,17),
 @pPct AS DECIMAL(18,17),
 @tPct AS DECIMAL(18,17);
SET @nPct =
(
SELECT EXP(SUM(LOG(Pct))) AS nPct
FROM dbo.TMNB
WHERE BikeBuyer = 0
  AND (Region = N'Pacific'
   OR NumberCarsOwned = 1
   OR CommuteDistance = N'2-5 Miles')
)
SET @pPct =
(
SELECT EXP(SUM(LOG(Pct))) AS pPct
FROM dbo.TMNB
WHERE BikeBuyer = 1
  AND (Region = N'Pacific'
   OR NumberCarsOwned = 1
   OR CommuteDistance = N'2-5 Miles')
)
SET @tPct = @pPct / (@nPct + @pPct);
SELECT @tPct AS PositiveProbability, 
 @nPct / (@nPct + @pPct) AS NegativeProbability;
GO

-- Prediction query
WITH nPctCTE AS
(
SELECT EXP(SUM(LOG(Pct))) AS nPct
FROM dbo.TMNB
WHERE BikeBuyer = 0
  AND (Region = N'Pacific'
   OR NumberCarsOwned = 1
   OR CommuteDistance = N'2-5 Miles')
),
pPctCTE AS
(
SELECT EXP(SUM(LOG(Pct))) AS pPct
FROM dbo.TMNB
WHERE BikeBuyer = 1
  AND (Region = N'Pacific'
   OR NumberCarsOwned = 1
   OR CommuteDistance = N'2-5 Miles')
)
SELECT pPct / (nPct + pPct) AS tPct
FROM nPctCTE CROSS JOIN pPctCTE;
GO
-- 0.734167179560153

-- Prediction function
CREATE OR ALTER FUNCTION dbo.PredictNB
 (@Region NVARCHAR(50),
  @NumberCarsOwned TINYINT,
  @CommuteDistance NVARCHAR(15))
RETURNS TABLE
AS RETURN
(
WITH nPctCTE AS
(
SELECT EXP(SUM(LOG(Pct))) AS nPct
FROM dbo.TMNB
WHERE BikeBuyer = 0
  AND (Region = @Region
   OR NumberCarsOwned = @NumberCarsOwned
   OR CommuteDistance = @CommuteDistance)
),
pPctCTE AS
(
SELECT EXP(SUM(LOG(Pct))) AS pPct
FROM dbo.TMNB
WHERE BikeBuyer = 1
  AND (Region = @Region
   OR NumberCarsOwned = @NumberCarsOwned
   OR CommuteDistance = @CommuteDistance)
)
SELECT pPct / (nPct + pPct) AS tPct
FROM nPctCTE CROSS JOIN pPctCTE);
GO

-- Full prediction on the test set
SELECT t.CustomerKey,
 t.BikeBuyer,
 t.Region,
 t.NumberCarsOwned,
 t.CommuteDistance,
 i.tPct,
 IIF(i.tPct > 0.5, 1, 0) AS BBPredicted
FROM dbo.TMTest AS t
 CROSS APPLY
  dbo.PredictNB(t.Region, t.NumberCarsOwned, t.CommuteDistance) AS i
ORDER BY t.CustomerKey;

-- Calculating accuracy
WITH predCTE AS
(
SELECT t.CustomerKey,
 t.BikeBuyer,
 t.Region,
 t.NumberCarsOwned,
 t.CommuteDistance,
 i.tPct,
 IIF(i.tPct > 0.5, 1, 0) AS BBPredicted
FROM dbo.TMTest AS t
 CROSS APPLY
  dbo.PredictNB(t.Region, t.NumberCarsOwned, t.CommuteDistance) AS i
)
SELECT BikeBuyer, BBPredicted, COUNT(*) AS Cnt
FROM predCTE
GROUP BY BikeBuyer, BBPredicted;
/*
BikeBuyer	BBPredicted	cnt
0			0			1777
0			1			1008
1			0			1249
1			1			1512
*/
SELECT 1.0 * (1803 + 1565) / (1803 + 991 + 1187 + 1565) AS Accuracy;
GO



-- Clean up
USE AdventureWorksDW2017;
DROP TABLE IF EXISTS dbo.EMA;
DROP TABLE IF EXISTS dbo.tAssocSeqLineItems;
DROP TABLE IF EXISTS dbo.tAssocSeqOrders;
DROP TABLE IF EXISTS dbo.TMTest;
DROP TABLE IF EXISTS dbo.TMTrain;
DROP FUNCTION dbo.PredictNB;
DROP TABLE IF EXISTS dbo.TMNB;
GO

