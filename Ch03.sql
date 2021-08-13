-- Advanced Analytics with Transact-SQL
-- Chapter 03: Data Preparation  

/*
1)	Dealing with Missing Values 
2)  String Operations
3)	Adding Derived Variables,
    Grouping Sets
4)	Data Normalization
5)	Converting Strings to Numerical Variables
6)	Discretizing Continuous Variables
*/

/* Missing values */
USE AdventureWorksDW2017;
DROP TABLE IF EXISTS #t1;
CREATE TABLE #t1
(
 col1 INT NULL,
 col2 INT NULL,
 col3 INT NULL
);
GO

INSERT INTO #t1 VALUES
(2, NULL, 6),
(8, 10, 12),
(NULL, 16, 18),
(20, 22, 24),
(26, NULL, NULL);
GO

-- Data
SELECT *
FROM #t1;

-- ISNULL and COALESCE
SELECT col1, 
 ISNULL(col1, 0) AS c1NULL,
 col2, col3, 
 COALESCE(col2, col3, 99) AS c2NULL
FROM #t1;
-- Aggregate functions
SELECT
 AVG(col2) AS c2AVG, 
 SUM(col2) AS c2SUM, 
 COUNT(*) AS n,
 SUM(1.0*col2)/COUNT(*) AS col2SumByCount
FROM #t1;
GO

-- The airquality dataset
/*
A discussion of R’s airquality dataset variables
https://www.rdocumentation.org/packages/datasets/versions/3.6.2/topics/airquality
*/

-- Load the airquality dataset
DROP TABLE IF EXISTS dbo.airquality;
CREATE TABLE dbo.airquality
(
 Ozone int,
 SolarR int,
 Wind int,
 Temp int,
 MonthInt int,
 DayInt int
);
GO
INSERT INTO dbo.airquality
EXECUTE sys.sp_execute_external_script
 @language=N'R',
 @script = N'
data("airquality")
 ',
 @output_data_1_name = N'airquality';
GO
SELECT *
FROM dbo.airquality;
GO

-- Checking amount of NULLs
SELECT IIF(Ozone IS NULL, N'NULL', N'Not NULL') AS OzoneN,
 COUNT(*) AS cnt
FROM dbo.airquality
GROUP BY IIF(Ozone IS NULL, N'NULL', N'Not NULL');
SELECT IIF(SolarR IS NULL, N'NULL', N'Not NULL') AS SolarRN,
 COUNT(*) AS cnt
FROM dbo.airquality
GROUP BY IIF(SolarR IS NULL, N'NULL', N'Not NULL');
GO

-- Adding indicator variable for missing values
SELECT *,
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow
FROM dbo.airquality;
-- Number of rows with NULLs
SELECT 
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 COUNT(*) AS cnt
FROM dbo.airquality
GROUP BY
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0);
-- 42 rows with NULLs in first two variables

-- Check the other variables in the classes of the NULL indicator
SELECT 
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 AVG(1.0 * Wind) AS WindA,
 AVG(1.0 * Wind) / STDEV(1.0 * Wind) AS WindCV,
 AVG(1.0 * Temp) AS TempA,
 AVG(1.0 * Temp) / STDEV(1.0 * Temp) AS TempCV
FROM dbo.airquality
GROUP BY
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0);
GO

-- Listwise filtering rows with NULLs
SELECT *
FROM dbo.airquality
WHERE
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0) = 0;
GO

-- Replacing SolarR NULLs with mean and median
SELECT SolarR,
 AVG(SolarR) OVER() AS SolarRA,
 ISNULL(SolarR, AVG(SolarR) OVER()) AS SolarRIA,
 PERCENTILE_CONT(0.5)
  WITHIN GROUP (ORDER BY SolarR) OVER() AS SolarM,
 ISNULL(SolarR,  PERCENTILE_CONT(0.5)
  WITHIN GROUP (ORDER BY SolarR) OVER()) AS SolarIM
FROM dbo.airquality;
GO


/* String operations */

-- Concatenation
SELECT FirstName, MiddleName, LastName,
 FirstName + MiddleName + LastName AS fn1,
 CONCAT(FirstName, MiddleName, LastName) AS fn2,
 CONCAT_WS(', ', FirstName, MiddleName, LastName) AS fn3
FROM dbo.vTargetMail;

-- Counting number of characters in a string
SELECT
 CONCAT_WS('.', FirstName, MiddleName, AddressLine1) AS s1,
 REPLACE(
  CONCAT_WS('.', FirstName, MiddleName, AddressLine1),
  '.', '') AS s2,
 LEN(CONCAT_WS('.', FirstName, MiddleName, AddressLine1))
  -
 LEN(
   REPLACE(
    CONCAT_WS('.', FirstName, MiddleName, AddressLine1),
    '.', '')
 ) AS nOfDots
FROM dbo.vTargetMail;

-- Using TRANSLATE
SELECT CONCAT_WS('. ', EmailAddress, AddressLine1) AS s1,
 TRANSLATE(
  CONCAT_WS('. ', EmailAddress, AddressLine1),
  '@.-', '?/*') AS s2
FROM dbo.vTargetMail;
GO

-- String aggregation
-- Casting to nvarchar(max)
SELECT EnglishEducation,
 STRING_AGG(CAST(MaritalStatus AS NVARCHAR(MAX)), ';')
  AS MSA
FROM dbo.vTargetMail
GROUP BY EnglishEducation;

-- Aggregation with order
SELECT EnglishEducation,
 STRING_AGG(CustomerKey, ';')
  WITHIN GROUP (ORDER BY CustomerKey DESC) AS CKA
FROM dbo.vTargetMail
WHERE CustomerKey < 11020
GROUP BY EnglishEducation;

-- Rowset function STRING_SPLIT
-- Used with APPLY
WITH CustCTE AS
(
SELECT EnglishEducation,
 STRING_AGG(CustomerKey, ';')
  WITHIN GROUP (ORDER BY CustomerKey DESC) AS CKA
FROM dbo.vTargetMail
WHERE CustomerKey < 11020
GROUP BY EnglishEducation
)
SELECT EnglishEducation, value AS CustomerKey
FROM CustCTE
 CROSS APPLY STRING_SPLIT(CKA, ';')
ORDER BY EnglishEducation DESC; 
GO


/* Adding Derived Variables */
SELECT 
 ISNULL(SolarR, AVG(SolarR) OVER()) AS SolarRIA,
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 FORMAT(MonthInt, '00') AS MonthChr,
 FORMAT(DayInt, '00') AS DayChr,
 DATENAME(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS NameDay,
 DATEPART(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS WeekDay,
 CASE 
  WHEN DATENAME(weekday, '1973' + 
    FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
   IN ('Saturday', 'Sunday') THEN 'Weekend'
  ELSE 'Workday'
 END AS TypeDay
FROM dbo.airquality;

/* Grouping Sets */
-- Basic group by
WITH grCTE AS
(
SELECT Ozone,
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 CAST( DATEPART(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00')) 
  AS CHAR(1)) + ' ' +
 DATENAME(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS NameDay
FROM dbo.airquality
)
SELECT NameDay, NullInRow,
 SUM(Ozone) AS OzoneTot
FROM grCTE
GROUP BY NameDay, NullInRow
ORDER BY NameDay, NullInRow;
-- Some NULLs
GO

-- Grouping sets
WITH grCTE AS
(
SELECT Ozone,
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 CAST( DATEPART(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00')) 
  AS CHAR(1)) + ' ' +
 DATENAME(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS NameDay
FROM dbo.airquality
)
SELECT NameDay, NullInRow,
 SUM(Ozone) AS OzoneTot
FROM grCTE
GROUP BY GROUPING SETS
 (NameDay, NullInRow)
ORDER BY NameDay, NullInRow;
-- Some NULLs

-- Cube
WITH grCTE AS
(
SELECT Ozone,
 IIF(IIF(Ozone IS NULL, 1, 0) = 1 OR 
     IIF(SolarR IS NULL, 1, 0) = 1, 1, 0)
 AS NullInRow,
 CAST( DATEPART(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00')) 
  AS CHAR(1)) + ' ' +
 DATENAME(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS NameDay
FROM dbo.airquality
)
SELECT NameDay, NullInRow,
 SUM(Ozone) AS OzoneTot
FROM grCTE
GROUP BY CUBE
 (NameDay, NullInRow)
ORDER BY NameDay, NullInRow;

-- Nulls in grouping variables
WITH grCTE AS
(
SELECT SolarR, 
 IIF(Ozone IS NULL, NULL, 'Ozone') AS Ozone,
 CAST( DATEPART(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00')) 
  AS CHAR(1)) + ' ' +
 DATENAME(weekday, '1973' + 
  FORMAT(MonthInt, '00') + FORMAT(DayInt, '00'))
 AS NameDay
FROM dbo.airquality
)
SELECT NameDay, 
 GROUPING(NameDay) AS NameDayGR,
 Ozone,
 GROUPING(Ozone) AS OzoneGR,
 GROUPING_ID(NameDay, Ozone) AS GRID,
 SUM(SolarR) AS SolarRTot
FROM grCTE
GROUP BY CUBE
 (NameDay, Ozone)
ORDER BY NameDay, Ozone, GRID DESC;
GO

/* Data normalization */

-- Range and Z-Score
WITH castCTE AS
(
SELECT MonthInt, DayInt,
 CAST(Wind AS NUMERIC(8,2)) AS Wind,
 CAST(SolarR AS NUMERIC(8,2)) AS SolarR
FROM dbo.airquality
)
SELECT MonthInt, DayInt,
 CAST(ROUND(
 (Wind - MIN(Wind) OVER()) /
  (MAX(Wind) OVER() - MIN(Wind) OVER())
 , 2) AS NUMERIC(8,2)) AS WindR,
 CAST(ROUND(
 (SolarR - MIN(SolarR) OVER()) /
  (MAX(SolarR) OVER() - MIN(SolarR) OVER())
 , 2) AS NUMERIC(8,2)) AS SolarRR,
 ROUND(
 (Wind - AVG(Wind) OVER()) /
  STDEV(Wind) OVER() 
 , 2) AS WindS,
 ROUND(
 (SolarR - AVG(SolarR) OVER()) /
  STDEV(SolarR) OVER()
 , 2) AS SolarRS
FROM castCTE	
ORDER BY MonthInt, DayInt;

-- Calculate mean and stdev for the normalized data
WITH castCTE AS
(
SELECT MonthInt, DayInt,
 CAST(Wind AS NUMERIC(8,2)) AS Wind,
 CAST(SolarR AS NUMERIC(8,2)) AS SolarR
FROM dbo.airquality
),
normCTE AS (
SELECT MonthInt, DayInt,
 CAST(ROUND(
 (Wind - MIN(Wind) OVER()) /
  (MAX(Wind) OVER() - MIN(Wind) OVER())
 , 2) AS NUMERIC(8,2)) AS WindR,
 CAST(ROUND(
 (SolarR - MIN(SolarR) OVER()) /
  (MAX(SolarR) OVER() - MIN(SolarR) OVER())
 , 2) AS NUMERIC(8,2)) AS SolarRR,
 ROUND(
 (Wind - AVG(Wind) OVER()) /
  STDEV(Wind) OVER() 
 , 2) AS WindS,
 ROUND(
 (SolarR - AVG(SolarR) OVER()) /
  STDEV(SolarR) OVER()
 , 2) AS SolarRS
FROM castCTE
)
SELECT 'Range' AS normType,
 ROUND(AVG(WindR), 4) AS avgWR, 
 ROUND(STDEV(WindR), 4) AS stdevWR,
 ROUND(AVG(SolarRR), 4) AS avgSR,
 ROUND(STDEV(SolarRR), 4) AS stdevSR
FROM normCTE
UNION ALL
SELECT 'Z-score' AS normType,
 ROUND(AVG(WindS), 4) AS avgWS, 
 ROUND(STDEV(WindS), 4) AS stdevWS,
 ROUND(AVG(SolarRS), 4) AS avgSS, 
 ROUND(STDEV(SolarRS), 4) AS stdevSS
FROM normCTE
ORDER BY normType;
GO

-- Logistic and hyperbolic tangent normalization
-- Demo table
DROP TABLE IF EXISTS dbo.norm;
CREATE TABLE dbo.norm
(x DECIMAL(3,2),
 y DECIMAL(5,4),
 yl DECIMAL(5,4),
 yth DECIMAL(5,4));
GO
-- Insert the data
SET NOCOUNT ON;
GO
DECLARE @x DECIMAL(3,2), @y DECIMAL(5,4),
  @yl DECIMAL(5,4), @yth DECIMAL(5,4);
SET @x=-6.00;
WHILE @x <= 6.00
 BEGIN
  SET @y = @x;
  SET @yl = 1.0 / (1.0 + EXP(-@x));
  SET @yth = (EXP(@x) - EXP(-@x)) / (EXP(@x) + EXP(-@x))
  INSERT INTO dbo.norm VALUES(@x, @y, @yl, @yth);
  SET @x=@x+0.1;
END
GO
SET NOCOUNT OFF;
GO
-- Check the data
SELECT *
FROM dbo.norm;
GO

-- Normalizing Wind
SELECT Wind,
 Wind - AVG(Wind) OVER() AS WindC,
 1.0 / (1.0 + EXP(-(Wind - AVG(Wind) OVER())))
  AS WindNLogistic,
 (EXP(Wind - AVG(Wind) OVER()) - EXP(-(Wind - AVG(Wind) OVER())))
 / 
 (EXP(Wind - AVG(Wind) OVER()) + EXP(-(Wind - AVG(Wind) OVER())))
  AS WindNTanH
FROM dbo.airquality;
GO


/* Converting strings to numerics */

-- Ordinal
SELECT carbrand,
 hp, hpdescription,
 CASE hpdescription 
  WHEN N'Weak' THEN 1
  WHEN N'Medium' THEN 2
  WHEN N'Strong' THEN 3
 END AS hpdescriptionint
FROM dbo.mtcars;

-- Checking the distribution
WITH frequency AS
(
SELECT 
 CASE hpdescription 
         WHEN N'Weak' THEN 1
		 WHEN N'Medium' THEN 2
         WHEN N'Strong' THEN 3
       END AS hpdescriptionint,
 COUNT(hpdescription) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(hpdescription)) /
       (SELECT COUNT(*) FROM dbo.mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS v
GROUP BY v.hpdescription
)
SELECT hpdescriptionint,
 AbsFreq,
 SUM(AbsFreq) 
  OVER(ORDER BY hpdescriptionint
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumFreq,
 AbsPerc,
 SUM(AbsPerc)
  OVER(ORDER BY hpdescriptionint
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumPerc,
 CAST(REPLICATE('*', AbsPerc) AS varchar(50)) AS Histogram
FROM frequency
ORDER BY hpdescriptionint;

-- Nominal - dummies
SELECT carbrand, engine,
 IIF(engine = 'V-shape', 1, 0)
  AS engineV,
 IIF(engine = 'Straight', 1, 0)
  AS engineS
FROM dbo.mtcars;

/* Discretizing Continuous Variables */

-- Binning hp
-- Data overview
SELECT MIN(hp) AS minA,
 MAX(hp) AS maxA,
 MAX(hp) - MIN(hp) AS rngA,
 AVG(hp) AS avgA,
 1.0 * (MAX(hp) - MIN(hp)) / 3 AS binwidth
FROM dbo.mtcars;

-- Equal width binning
DECLARE @binwidth AS NUMERIC(5,2), 
 @minA AS INT, @maxA AS INT;
SELECT @minA = MIN(hp),
 @maxa = MAX(hp),
 @binwidth = 1.0 * (MAX(hp) - MIN(hp)) / 3
FROM dbo.mtcars;
SELECT carbrand, hp,
 CASE 
  WHEN hp >= @minA + 0 * @binwidth AND hp < @minA + 1 * @binwidth
   THEN CAST((@minA + 0 * @binwidth) AS VARCHAR(10)) + ' - ' +
        CAST((@minA + 1 * @binwidth - 1) AS VARCHAR(10))
  WHEN hp >= @minA + 1 * @binwidth AND hp < @minA + 2 * @binwidth
   THEN CAST((@minA + 1 * @binwidth) AS VARCHAR(10)) + ' - ' +
        CAST((@minA + 2 * @binwidth - 1) AS VARCHAR(10))
  ELSE CAST((@minA + 2 * @binwidth) AS VARCHAR(10)) + ' + '
 END AS hpEWB
FROM dbo.mtcars
ORDER BY carbrand;
GO

-- Equal height binning
SELECT carbrand, hp,
 CAST(NTILE(3) OVER(ORDER BY hp)
  AS CHAR(1)) AS hpEHB
FROM dbo.mtcars
ORDER BY carbrand;
GO

-- Custom binning
SELECT carbrand, hp,
 IIF(hp > 175, '3 - Strong',
     IIF (hp < 100, '1 - Weak', '2 - Medium'))
  AS hpCUB
FROM dbo.mtcars
ORDER BY carbrand;
GO

-- All together
DECLARE @binwidth AS NUMERIC(5,2), 
 @minA AS INT, @maxA AS INT;
SELECT @minA = MIN(hp),
 @maxa = MAX(hp),
 @binwidth = 1.0 * (MAX(hp) - MIN(hp)) / 3
FROM dbo.mtcars;
SELECT carbrand, hp,
 CASE 
  WHEN hp >= @minA + 0 * @binwidth AND hp < @minA + 1 * @binwidth
   THEN CAST((@minA + 0 * @binwidth) AS VARCHAR(10)) + ' - ' +
        CAST((@minA + 1 * @binwidth - 1) AS VARCHAR(10))
  WHEN hp >= @minA + 1 * @binwidth AND hp < @minA + 2 * @binwidth
   THEN CAST((@minA + 1 * @binwidth) AS VARCHAR(10)) + ' - ' +
        CAST((@minA + 2 * @binwidth - 1) AS VARCHAR(10))
  ELSE CAST((@minA + 2 * @binwidth) AS VARCHAR(10)) + ' + '
 END AS hpEWB,
 CHAR(64 + (NTILE(3) OVER(ORDER BY hp)))
  AS hpEHB,
 IIF(hp > 175, '3 - Strong',
     IIF (hp < 100, '1 - Weak', '2 - Medium'))
  AS hpCUB
FROM dbo.mtcars
ORDER BY carbrand;
GO


-- Clean up
USE AdventureWorksDW2017;
DROP TABLE IF EXISTS #t1;
DROP TABLE IF EXISTS dbo.norm;
GO
