-- Advanced Analytics with Transact-SQL
-- Chapter 01: Descriptive Statistics 


-- Configure SQL Server to enable external scripts
USE master;
EXEC sys.sp_configure 'show advanced options', 1;
RECONFIGURE
EXEC sys.sp_configure 'external scripts enabled', 1; 
RECONFIGURE;
GO
-- Check the configuration
EXEC sys.sp_configure;
GO

-- Check R version
EXECUTE sys.sp_execute_external_script
 @language=N'R',
 @script = 
 N'str(OutputDataSet);
   OutputDataSet <- as.data.frame(R.version.string);'
WITH RESULT SETS ( ( VersionNumber nvarchar(50) ) );
GO

/*
A discussion of R’s mtcar dataset variables
https://rstudio-pubs-static.s3.amazonaws.com/61800_faea93548c6b49cc91cd0c5ef5059894.html
*/

-- Load the mtcars dataset
EXECUTE sys.sp_execute_external_script
 @language=N'R',
 @script = N'
data("mtcars")
mtcars$l100km = round(235.214583 / mtcars$mpg, 2)
mtcars$dispcc = round(mtcars$disp * 16.38706, 2)
mtcars$kw = round(mtcars$hp * 0.7457, 2)
mtcars$weightkg = round(mtcars$wt * 1000 * 0.453592, 2)
mtcars$transmission = factor(ifelse(mtcars$am == 0, "Automatic", "Manual"))
mtcars$engine = factor(ifelse(mtcars$vs == 0, "V-shape", "Straight"))
mtcars$hpdescription = 
  factor(ifelse(mtcars$hp > 175, "Strong", 
                ifelse(mtcars$hp < 100, "Weak", "Medium")),
         order = TRUE,
         levels = c("Weak", "Medium", "Strong"))
mtcars$carbrand = row.names(mtcars)
 ',
 @output_data_1_name = N'mtcars'
WITH RESULT SETS ((
 mpg numeric(8,2),
 cyl int,
 disp numeric(8,2),
 hp int,
 drat numeric(8,2),
 wt numeric(8,3),
 qsec numeric(8,2),
 vs int,
 am int,
 gear int,
 carb int,
 l100km numeric(8,2),
 dispcc numeric(8,2),
 kw numeric(8,2),
 weightkg numeric(8,2),
 transmission nvarchar(10),
 engine nvarchar(10),
 hpdescription nvarchar(10),
 carbrand nvarchar(20)
));
GO


-- Create a new table in the AWDW database
USE AdventureWorksDW2017;
DROP TABLE IF EXISTS dbo.mtcars;
CREATE TABLE dbo.mtcars
(
 mpg numeric(8,2),
 cyl int,
 disp numeric(8,2),
 hp int,
 drat numeric(8,2),
 wt numeric(8,3),
 qsec numeric(8,2),
 vs int,
 am int,
 gear int,
 carb int,
 l100km numeric(8,2),
 dispcc numeric(8,2),
 kw numeric(8,2),
 weightkg numeric(8,2),
 transmission nvarchar(10),
 engine nvarchar(10),
 hpdescription nvarchar(10),
 carbrand nvarchar(20) PRIMARY KEY
)
GO

-- Insert the mtcars dataset
INSERT INTO dbo.mtcars
EXECUTE sys.sp_execute_external_script
 @language=N'R',
 @script = N'
data("mtcars")
mtcars$l100km = round(235.214583 / mtcars$mpg, 2)
mtcars$dispcc = round(mtcars$disp * 16.38706, 2)
mtcars$kw = round(mtcars$hp * 0.7457, 2)
mtcars$weightkg = round(mtcars$wt * 1000 * 0.453592, 2)
mtcars$transmission = ifelse(mtcars$am == 0, "Automatic", "Manual")
mtcars$engine = ifelse(mtcars$vs == 0, "V-shape", "Straight")
mtcars$hpdescription = 
  factor(ifelse(mtcars$hp > 175, "Strong", 
                ifelse(mtcars$hp < 100, "Weak", "Medium")),
         order = TRUE,
         levels = c("Weak", "Medium", "Strong"))
mtcars$carbrand = row.names(mtcars)
 ',
 @output_data_1_name = N'mtcars';
GO
SELECT *
FROM dbo.mtcars;
GO


-- Frequencies

-- Simple, nominals
SELECT c.transmission,
 COUNT(c.transmission) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(c.transmission)) /
       (SELECT COUNT(*) FROM mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS c
GROUP BY c.transmission;

-- Adding the histogram
WITH freqCTE AS
(
SELECT c.transmission,
 COUNT(c.transmission) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(c.transmission)) /
       (SELECT COUNT(*) FROM mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS c
GROUP BY c.transmission
)
SELECT transmission,
 AbsFreq,
 AbsPerc,
 CAST(REPLICATE('*', AbsPerc) AS varchar(50)) AS Histogram
FROM freqCTE;

-- Ordinals - simple with numerics
WITH frequency AS
(
SELECT v.cyl,
 COUNT(v.cyl) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(v.cyl)) /
       (SELECT COUNT(*) FROM dbo.mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS v
GROUP BY v.cyl
)
SELECT cyl,
 AbsFreq,
 SUM(AbsFreq) 
  OVER(ORDER BY cyl 
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumFreq,
 AbsPerc,
 SUM(AbsPerc)
  OVER(ORDER BY cyl
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumPerc,
 CAST(REPLICATE('*', AbsPerc) AS varchar(50)) AS Histogram
FROM frequency
ORDER BY cyl;

-- Ordinals - incorrect order with strings
WITH frequency AS
(
SELECT v.hpdescription,
 COUNT(v.hpdescription) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(v.hpdescription)) /
       (SELECT COUNT(*) FROM dbo.mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS v
GROUP BY v.hpdescription
)
SELECT hpdescription,
 AbsFreq,
 SUM(AbsFreq) 
  OVER(ORDER BY hpdescription 
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumFreq,
 AbsPerc,
 SUM(AbsPerc)
  OVER(ORDER BY hpdescription
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumPerc,
 CAST(REPLICATE('*', AbsPerc) AS varchar(50)) AS Histogram
FROM frequency
ORDER BY hpdescription;

-- Ordinals - correct order
WITH frequency AS
(
SELECT 
 CASE v.hpdescription 
         WHEN N'Weak' THEN N'1 - Weak'
		 WHEN N'Medium' THEN N'2 - Medium'
         WHEN N'Strong' THEN N'3 - Strong'
       END AS hpdescriptionord,
 COUNT(v.hpdescription) AS AbsFreq,
 CAST(ROUND(100. * (COUNT(v.hpdescription)) /
       (SELECT COUNT(*) FROM dbo.mtcars), 0) AS int) AS AbsPerc
FROM dbo.mtcars AS v
GROUP BY v.hpdescription
)
SELECT hpdescriptionord,
 AbsFreq,
 SUM(AbsFreq) 
  OVER(ORDER BY hpdescriptionord 
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumFreq,
 AbsPerc,
 SUM(AbsPerc)
  OVER(ORDER BY hpdescriptionord
       ROWS BETWEEN UNBOUNDED PRECEDING
	    AND CURRENT ROW) AS CumPerc,
 CAST(REPLICATE('*', AbsPerc) AS varchar(50)) AS Histogram
FROM frequency
ORDER BY hpdescriptionord;


-- Centers

-- Mode
/* Centers of a distribution */

-- Median
-- Difference between PERCENTILE_CONT() and PERCENTILE_DISC()
SELECT DISTINCT			-- can also use TOP (1)
 PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY val) OVER () AS MedianDisc,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY val) OVER () AS MedianCont
FROM (VALUES (1), (2), (3), (4)) AS a(val);
GO

-- PERCENTILE_CONT on mtcars
SELECT 
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY weightkg) OVER () AS median
FROM dbo.mtcars;
GO

-- Mean and median
-- Weight and hp
WITH medianW AS
(
SELECT N'weight' AS variable, weightkg,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY weightkg) OVER () AS median
FROM dbo.mtcars
),
medianH AS
(
SELECT N'hp' AS variable, hp,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hp) OVER () AS median
FROM dbo.mtcars
)
SELECT 
 MIN(variable) AS variable,
 AVG(weightkg) AS average,
 MIN(median) AS median
FROM medianW
UNION
SELECT 
 MIN(variable) AS variable,
 AVG(hp) AS average,
 MIN(median) AS median
FROM medianH
ORDER BY variable;
GO

-- Trimmed mean
WITH rownumbers AS
(
SELECT hp,
 ROW_NUMBER() OVER(ORDER BY hp ASC) AS rna,
 ROW_NUMBER() OVER(ORDER BY hp DESC) AS rnd
FROM dbo.mtcars
)
SELECT AVG(hp) AS trimmedMean
FROM rownumbers
WHERE rna > 3 AND rnd > 3;
GO

SET NOCOUNT ON;
-- Mode
-- Single mode
SELECT TOP (1) WITH TIES weightkg, COUNT(*) AS n
FROM dbo.mtcars
GROUP BY weightkg
ORDER BY COUNT(*) DESC;
-- Multimodal distribution
SELECT TOP (1) WITH TIES hp, COUNT(*) AS n
FROM dbo.mtcars
GROUP BY hp
ORDER BY COUNT(*) DESC;
GO


-- Spread

-- Range
SELECT MAX(weightkg) - MIN(weightkg) AS rangeWeight,
 MAX(hp) - MIN(hp) AS rangeHp
FROM dbo.mtcars;
GO

-- IQR
SELECT DISTINCT
 PERCENTILE_CONT(0.75) WITHIN GROUP
  (ORDER BY 1.0*weightkg) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP
  (ORDER BY 1.0*weightkg) OVER () AS weightkgIQR,
 PERCENTILE_CONT(0.75) WITHIN GROUP
  (ORDER BY 1.0*hp) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP
  (ORDER BY 1.0*hp) OVER () AS hpIQR
FROM dbo.mtcars;
GO

-- Variance, standard deviation, coefFicient of variation
SELECT 
 ROUND(VAR(weightkg), 2) AS weightVAR,
 ROUND(STDEV(weightkg), 2) AS weightSD,
 ROUND(VAR(hp), 2) AS hpVAR,
 ROUND(STDEV(hp), 2) AS hpSD,
 ROUND(STDEV(weightkg) / AVG(weightkg), 2) AS weightCV,
 ROUND(STDEV(hp) / AVG(hp), 2) AS hpCV
FROM dbo.mtcars;
GO

-- IQR and standard deviation for hp
SELECT DISTINCT
 PERCENTILE_CONT(0.75) WITHIN GROUP
  (ORDER BY 1.0*hp) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP
  (ORDER BY 1.0*hp) OVER () AS hpIQR,
 STDEV(hp) OVER() AS hpSD
FROM dbo.mtcars;
GO


-- Skewness and kurtosis
WITH acs AS
(
SELECT hp,
 AVG(hp) OVER() AS a,
 COUNT(*) OVER() AS c,
 STDEV(hp) OVER() AS s
FROM dbo.mtcars
)
SELECT SUM(POWER((hp - a), 3) / POWER(s, 3)) / MIN(c) AS skewness,
 (SUM(POWER((hp - a), 4) / POWER(s, 4)) / MIN(c) - 
 3.0 * (MIN(c)-1) * (MIN(c)-1) / (MIN(c)-2) / (MIN(c)-3)) AS kurtosis
FROM acs;
GO

-- All first population moments for hp
WITH acs AS
(
SELECT hp,
 AVG(hp) OVER() AS a,
 COUNT(*) OVER() AS c,
 STDEV(hp) OVER() AS s,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hp) OVER () AS m,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY hp) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY hp) OVER () AS i
FROM dbo.mtcars
)
SELECT MIN(c) AS hpCount,
 MIN(a) AS hpMean,
 MIN(m) AS hpMedian,
 ROUND(MIN(s), 2) AS hpStDev,
 MIN(i) AS hpIQR,
 ROUND(MIN(s) / MIN(a), 2) AS hpCV,
 ROUND(SUM(POWER((hp - a), 3) / POWER(s, 3)) / MIN(c), 2) AS hpSkew,
 ROUND((SUM(POWER((hp - a), 4) / POWER(s, 4)) / MIN(c) - 
            3.0 * (MIN(c)-1) * (MIN(c)-1) / (MIN(c)-2) / (MIN(c)-3)), 2) AS hpKurt
FROM acs;
GO

-- All first population moments for hp grouped by engine
WITH acs AS
(
SELECT engine,
 hp,
 AVG(hp) OVER() AS a,
 COUNT(*) OVER() AS c,
 STDEV(hp) OVER() AS s,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hp) OVER () AS m,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY hp) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY hp) OVER () AS i
FROM dbo.mtcars
)
SELECT engine,
 MIN(c) AS hpCount,
 MIN(a) AS hpMean,
 MIN(m) AS hpMedian,
 ROUND(MIN(s), 2) AS hpStDev,
 MIN(i) AS hpIQR,
 ROUND(MIN(s) / MIN(a), 2) AS hpCV,
 ROUND(SUM(POWER((hp - a), 3) / POWER(s, 3)) / MIN(c), 2) AS hpSkew,
 ROUND((SUM(POWER((hp - a), 4) / POWER(s, 4)) / MIN(c) - 
            3.0 * (MIN(c)-1) * (MIN(c)-1) / (MIN(c)-2) / (MIN(c)-3)), 2) AS hpKurt
FROM acs
GROUP BY engine
ORDER BY engine;
GO


SET NOCOUNT OFF;
GO
