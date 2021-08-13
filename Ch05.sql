-- Advanced Analytics with Transact-SQL
-- Chapter 05: Time-Oriented Data  

/* 1) Application and System Times
      Inclusion Constraints
	  Demo Data
   2) System-Versioned Tables
      A Quick intro
      Querying Surprises
	  Missing Inclusion Constraints
   3) Optimizing Temporal Queries
      Modifying the Filter Predicate
	  Using the Unpacked Form
   4) Time Series
      Moving Averages
 */

/* Application and System Times */

-- Demo data
USE AdventureWorksDW2017;
GO

-- Auxiliary table of dates and numbers
DROP TABLE IF EXISTS dbo.DateNums;
CREATE TABLE dbo.DateNums
 (n int NOT NULL PRIMARY KEY,
  d date NOT NULL UNIQUE);
GO

SET NOCOUNT ON;
DECLARE @max AS INT, @rc AS INT, @d AS DATE;
SET @max = 10000;
SET @rc = 1;
SET @d = '20100101'     -- Initial date

INSERT INTO dbo.DateNums VALUES(1, @d);
WHILE @rc * 2 <= @max
BEGIN
  INSERT INTO dbo.DateNums 
  SELECT n + @rc, DATEADD(day, n + @rc - 1, @d) 
  FROM dbo.DateNums;
  SET @rc = @rc * 2;
END

INSERT INTO dbo.DateNums
  SELECT n + @rc, DATEADD(day, n + @rc - 1, @d) 
  FROM dbo.DateNums 
  WHERE n + @rc <= @max;
GO

-- Check data
SELECT * FROM dbo.DateNums

SET NOCOUNT OFF;
GO


-- Sales demo data
DROP TABLE IF EXISTS dbo.Sales;
CREATE TABLE dbo.Sales
(
 Id int IDENTITY(1,1) PRIMARY KEY,
 ProductKey int,
 PName varchar(13),
 sn int NULL,
 en int NULL,
 SoldDate date,
 ExpirationDate date
);
GO

-- Develop the queries
DECLARE @y AS int = 1;
SELECT 
 CustomerKey AS ProductKey,
 'Product ' + CAST(CustomerKey AS char(5)) AS PName,
 CAST(DATEADD(year, @y *3, OrderDate) 
  AS date) AS SoldDate, 
 CAST(CRYPT_GEN_RANDOM(1) AS int) % 30 AS Duration,
 CAST(DATEADD(day, 
	    CAST(CRYPT_GEN_RANDOM(1) AS int) % 30 + 1,
        DATEADD(year, @y *3, OrderDate)) 
  AS date) AS ExpirationDate
FROM dbo.FactInternetSales
GO

-- Insert the data
DECLARE @y AS int = 0;
WHILE @y < 3
BEGIN
INSERT INTO dbo.Sales
 (ProductKey, PName, SoldDate, ExpirationDate)
SELECT 
 CustomerKey AS ProductKey,
 'Product ' + CAST(CustomerKey AS char(5)) AS PName,
 CAST(DATEADD(year, @y *3, OrderDate) 
  AS date) AS SoldDate,  
 CAST(DATEADD(day, 
	    CAST(CRYPT_GEN_RANDOM(1) AS int) % 30 + 1,
        DATEADD(year, @y *3, OrderDate)) 
  AS date) AS ExpirationDate
FROM dbo.FactInternetSales
UNION ALL 
SELECT 
 ResellerKey AS ProductKey,
 'Product ' + CAST(ResellerKey AS char(5)) AS PName,
 CAST(DATEADD(year, @y *3, OrderDate) 
  AS date) AS SoldDate,  
 CAST(DATEADD(day, 
	    CAST(CRYPT_GEN_RANDOM(1) AS int) % 30 + 1,
        DATEADD(year, @y *3, OrderDate)) 
  AS date) AS ExpirationDate
FROM dbo.FactResellerSales;
SET @y = @y + 1;
END;
GO

-- Update sn and en
--SELECT d.n, s.SoldDate
UPDATE dbo.Sales
   SET sn = d.n
FROM dbo.Sales AS s
 INNER JOIN dbo.DateNums AS d
  ON s.SoldDate = d.d;
UPDATE dbo.Sales
   SET en = d.n
FROM dbo.Sales AS s
 INNER JOIN dbo.DateNums AS d
  ON s.ExpirationDate = d.d;
GO

-- Overview
SELECT *
FROM dbo.Sales;
SELECT MIN(SoldDate), MAX(ExpirationDate)
FROM dbo.Sales;
SELECT YEAR(SoldDate) AS sy,
 COUNT(*) AS cnt
FROM dbo.Sales
GROUP BY YEAR(SoldDate)
ORDER BY sy;
GO


/* System-Versioned Tables */

-- A Quick intro
-- Retention policy
ALTER DATABASE AdventureWorksDW2017
 SET TEMPORAL_HISTORY_RETENTION ON;
GO

-- T1
DROP TABLE IF EXISTS dbo.T1;
CREATE TABLE dbo.T1
(
 Id INT NOT NULL PRIMARY KEY CLUSTERED,
 C1 INT,
 Vf DATETIME2 NOT NULL,
 Vt DATETIME2 NOT NULL
);
GO
-- T1 hist
DROP TABLE IF EXISTS dbo.T1_Hist;
CREATE TABLE dbo.T1_Hist
(
 Id INT NOT NULL,
 C1 INT,
 Vf DATETIME2 NOT NULL,
 Vt DATETIME2 NOT NULL
);
GO
CREATE CLUSTERED INDEX IX_CL_T1_Hist ON dbo.T1_Hist(Vt, Vf);
GO

-- Populate tables
INSERT INTO dbo.T1_Hist(Id, C1, Vf, Vt) VALUES
(1,1,'20191101','20191106'),
(1,2,'20191106','20210202');
GO
INSERT INTO dbo.T1(Id, C1, Vf, Vt) VALUES
(1,3,'20210202','99991231 23:59:59.9999999');
GO
SELECT *
FROM dbo.T1;
SELECT *
FROM dbo.T1_Hist;
GO

-- Convert to temporal
ALTER TABLE dbo.T1 ADD PERIOD FOR SYSTEM_TIME (Vf, Vt);
GO
ALTER TABLE dbo.T1 SET
(
SYSTEM_VERSIONING = ON
 (
  HISTORY_TABLE = dbo.T1_Hist,
  HISTORY_RETENTION_PERIOD = 3 MONTHS
 )
);
GO

-- Show the content of the two tables
SELECT *
FROM dbo.T1;
SELECT *
FROM dbo.T1_Hist;

-- Do some updates
INSERT INTO dbo.T1 (Id, C1)
VALUES (2, 1), (3, 1);

WAITFOR DELAY '00:00:01';

UPDATE dbo.T1
   SET C1 = 2 
 WHERE Id = 2;

WAITFOR DELAY '00:00:01';

DELETE FROM dbo.T1
WHERE id = 3;
GO

-- Show the content of the two tables
SELECT *
FROM dbo.T1;
SELECT *
FROM dbo.T1_Hist;
GO

-- Hiding the period columns
ALTER TABLE dbo.T1 ALTER COLUMN Vf ADD HIDDEN;
ALTER TABLE dbo.T1 ALTER COLUMN Vt ADD HIDDEN;
GO
-- Show the content of the two tables
SELECT *
FROM dbo.T1;
SELECT *
FROM dbo.T1_Hist;
GO

-- FOR SYSTEM_TIME clause

-- AS OF
SELECT Id, C1, Vf, Vt
FROM dbo.T1
 FOR SYSTEM_TIME
  AS OF '2021-02-05 10:30:10.6184612';

-- FROM..TO and BETWEEN
DECLARE @Vf AS DATETIME2;
SET @Vf = 
 (SELECT MAX(Vf) FROM dbo.T1_Hist);
-- SELECT @Vf;
SELECT Id, C1, Vf, Vt
FROM dbo.T1
 FOR SYSTEM_TIME
  FROM '2019-11-06 00:00:00.0000000' 
    TO @Vf;
SELECT Id, C1, Vf, Vt
FROM dbo.T1
 FOR SYSTEM_TIME
  BETWEEN '2019-11-06 00:00:00.0000000' 
      AND @Vf;
GO

-- CONTAINED IN
DECLARE @Vf AS DATETIME2;
SET @Vf = 
 (SELECT MAX(Vf) FROM dbo.T1_Hist);
SET @Vf = DATEADD(s, 3, @Vf);
-- SELECT @Vf;
SELECT Id, C1, Vf, Vt
FROM dbo.T1
 FOR SYSTEM_TIME
  CONTAINED IN
   ('2019-11-06 00:00:00.0000000',
    @Vf); 
GO


-- Querying Surprises
-- Show the execution plan
-- Rows that exceed the retention period not shown
SELECT Id, C1, Vf, Vt
FROM dbo.T1
 FOR SYSTEM_TIME ALL;
-- Still can see them if you query the history table directly
SELECT Id, C1, Vf, Vt 
FROM dbo.T1
UNION ALL
SELECT Id, C1, Vf, Vt 
FROM dbo.T1_Hist;
GO

-- Check the retention period
SELECT temporal_type_desc, history_retention_period,
 history_retention_period_unit
FROM sys.tables 
WHERE name = 'T1';
GO
/* Possible retention units
-1: INFINITE
3: DAY
4: WEEK
5: MONTH
6: YEAR
*/

-- Clean up
ALTER TABLE dbo.T1 SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS dbo.T1;
DROP TABLE IF EXISTS dbo.T1_Hist;
GO
ALTER DATABASE AdventureWorksDW2017
 SET TEMPORAL_HISTORY_RETENTION OFF;
GO


-- Granularity issues - granularity 1s demo
CREATE TABLE dbo.T1
(
 id INT NOT NULL CONSTRAINT PK_T1 PRIMARY KEY,
 c1 INT NOT NULL,
 vf DATETIME2(0) GENERATED ALWAYS AS ROW START NOT NULL,
 vt DATETIME2(0) GENERATED ALWAYS AS ROW END NOT NULL,
 PERIOD FOR SYSTEM_TIME (vf, vt)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.T1_Hist));
GO
-- Initial row
INSERT INTO dbo.T1(id, c1) 
VALUES(1, 1);
SELECT *
FROM dbo.T1 
FOR SYSTEM_TIME ALL;
GO

-- Execute the following two transactions together
BEGIN TRAN
UPDATE dbo.T1
   SET c1 = 2
 WHERE id=1;
COMMIT;
WAITFOR DELAY '00:00:00.1';
BEGIN TRAN
UPDATE dbo.T1
   SET c1 = 3
 WHERE id=1;
COMMIT;
GO
-- Check the state - 2 rows
SELECT *
FROM dbo.T1 
FOR SYSTEM_TIME ALL;
GO

-- FOR SYSTEM_TIME ALL filters rows with the same valid from and valid to
-- However, the rows are in the history table
SELECT *
FROM dbo.T1
UNION ALL
SELECT *
FROM dbo.T1_Hist;
GO
-- Clean up
ALTER TABLE dbo.T1 SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS dbo.T1;
DROP TABLE IF EXISTS dbo.T1_Hist;
GO


-- Missing Inclusion Constraints
USE tempdb;
GO
-- Customers
CREATE TABLE dbo.CustomerHistory
(
 CId CHAR(3) NOT NULL,
 CName CHAR(5) NOT NULL,
 ValidFrom DATETIME2 NOT NULL,
 ValidTo DATETIME2 NOT NULL
);
CREATE CLUSTERED INDEX CIX_CustomerHistory ON dbo.CustomerHistory
(ValidTo ASC, ValidFrom ASC);
GO
CREATE TABLE dbo.Customer
(
 CId CHAR(3) PRIMARY KEY,
 CName CHAR(5) NOT NULL
);
GO
-- Orders
CREATE TABLE dbo.OrdersHistory
(
 OId CHAR(3) NOT NULL,
 CId CHAR(3) NOT NULL,
 Q INT NOT NULL,
 ValidFrom DATETIME2 NOT NULL,
 ValidTo DATETIME2 NOT NULL
);
CREATE CLUSTERED INDEX CIX_OrdersHistory ON dbo.OrdersHistory
(ValidTo ASC, ValidFrom ASC);
GO
CREATE TABLE dbo.Orders
(
 OId CHAR(3) NOT NULL PRIMARY KEY,
 CId CHAR(3) NOT NULL,
 Q INT NOT NULL
);
GO
ALTER TABLE dbo.Orders ADD CONSTRAINT FK_Orders_Customer
 FOREIGN KEY (CId) REFERENCES dbo.Customer(CID);
GO

-- Demo data
INSERT INTO dbo.CustomerHistory
 (CId, CName, ValidFrom, ValidTo)
VALUES
 ('111','AAA','20180101', '20180201'),
 ('111','BBB','20180201', '20180220');
INSERT INTO dbo.Customer
 (CId, CName)
VALUES
 ('111','CCC');
INSERT INTO dbo.OrdersHistory
 (OId, CId, Q, ValidFrom, ValidTo)
VALUES
 ('001','111',1000,'20180110','20180201'),
 ('001','111',2000,'20180201','20180203'),
 ('001','111',3000,'20180203','20180220');
INSERT INTO dbo.Orders
 (OId, CId, q)
VALUES
 ('001','111',4000);
GO

-- Check the data
SELECT * FROM dbo.Customer;
SELECT * FROM dbo.CustomerHistory;
SELECT * FROM dbo.Orders;
SELECT * FROM dbo.OrdersHistory;
GO

-- Make the tables temporal
-- Alter the current tables
ALTER TABLE dbo.Customer
 ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL
  CONSTRAINT DFC_StartDate1 DEFAULT '20180220 00:00:00.0000000',
 ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL 
  CONSTRAINT DFC_EndDate1 DEFAULT '99991231 23:59:59.9999999',
 PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
ALTER TABLE dbo.Orders
 ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL
  CONSTRAINT DFO_StartDate1 DEFAULT '20180220 00:00:00.0000000',
 ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL 
  CONSTRAINT DFO_EndDate1 DEFAULT '99991231 23:59:59.9999999',
 PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
-- Enable system versioning
ALTER TABLE dbo.Customer
 SET (SYSTEM_VERSIONING = ON
  (HISTORY_TABLE = dbo.CustomerHistory, 
   DATA_CONSISTENCY_CHECK = ON));
GO
ALTER TABLE dbo.Orders
 SET (SYSTEM_VERSIONING = ON
  (HISTORY_TABLE = dbo.OrdersHistory, 
   DATA_CONSISTENCY_CHECK = ON));
GO
-- Check all data 
SELECT * 
FROM dbo.Customer 
 FOR SYSTEM_TIME ALL;
SELECT * 
FROM dbo.Orders 
 FOR SYSTEM_TIME ALL;
GO

-- State on a specific time point through a view
CREATE OR ALTER VIEW dbo.CustomerOrders
AS
SELECT C.CId, C.CName, O.OId, O.Q,
 c.ValidFrom AS CVF, c.ValidTo AS CVT,
 o.ValidFrom AS OVF, o.ValidTo AS OVT
FROM dbo.Customer AS c
 INNER JOIN dbo.Orders AS o
  ON c.CId = o.CId;
GO

-- Queries on the view - show execution plan
-- Current state
SELECT *
FROM dbo.CustomerOrders;
-- Specific dates - propagated to source tables
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME AS OF '20180102';  
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME AS OF '20180131'; 
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME AS OF '20180201';
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME AS OF '20180203';
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME AS OF '20180221';
GO

-- System time all - all combinations
-- Cross join, no temporal constraints
-- Also includes incorrect rows
SELECT *
FROM dbo.CustomerOrders
 FOR SYSTEM_TIME ALL;
GO

-- Clean up
DROP VIEW IF EXISTS dbo.CustomerOrders;
ALTER TABLE dbo.Orders SET (SYSTEM_VERSIONING = OFF);
ALTER TABLE dbo.Orders DROP PERIOD FOR SYSTEM_TIME;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.OrdersHistory;
ALTER TABLE dbo.Customer SET (SYSTEM_VERSIONING = OFF);
ALTER TABLE dbo.Customer DROP PERIOD FOR SYSTEM_TIME;
DROP TABLE IF EXISTS dbo.Customer;
DROP TABLE IF EXISTS dbo.CustomerHistory;
GO


/* Optimizing Temporal Queries */
USE AdventureWorksDW2017;
GO
-- Create indexes on the interval boundaries
CREATE INDEX idx_sn 
 ON dbo.Sales(sn) INCLUDE(en);
CREATE INDEX idx_en 
 ON dbo.Sales(en) INCLUDE(sn);
GO


-- Classical solution for overlapping intervals
SET STATISTICS IO ON;
GO
-- beginning of data
DECLARE
 @sn AS INT = 370,
 @en AS INT = 400;
SELECT Id, sn, en
FROM dbo.Sales
WHERE sn <= @en AND en >= @sn
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seeks idx_sn
-- logical reads: 6

-- end of data
DECLARE
 @sn AS INT = 3640,
 @en AS INT = 3670;
SELECT Id, sn, en
FROM dbo.Sales
WHERE sn <= @en AND en >= @sn
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seeks idx_en
-- logical reads: 21

-- middle of data
DECLARE
 @sn AS INT = 1780,
 @en AS INT = 1810;
SELECT Id, sn, en
FROM dbo.Sales
WHERE sn <= @en AND en >= @sn
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seeks idx_sn
-- logical reads: 299

SET STATISTICS IO OFF;
GO


-- Modifying the Filter Predicate
SET STATISTICS IO ON;
GO

-- middle of data
-- Max length of an interval is 30
DECLARE
 @sn AS INT = 1780,
 @en AS INT = 1810;
SELECT Id, sn, en
FROM dbo.Sales
WHERE sn <= @en AND sn >= @sn - 30
  AND en >= @sn AND en <= @en + 30
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seeks idx_sn
-- logical reads: 9

-- middle of data
-- Max length of an interval is 900
DECLARE
 @sn AS INT = 1780,
 @en AS INT = 1810;
SELECT Id, sn, en
FROM dbo.Sales
WHERE sn <= @en AND sn >= @sn - 900
  AND en >= @sn AND en <= @en + 900
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seeks idx_sn
-- logical reads: 250

SET STATISTICS IO OFF;
GO


-- Using the Unpacked Form

-- Unpacked form with an indexed view
-- Create view Intervals_Unpacked
DROP VIEW IF EXISTS dbo.SalesU;
GO
CREATE VIEW dbo.SalesU
WITH SCHEMABINDING
AS
SELECT i.id, n.n
FROM dbo.Sales AS i
 INNER JOIN dbo.DateNums AS n
  ON n.n BETWEEN i.sn AND i.en;
GO
-- Index the view
CREATE UNIQUE CLUSTERED INDEX PK_SalesU
 ON dbo.SalesU(n, id);
GO


SET STATISTICS IO ON;
GO

-- Overlapping interval - middle of data
DECLARE
 @sn AS INT = 1780,
 @en AS INT = 1810;
SELECT id
FROM dbo.SalesU
WHERE n BETWEEN @sn AND @en
GROUP BY id
ORDER BY id
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seek in the clustered view
-- logical reads: 43


-- Space used
EXEC sys.sp_spaceused 'dbo.Sales';
EXEC sys.sp_spaceused 'dbo.SalesU';
GO

-- Included intervals - middle of data
DECLARE
 @sn AS INT = 1780,
 @en AS INT = 1810;
WITH OverlappingCTE AS
(
SELECT id
FROM dbo.SalesU
WHERE n BETWEEN @sn AND @en
GROUP BY id
)
SELECT s.id, s.sn, s.en
FROM dbo.Sales AS s
 INNER JOIN OverlappingCTE AS o
  ON s.id = o.id
WHERE @sn <= s.sn
  AND @en >= s.en
ORDER BY id
OPTION (RECOMPILE);     -- preventing plan reusage
GO
-- index seek in the clustered view
-- logical reads: 43 + 313

SET STATISTICS IO OFF;
GO

-- Clean up   
USE AdventureWorksDW2017;
DROP VIEW IF EXISTS dbo.SalesU;
DROP TABLE IF EXISTS dbo.Sales;
GO


/* Time Series */

-- Moving Averages
-- Using the dbo.vTimeSeries view

SELECT TOP 5 *
FROM dbo.vTimeSeries;

-- Aggregating the data, making the differences between months bigger
SELECT TimeIndex, 
 SUM(Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
GROUP BY TimeIndex
ORDER BY TimeIndex;

-- Simple - last 3 values
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
GROUP BY TimeIndex
)
SELECT TimeIndex,
 Quantity,
 AVG(Quantity) 
 OVER (ORDER BY TimeIndex 
       ROWS BETWEEN 2 PRECEDING
	     AND CURRENT ROW) AS SMA,
 DateIndex
FROM TSAggCTE
ORDER BY TimeIndex;
GO

-- Weighted  - last 2 values
DECLARE  @A AS FLOAT;
SET @A = 0.7;
WITH TSAggCTE AS
(
SELECT TimeIndex, 
 SUM(Quantity*2) - 200 AS Quantity, 
 DATEFROMPARTS(TimeIndex / 100, TimeIndex % 100, 1) AS DateIndex
FROM dbo.vTimeSeries
WHERE TimeIndex > 201012    -- December 2010 outlier, too small value
GROUP BY TimeIndex
)
SELECT TimeIndex,
 Quantity,
 AVG(Quantity) 
 OVER (ORDER BY TimeIndex 
       ROWS BETWEEN 2 PRECEDING
	     AND CURRENT ROW) AS SMA,
 @A * Quantity + (1 - @A) *
  ISNULL((LAG(Quantity) 
          OVER (ORDER BY TimeIndex)), Quantity)  AS WMA,
 DateIndex
FROM TSAggCTE
ORDER BY TimeIndex;
GO


-- Clean up
USE AdventureWorksDW2017;
DROP VIEW IF EXISTS dbo.SalesU;
DROP TABLE IF EXISTS dbo.Sales;
ALTER TABLE dbo.T1 SET (SYSTEM_VERSIONING = OFF);
DROP TABLE IF EXISTS dbo.T1;
DROP TABLE IF EXISTS dbo.T1_Hist;
GO
ALTER DATABASE AdventureWorksDW2017
 SET TEMPORAL_HISTORY_RETENTION ON;
GO
