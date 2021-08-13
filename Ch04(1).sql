-- Advanced Analytics with Transact-SQL
-- Chapter 04: Data Quality  

/* 0) Adding Low Quality Data
   1) Data Quality
      Measuring Completeness
      Finding Inaccurate Data 
      Measuring Data Quality over Time
   2) Measuring the Information
      Introducing Entropy
      Mutual Information
	  Conditional Entropy
 */

/* Data Quality */
-- Adding low quality data
r
DROP VIEW IF EXISTS dbo.airqualityLQ;
GO
CREATE OR ALTER VIEW dbo.airqualityLQ
AS
SELECT Ozone, SolarR, Wind, Temp,
  CAST('1973' + FORMAT(MonthInt, '00') +
       FORMAT(DayInt, '00') AS date) AS DateM
FROM dbo.airquality
UNION
SELECT *
FROM (VALUES 
 (150, NULL, 55,    -- too strong Wind
  88, '19731001'),  -- too high temperature, date
 (80, 120, 8,
  92, '19731002'),  -- too high temperature, date
 (50, 40, 6,
  56, '19730202')   -- too low date
 ) AS a(Ozone, SolarR, Wind,
  Temp, DateM);
GO
DROP VIEW IF EXISTS dbo.mtcarsLQ;
GO
CREATE OR ALTER VIEW dbo.mtcarsLQ
AS
SELECT carbrand, engine, 
 transmission + '@comp.com' AS transMail
FROM dbo.mtcars
UNION
SELECT *
FROM (VALUES 
 (N'1',                                           -- Short carbrand
  N'Straight',
  N'Manual#comp.com'),                            -- Incorrect mail
 (N'2 Long Carbrand Name' + REPLICATE(N'X',100),  -- Long carbrand
  N'V-shape',
  N'Manual@comp.com'),
 (N'3 Normal Carbrand',                                          
  N'Streight',                                    -- Spelling error
  N'Manual#comp.com')                             -- Incorrect mail
 ) AS a(carbrand, engine, transMail);
GO

-- Checking the data
SELECT *
FROM dbo.airqualityLQ
ORDER BY dateM;
SELECT *
FROM dbo.mtcarsLQ
ORDER BY carbrand;
GO


/* Completeness (same queries as in Ch03, just on the view) */
-- Checking amount of NULLs
SELECT IIF(Ozone IS NULL, 1, 0) AS OzoneN,
 COUNT(*) AS cnt
FROM dbo.airquality
GROUP BY IIF(Ozone IS NULL, 1, 0);
-- 37
SELECT IIF(SolarR IS NULL, 1, 0) AS SolarRN,
 COUNT(*) AS cnt
FROM dbo.airqualityLQ
GROUP BY IIF(SolarR IS NULL, 1, 0);
-- 8
GO

-- Number of rows with NULLs
SELECT 
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 COUNT(*) AS cnt
FROM dbo.airqualityLQ
GROUP BY
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0);
-- 43 rows with NULLs in first two variables


/* Accuracy */

-- Column uniqueness - candidate key
SELECT carbrand,
 COUNT(*) AS Number
FROM dbo.mtcarsLQ
GROUP BY carbrand
HAVING COUNT(*) > 1
ORDER BY Number DESC;
-- 0 rows
GO

-- Numbers
-- Check extreme numbers
WITH WindCTE AS
(
SELECT DateM, Wind,
 AVG(Wind) OVER() AS WindAvg,
 STDEV(Wind) OVER() AS WindStDev
FROM dbo.airqualityLQ
) 
SELECT DateM, Wind,
 WindAvg, WindStDev
FROM WindCTE
WHERE Wind > 
 WindAvg + 2 * WindStDev
ORDER BY DateM;
-- Clearly one row is suspicious

-- Dates
-- Check months with few rows only
SELECT MONTH(DateM) AS DateMonth,
 COUNT(*) AS DaysInMonth
FROM dbo.airqualityLQ
GROUP BY MONTH(DateM)
ORDER BY DaysInMonth;
-- Two months suspicious

-- Strings
-- String checking

-- Length of a string
SELECT LEN(carbrand) AS carbrandLength,
 COUNT(*) AS Number
FROM dbo.mtcarsLQ
GROUP BY LEN(carbrand)
ORDER BY Number, carbrandLength;
GO
-- Find suspicious rows
SELECT carbrand
FROM dbo.mtcarsLQ
WHERE LEN(carbrand) < 2
   OR LEN(carbrand) > 20;
GO 

-- Values with low frequency
SELECT engine,
 COUNT(*) AS Number
FROM dbo.mtcarsLQ
GROUP BY engine
ORDER BY Number;
GO

-- Incorrect email addresses
SELECT carbrand, transMail
FROM dbo.mtcarsLQ
WHERE transMail NOT LIKE '%@%';
GO

-- Advanced check with regular expressions in Python
-- R with data.table

/* In RStudio IDE,
Download the package data.table and not install it
download.packages("data.table", destdir="C:\\Apress\\Ch04", 
                  type="win.binary")
*/
-- Create external library
CREATE EXTERNAL LIBRARY [data.table]
FROM (CONTENT = 'C:\Apress\Ch04\data.table_1.12.0.zip') 
WITH (LANGUAGE = 'R');
GO

-- Calling R
EXECUTE sys.sp_execute_external_script
 @language=N'R',
 @script = 
  N'
    library(data.table)
    RTD <- data.table(RT)
	regex <- "^[[:alnum:]._-]+@[[:alnum:].-]+$"
	RTDJ <- RTD[!grepl(regex, transMail)]
   '
 ,@input_data_1 = N'
    SELECT carbrand, transMail
    FROM dbo.mtcarsLQ;'
 ,@input_data_1_name =  N'RT'
 ,@output_data_1_name = N'RTDJ'
WITH RESULT SETS 
(
 ("carbrand" NVARCHAR(120) NOT NULL,
  "transMail" NVARCHAR(20) NOT NULL)
);
GO

-- Suspicious data over more than one variable
-- Checking the temperature over months
SELECT MONTH(DateM) AS MonthD,
 AVG(Temp) AS tempAvg,
 COUNT(*) AS nRows
FROM dbo.airqualityLQ
GROUP BY MONTH(DateM);
GO

/* Data Quality DW */
USE master;
CREATE DATABASE DQDW;
GO
USE DQDW;
GO

-- Dimensions
-- DimDate 
CREATE TABLE dbo.DimDate
(DateId int NOT NULL,
 FullDate DATE NOT NULL);
ALTER TABLE dbo.DimDate 
 ADD CONSTRAINT PK_DimDate
  PRIMARY KEY(DateId);
GO
-- DimTable
CREATE TABLE dbo.DimTable
(TableId int NOT NULL,
 TableName sysname NOT NULL,
 SchemaName sysname NOT NULL,
 DatabaseName sysname NULL,
 ServerName sysname NULL,
 ApplicationName sysname NULL);
GO
ALTER TABLE dbo.DimTable
 ADD CONSTRAINT PK_DimTable
  PRIMARY KEY(TableId);
GO
-- DimColumn
CREATE TABLE dbo.DimColumn
(ColumnId int NOT NULL,
 ColumnName sysname NOT NULL,
 TableId int NOT NULL);
GO
ALTER TABLE dbo.DimColumn
 ADD CONSTRAINT PK_DimColumn
  PRIMARY KEY(ColumnId);
GO
ALTER TABLE dbo.DimColumn 
 ADD CONSTRAINT FK_DimColumn_DimTable
  FOREIGN KEY(TableId)
  REFERENCES dbo.DimTable(TableId);
GO

-- Fact tables
-- Tables
CREATE TABLE dbo.FactTables
(TableId int NOT NULL,
 DateId int NOT NULL,
 NumRows bigint NOT NULL,
 NumUnknownRows bigint NOT NULL,
 NumErroneousRows bigint NOT NULL);
GO
ALTER TABLE dbo.FactTables
 ADD CONSTRAINT PK_FactTables
  PRIMARY KEY(TableId, DateId);
GO
ALTER TABLE dbo.FactTables 
 ADD CONSTRAINT FK_FactTables_DimTable
  FOREIGN KEY(TableId)
  REFERENCES dbo.DimTable(TableId);
ALTER TABLE dbo.FactTables 
 ADD CONSTRAINT FK_FactTables_DimDate
  FOREIGN KEY(DateId)
  REFERENCES dbo.DimDate(DateId);  
GO
-- Columns
CREATE TABLE dbo.FactColumns
(ColumnId int NOT NULL,
 DateId int NOT NULL,
 NumValues bigint NOT NULL,
 NumUnknownValues bigint NOT NULL,
 NumErroneousValues bigint NOT NULL);
GO
ALTER TABLE dbo.FactColumns
 ADD CONSTRAINT PK_FactColumns
  PRIMARY KEY(ColumnId, DateId);
GO
ALTER TABLE dbo.FactColumns 
 ADD CONSTRAINT FK_FacColumns_DimColumn
  FOREIGN KEY(ColumnId)
  REFERENCES dbo.DimColumn(ColumnId);
ALTER TABLE dbo.FactColumns 
 ADD CONSTRAINT FK_FactColumns_DimDate
  FOREIGN KEY(DateId)
  REFERENCES dbo.DimDate(DateId);
GO

-- Create database diagram in SSMS


/* Entropy */

-- Calculating the entropy
-- Maximal entropy for different number of distinct states
-- Logarithm equation for probability = 1/3 (3 states)
-- LOG(1/3) = LOG(1) - LOG(3) = -LOG(3)
-- Entropy = (-1) * ((1/3)*(-LOG(3)) + (1/3)*(-LOG(3)) + (1/3)*(-LOG(3))) = LOG(3)
-- Simplified calculation
USE AdventureWorksDW2017;
SELECT LOG(2,2) AS TwoStatesMax,
 LOG(3,2) AS ThreeStatesMax,
 LOG(4,2) AS FourStatesMax,
 LOG(5,2) AS FiveStatesMax;
GO

-- Entropy of hpdescription
WITH prob AS
(
SELECT hpdescription,
 COUNT(hpdescription) AS stateFreq
FROM dbo.mtcars
GROUP BY hpdescription
),
stateEntropy AS
(
SELECT hpdescription, stateFreq,
 1.0 * stateFreq / SUM(stateFreq) OVER () AS stateProbability
FROM prob
)
--SELECT * FROM stateEntropy;
SELECT 'hpdescription' AS Variable,
 (-1) * SUM(stateProbability * LOG(stateProbability, 2)) AS TotalEntropy,
 LOG(COUNT(*), 2) AS MaxPossibleEntropy,
 100 * ((-1)*SUM(stateProbability * LOG(stateProbability, 2))) / 
 (LOG(COUNT(*), 2)) AS PctOfMaxPossibleEntropy
FROM stateEntropy;
GO

-- Entropy of cyl
WITH prob AS
(
SELECT cyl,
 COUNT(cyl) AS stateFreq
FROM dbo.mtcars
GROUP BY cyl
),
stateEntropy AS
(
SELECT cyl,
 1.0 * stateFreq / SUM(stateFreq) OVER () AS stateProbability
FROM prob
)
--SELECT * FROM stateEntropy
SELECT 'cyl' AS Variable,
 (-1) * SUM(stateProbability * LOG(stateProbability, 2)) AS TotalEntropy,
 LOG(COUNT(*), 2) AS MaxPossibleEntropy,
 100 * ((-1)*SUM(stateProbability * LOG(stateProbability, 2))) / 
 (LOG(COUNT(*), 2)) AS PctOfMaxPossibleEntropy
FROM stateEntropy;
GO


-- Mutual information I(hpdescription; cyl)
WITH counts AS
(
SELECT cyl AS x,
 hpdescription AS y,
 COUNT(*) AS n
FROM dbo.mtcars
GROUP BY cyl, hpdescription
)
--SELECT * FROM counts
, probs AS
(
SELECT x, y, n,
 1.0 * n / SUM(n) OVER () AS xyProb,
 1.0 * SUM(n) OVER(PARTITION BY x) AS xn,
 1.0 * SUM(n) OVER(PARTITION BY x) / SUM(n) OVER () AS xProb,
 1.0 * SUM(n) OVER(PARTITION BY y) AS yn,
 1.0 * SUM(n) OVER(PARTITION BY y) / SUM(n) OVER () AS yProb
FROM counts
)
--SELECT * FROM probs
--ORDER BY x, y;
SELECT SUM(xyProb * LOG(xyProb / xProb / yProb, 2))
 AS mutualInformation
FROM probs;

-- Mutual information carb, engine
WITH counts AS
(
SELECT carb AS x,
 engine AS y,
 COUNT(*) AS n
FROM dbo.mtcars
GROUP BY carb, engine
)
--SELECT * FROM counts
, probs AS
(
SELECT x, y, n,
 1.0 * n / SUM(n) OVER () AS xyProb,
 1.0 * SUM(n) OVER(PARTITION BY x) AS xn,
 1.0 * SUM(n) OVER(PARTITION BY x) / SUM(n) OVER () AS xProb,
 1.0 * SUM(n) OVER(PARTITION BY y) AS yn,
 1.0 * SUM(n) OVER(PARTITION BY y) / SUM(n) OVER () AS yProb
FROM counts
)
--SELECT * FROM probs
--ORDER BY x, y;
SELECT SUM(xyProb * LOG(xyProb / xProb / yProb, 2))
 AS mutualInformation
FROM probs;

-- Conditional entropy H(hpdescription | cyl)
WITH counts AS
(
SELECT cyl AS x,
 hpdescription AS y,
 COUNT(*) AS n
FROM dbo.mtcars
GROUP BY cyl, hpdescription
)
--SELECT * FROM counts
, probs AS
(
SELECT x, y, n,
 1.0 * n / SUM(n) OVER () AS xyProb,
 1.0 * SUM(n) OVER(PARTITION BY x) AS xn,
 1.0 * SUM(n) OVER(PARTITION BY x) / SUM(n) OVER () AS xProb,
 1.0 * SUM(n) OVER(PARTITION BY y) AS yn,
 1.0 * SUM(n) OVER(PARTITION BY y) / SUM(n) OVER () AS yProb
FROM counts
)
--SELECT * FROM probs
--ORDER BY x, y;
SELECT (-1) * SUM(xyProb * LOG(xyProb / xProb, 2))
 AS conditionalEntropy
FROM probs;

-- Conditional entropy H(cyl | hpdescription) 
WITH counts AS
(
SELECT hpdescription AS x,
 cyl AS y,
 COUNT(*) AS n
FROM dbo.mtcars
GROUP BY hpdescription, cyl
)
--SELECT * FROM counts
, probs AS
(
SELECT x, y, n,
 1.0 * n / SUM(n) OVER () AS xyProb,
 1.0 * SUM(n) OVER(PARTITION BY x) AS xn,
 1.0 * SUM(n) OVER(PARTITION BY x) / SUM(n) OVER () AS xProb,
 1.0 * SUM(n) OVER(PARTITION BY y) AS yn,
 1.0 * SUM(n) OVER(PARTITION BY y) / SUM(n) OVER () AS yProb
FROM counts
)
--SELECT * FROM probs
--ORDER BY x, y;
SELECT (-1) * SUM(xyProb * LOG(xyProb / xProb, 2))
 AS conditionalEntropy
FROM probs;
GO

/*
Variable	TotalEntropy
hpdescription	1.56705242819723
cyl             1.53099371349313

cyl hpdescription mutual information 0.954298454365242
*/
SELECT 
 1.56705242819723 - 0.954298454365242 AS '(hpdescription | cyl)',
 1.53099371349313 - 0.954298454365242 AS '(cyl | hpdescription)';
GO
-- 0.612753973831988 0.576695245634758



-- Clean up
USE AdventureWorksDW2017;
DROP VIEW IF EXISTS dbo.airqualityLQ;
DROP VIEW IF EXISTS dbo.mtcarsLQ;
DROP EXTERNAL LIBRARY [data.table];
GO
USE master;
DROP DATABASE DQDW;
GO