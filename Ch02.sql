-- Advanced Analytics with Transact-SQL
-- Chapter 02: Associations between Pairs of Variables  

USE AdventureWorksDW2017;
GO

/* Continuous variables */

-- Covariance
-- l100km and mpg by hp
WITH CoVarCTE AS
(
SELECT l100km as val1,
 AVG(l100km) OVER() AS mean1,
 1.0 * hp AS val2,
 AVG(1.0 * hp) OVER() AS mean2,
 mpg AS val3,
 AVG(mpg) OVER() AS mean3
FROM dbo.mtcars
)
SELECT 
 SUM((val1-mean1)*(val2-mean2)) / (COUNT(*)-1) AS Covar1,
 SUM((val3-mean3)*(val2-mean2)) / (COUNT(*)-1) AS Covar2
FROM CoVarCTE;
GO

-- Covariance, correlation coeeficient,
-- and coefficient of determination

-- l100km and mpg by hp
WITH CoVarCTE AS
(
SELECT l100km as val1,
 AVG(l100km) OVER () AS mean1,
 1.0 * hp AS val2,
 AVG(1.0 * hp) OVER() AS mean2,
 mpg AS val3,
 AVG(mpg) OVER() AS mean3
FROM dbo.mtcars
)
SELECT N'l100km by hp' AS Variables,
 SUM((val1-mean1)*(val2-mean2)) / (COUNT(*)-1) AS Covar,
 (SUM((val1-mean1)*(val2-mean2)) / (COUNT(*)-1)) /
 (STDEV(val1) * STDEV(val2)) AS Correl,
 SQUARE((SUM((val1-mean1)*(val2-mean2)) / (COUNT(*)-1)) /
 (STDEV(val1) * STDEV(val2))) AS CD
FROM CoVarCTE
UNION
SELECT N'mpg by hp' AS Variables,
 SUM((val3-mean3)*(val2-mean2)) / (COUNT(*)-1) AS Covar,
 (SUM((val3-mean3)*(val2-mean2)) / (COUNT(*)-1)) /
 (STDEV(val3) * STDEV(val2)) AS Correl,
 SQUARE((SUM((val3-mean3)*(val2-mean2)) / (COUNT(*)-1)) /
 (STDEV(val3) * STDEV(val2))) AS CD
FROM CoVarCTE;


-- Using formula for the population
-- l100km and mpg by hp
WITH CoVarCTE AS
(
SELECT 
 l100km as val1,
 AVG(l100km) OVER () AS mean1,
 mpg as val3,
 AVG(mpg) OVER () AS mean3,
 1.0 * hp AS val2,
 AVG(1.0 * hp) OVER() AS mean2
FROM dbo.mtcars
)
SELECT N'l100km by hp' AS Variables,
 SUM((val1-mean1)*(val2-mean2)) / COUNT(*) AS Covar,
 (SUM((val1-mean1)*(val2-mean2)) / COUNT(*)) /
 (STDEVP(val1) * STDEVP(val2)) AS Correl,
 SQUARE((SUM((val1-mean1)*(val2-mean2)) / COUNT(*)) /
 (STDEVP(val1) * STDEVP(val2))) AS CD
FROM CoVarCTE
UNION
SELECT N'mpg by hp' AS Variables,
 SUM((val3-mean3)*(val2-mean2)) / COUNT(*) AS Covar,
 (SUM((val3-mean3)*(val2-mean2)) / COUNT(*)) /
 (STDEVP(val3) * STDEVP(val2)) AS Correl,
 SQUARE((SUM((val3-mean3)*(val2-mean2)) / COUNT(*)) /
 (STDEVP(val3) * STDEVP(val2))) AS CD
FROM CoVarCTE
ORDER BY Variables;
GO

-- Issues with non-linear relationships
CREATE TABLE #Nonlinear
 (x int,
  y AS SQUARE(x))
INSERT INTO #Nonlinear(x) 
VALUES(-2), (-1), (0), (1), (2)
GO
DECLARE @mean1 decimal(10,6)
DECLARE @mean2 decimal(10,6)
SELECT @mean1=AVG(x*1.0),
       @mean2=AVG(y*1.0)
  FROM #Nonlinear
SELECT Correl=
        (SUM((x*1.0-@mean1)*(y*1.0-@mean2))
         /COUNT(*))
        /((STDEVP(x*1.0)*STDEVP(y*1.0)))
FROM #Nonlinear
DROP TABLE #Nonlinear;
GO


/* Discrete variables */

-- Group by excludes empty rows
SELECT 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X,
 engine AS Y, 
 COUNT(*) AS obsXY
FROM dbo.mtcars
GROUP BY 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END
      ,engine
ORDER BY X, Y;

-- Use a cross join to generate all rows
SELECT X, Y
FROM 
(
SELECT DISTINCT
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X
FROM dbo.mtcars) AS a
CROSS JOIN
(
SELECT DISTINCT
 engine AS Y
FROM dbo.mtcars) AS b;


-- Group by with all rows
WITH o1 AS
(
SELECT 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X,
 engine AS Y, 
 COUNT(*) AS obsXY
FROM dbo.mtcars
GROUP BY 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END
      ,engine
),
o2 AS
(
SELECT X, Y
FROM 
(
SELECT DISTINCT
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X
FROM dbo.mtcars) AS a
CROSS JOIN
(
SELECT DISTINCT
 engine AS Y
FROM dbo.mtcars) AS b
)
SELECT o2.X, o2.Y, 
 ISNULL(o1.obsXY, 0) AS obsXY
FROM o2 LEFT OUTER JOIN o1
 ON o2.X = o1.X AND
    o2.Y = o1.Y
ORDER BY o2.X, o2.Y;


-- Contingency table with chi-squared contribution
WITH o1 AS
(
SELECT 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X,
 engine AS Y, 
 COUNT(*) AS obsXY
FROM dbo.mtcars
GROUP BY 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END
      ,engine
),
o2 AS
(
SELECT X, Y
FROM 
(
SELECT DISTINCT
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X
FROM dbo.mtcars) AS a
CROSS JOIN
(
SELECT DISTINCT
 engine AS Y
FROM dbo.mtcars) AS b
),
obsXY_CTE AS
(
SELECT o2.X, o2.Y, 
 ISNULL(o1.obsXY, 0) AS obsXY
FROM o2 LEFT OUTER JOIN o1
 ON o2.X = o1.X AND
    o2.Y = o1.Y
),
expXY_CTE AS
(
SELECT X, Y, obsXY
 ,SUM(obsXY) OVER (PARTITION BY X) AS obsX
 ,SUM(obsXY) OVER (PARTITION BY Y) AS obsY
 ,SUM(obsXY) OVER () AS obsTot
 ,CAST(ROUND(SUM(1.0 * obsXY) OVER (PARTITION BY X)
  * SUM(1.0 * obsXY) OVER (PARTITION BY Y) 
  / SUM(1.0 * obsXY) OVER (), 2) AS NUMERIC(6,2)) AS expXY
FROM obsXY_CTE
)
SELECT X, Y,
 obsXY, expXY,
 ROUND(SQUARE(obsXY - expXY) / expXY, 2) AS chiSq,
 CAST(ROUND(100.0 * obsXY / obsX, 2) AS NUMERIC(6,2)) AS rowPct,
 CAST(ROUND(100.0 * obsXY / obsY, 2) AS NUMERIC(6,2)) AS colPct,
 CAST(ROUND(100.0 * obsXY / obsTot, 2) AS NUMERIC(6,2)) AS totPct
FROM expXY_CTE
ORDER BY X, Y;
GO


-- Chi Squared and DF
WITH o1 AS
(
SELECT 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X,
 engine AS Y, 
 COUNT(*) AS obsXY
FROM dbo.mtcars
GROUP BY 
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END
      ,engine
),
o2 AS
(
SELECT X, Y
FROM 
(
SELECT DISTINCT
 CASE hpdescription 
       WHEN N'Weak' THEN N'1 - Weak'
	   WHEN N'Medium' THEN N'2 - Medium'
       WHEN N'Strong' THEN N'3 - Strong'
      END AS X
FROM dbo.mtcars) AS a
CROSS JOIN
(
SELECT DISTINCT
 engine AS Y
FROM dbo.mtcars) AS b
),
obsXY_CTE AS
(
SELECT o2.X, o2.Y, 
 ISNULL(o1.obsXY, 0) AS obsXY
FROM o2 LEFT OUTER JOIN o1
 ON o2.X = o1.X AND
    o2.Y = o1.Y
),
expXY_CTE AS
(
SELECT X, Y, obsXY
 ,SUM(obsXY) OVER (PARTITION BY X) AS obsX
 ,SUM(obsXY) OVER (PARTITION BY Y) AS obsY
 ,SUM(obsXY) OVER () AS obsTot
 ,ROUND(SUM(1.0 * obsXY) OVER (PARTITION BY X)
  * SUM(1.0 * obsXY) OVER (PARTITION BY Y) 
  / SUM(1.0 * obsXY) OVER (), 2) AS expXY
FROM obsXY_CTE
)
SELECT SUM(ROUND(SQUARE(obsXY - expXY) / expXY, 2)) AS ChiSquared,
 (COUNT(DISTINCT X) - 1) * (COUNT(DISTINCT Y) - 1) AS DegreesOfFreedom
FROM expXY_CTE;
GO


/* Discrete and Continuous variables */

-- All first population moments for weightkg grouped by 
-- transmission
WITH acs AS
(
SELECT transmission,
 weightkg,
 AVG(weightkg) OVER (PARTITION BY transmission) AS a,
 COUNT(*) OVER (PARTITION BY transmission) AS c,
 STDEV(weightkg) OVER (PARTITION BY transmission) AS s,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY weightkg)
  OVER (PARTITION BY transmission) AS m,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY weightkg) 
  OVER (PARTITION BY transmission)-
 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY weightkg) 
  OVER (PARTITION BY transmission) AS i
FROM dbo.mtcars
)
SELECT transmission,
 MIN(c) AS wCount,
 AVG(weightkg) AS wMean,
 MIN(m) AS wMedian,
 ROUND(MIN(s), 2) AS wStDev,
 MIN(i) AS wIQR,
 ROUND(MIN(s) / MIN(a), 2) AS wCV,
 ROUND(SUM(POWER((weightkg - a), 3) / POWER(s, 3)) / MIN(c), 2)
       AS wSkew,
 ROUND((SUM(POWER((weightkg - a), 4) / POWER(s, 4)) / MIN(c) - 
        3.0 * (MIN(c)-1) * (MIN(c)-1) / (MIN(c)-2) 
		/ (MIN(c)-3)), 2) AS wKurt
FROM acs
GROUP BY transmission
ORDER BY transmission;
GO

-- Control for a single group
WITH acs AS
(
SELECT weightkg,
 AVG(weightkg) OVER() AS a,
 COUNT(*) OVER() AS c,
 STDEV(weightkg) OVER() AS s,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY weightkg) OVER () AS m,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY weightkg) OVER () -
 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY weightkg) OVER () AS i
FROM dbo.mtcars
WHERE transmission = N'Automatic'
)
SELECT N'Automatic' AS transmission,
 MIN(c) AS wCount,
 MIN(a) AS wMean,
 MIN(m) AS wMedian,
 ROUND(MIN(s), 2) AS wStDev,
 MIN(i) AS wIQR,
 ROUND(MIN(s) / MIN(a), 2) AS wCV,
 ROUND(SUM(POWER((weightkg - a), 3) / POWER(s, 3)) / MIN(c), 2) AS wSkew,
 ROUND((SUM(POWER((weightkg - a), 4) / POWER(s, 4)) / MIN(c) - 
            3.0 * (MIN(c)-1) * (MIN(c)-1) / (MIN(c)-2) / (MIN(c)-3)), 2) AS wKurt
FROM acs;
GO

-- One-way ANOVA
WITH Anova_CTE AS
(
SELECT transmission, weightkg,
 COUNT(*) OVER (PARTITION BY transmission) AS gr_CasesCount,
 DENSE_RANK() OVER (ORDER BY transmission) AS gr_DenseRank,
 SQUARE(AVG(weightkg) OVER (PARTITION BY transmission) -
        AVG(weightkg) OVER ()) AS between_gr_SS,
 SQUARE(weightkg - 
        AVG(weightkg) OVER (PARTITION BY transmission)) 
		AS within_gr_SS
FROM dbo.mtcars
) 
SELECT N'Between groups' AS [Source of Variation],
 MAX(gr_DenseRank) - 1 AS df,
 ROUND(SUM(between_gr_SS), 0) AS [Sum Sq],
 ROUND(SUM(between_gr_SS) / (MAX(gr_DenseRank) - 1), 0)
  AS [Mean Sq],
 ROUND((SUM(between_gr_SS) / (MAX(gr_DenseRank) - 1)) /
 (SUM(within_gr_SS) / (COUNT(*) - MAX(gr_DenseRank))), 2)
  AS F
FROM Anova_CTE
UNION 
SELECT N'Within groups' AS [Source of Variation],
 COUNT(*) - MAX(gr_DenseRank) AS Df,
 ROUND(SUM(within_gr_SS), 0) AS [Sum Sq],
 ROUND(SUM(within_gr_SS) / (COUNT(*) - MAX(gr_DenseRank)), 0)
  AS [Mean Sq],
 NULL AS F
FROM Anova_CTE;
-- Calculating the cumulative F
-- Turn on the SQLCMD mode
!!C:\temp\FDistribution 27.64 1 30
GO

/* C# console application for F distribution */
/*

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows.Forms.DataVisualization.Charting;

class FDistribution
{
    static void Main(string[] args)
    {
        // Test input arguments
        if (args.Length != 3)
        {
            Console.WriteLine("Please use three arguments: double FValue, int DF1, int DF2.");
            //Console.ReadLine();
            return;
        }

        // Try to convert the input arguments to numbers. 
        // FValue
        double FValue;
        bool test = double.TryParse(args[0], System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture.NumberFormat, out FValue);
        if (test == false)
        {
            Console.WriteLine("First argument must be double (nnn.n).");
            return;
        }

        // DF1
        int DF1;
        test = int.TryParse(args[1], out DF1);
        if (test == false)
        {
            Console.WriteLine("Second argument must be int.");
            return;
        }

        // DF2
        int DF2;
        test = int.TryParse(args[2], out DF2);
        if (test == false)
        {
            Console.WriteLine("Third argument must be int.");
            return;
        }

        // Calculate the cumulative F distribution function probability
        Chart c = new Chart();
        double result = c.DataManipulator.Statistics.FDistribution(FValue, DF1, DF2);
        Console.WriteLine("Input parameters: " + 
            FValue.ToString(System.Globalization.CultureInfo.InvariantCulture.NumberFormat)
            + " " + DF1.ToString() + " " + DF2.ToString());
        Console.WriteLine("Cumulative F distribution function probability: " +
            result.ToString("P"));
    }
}

*/
/* C# console application for F distribution */


/* Definite integration */

-- Standard normal distribution table
CREATE TABLE #t1
(z DECIMAL(3,2),
 y DECIMAL(10,9));
GO
-- Insert the data
SET NOCOUNT ON;
GO
DECLARE @z DECIMAL(3,2), @y DECIMAL(10,9);
SET @z=-4.00;
WHILE @z <= 4.00
 BEGIN
  SET @y=1.00/SQRT(2.00*PI())*EXP((-1.00/2.00)*SQUARE(@z));
  INSERT INTO #t1(z,y) VALUES(@z, @y);
  SET @z=@z+0.01;
END
GO
SET NOCOUNT OFF;
GO
-- Check the data
SELECT *
FROM #t1;
GO

-- Trapezoidal rule for definite integration
-- Pct of area between 0 and 1
WITH z0 AS
(
SELECT z, y,
  FIRST_VALUE(y) OVER(ORDER BY z) AS fy,
  LAST_VALUE(y) 
   OVER(ORDER BY z
        ROWS BETWEEN UNBOUNDED PRECEDING
		 AND UNBOUNDED FOLLOWING) AS ly
FROM #t1
WHERE z >= 0 AND z <= 1
)
SELECT 100.0 * ((0.01 / 2.0) * 
 (SUM(2 * y) - MIN(fy) - MAX(ly))) AS pctdistribution
FROM z0;
-- Right tail after z = 1.96
WITH z0 AS
(
SELECT z, y,
  FIRST_VALUE(y) OVER(ORDER BY z) AS fy,
  LAST_VALUE(y) 
   OVER(ORDER BY z
        ROWS BETWEEN UNBOUNDED PRECEDING
		 AND UNBOUNDED FOLLOWING) AS ly
FROM #t1
WHERE (z >= 0 AND z <= 1.96)
)
SELECT 50 - 100.0 * ((0.01 / 2.0) * 
 (SUM(2 * y) - MIN(fy) - MAX(ly))) AS pctdistribution
FROM z0;
GO

-- Clean up
DROP TABLE #t1;
GO
