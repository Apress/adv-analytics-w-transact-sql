-- Advanced Analytics with Transact-SQL
-- Chapter 08: Data Mining


/*
1)  Introducing Full-Text Search
    Full-Text Predicates
    Full-Text Functions
    Statistical Semantic Search
2)  Quantitative Analysis
    Analysis of Letters
    Word Length Analysis
3)  Advanced Analysis of Text
    Term Extraction
    Words Associations
*/

-- Demo data
-- Check whether Full-Text and Semantic search is installed
SELECT SERVERPROPERTY('IsFullTextInstalled');
-- Check the filters
EXEC sys.sp_help_fulltext_system_components 'filter'; 
SELECT * FROM sys.fulltext_document_types;
GO
-- Download and install Office 2010 filter pack and SP 2 for the pack
-- Next, load them
/*
EXEC sys.sp_fulltext_service 'load_os_resources', 1;
GO
*/
-- Restart SQL Server
-- Check the filters again
/*
EXEC sys.sp_help_fulltext_system_components 'filter'; 
SELECT * FROM sys.fulltext_document_types;
GO
*/
-- Office 2010 filters should be installed

-- Demo db
CREATE DATABASE FTSSS;
GO
USE FTSSS;
-- Table for documents for FTSSS
CREATE TABLE dbo.Documents
(
  Id INT IDENTITY(1,1) NOT NULL,
  Title NVARCHAR(100) NOT NULL,
  docType NCHAR(4) NOT NULL,
  docExcerpt NVARCHAR(1000) NOT NULL,
  docContent VARBINARY(MAX) NOT NULL,
  CONSTRAINT PK_Documents 
   PRIMARY KEY CLUSTERED(id)
);
GO
/* Truncate if needed
TRUNCATE TABLE dbo.Documents;
GO
*/

-- Insert data
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Columnstore Indices and Batch Processing', 
 N'docx',
 N'You should use a columnstore index on your fact tables,
   putting all columns of a fact table in a columnstore index. 
   In addition to fact tables, very large dimensions could benefit 
   from columnstore indices as well. 
   Do not use columnstore indices for small dimensions. ',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\01_CIBatchProcessing.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Introduction to Data Mining', 
 N'docx',
 N'Using Data Mining is becoming more a necessity for every company 
   and not an advantage of some rare companies anymore. ',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\02_IntroductionToDataMining.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Why Is Bleeding Edge a Different Conference', 
 N'docx',
 N'During high level presentations attendees encounter 
   many questions. For the third year, we are continuing 
   with the breakfast Q&A session. It is very popular, 
   and for two years now, we could not accommodate enough 
   time for all questions and discussions! ',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\03_BleedingEdgeDifferent.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Additivity of Measures', 
 N'docx',
 N'Additivity of measures is not exactly a data warehouse 
   design problem. However, you have to realize which 
   aggregate functions you will use in reports for which measure, 
   and which aggregate functions you will use when aggregating 
   over which dimension.',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\04_AdditivityOfMeasures.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Transparent Data Encryption', 
 N'docx',
 N'Besides sensitive data, for which you could use the column encryption, 
   you might want to protect all of your data also against physical theft 
   of your computer, your hard drives, or database and log files. 
   Once the SQL Server service is stopped, it is possible to copy 
   the database and the log files and attach them to 
   another instance of SQL Server. 
   If the data is not encrypted, the it is fully exposed to the attacker. 
   Transparent data encryption (TDE) can help you protecting data at rest, 
   when your SQL Server instance is not running.',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\05_TransparentdataEncryption.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Introducing JSON', 
 N'docx',
 N'Although XML is a standard for many years, 
   many developers did not like it because it is somehow too verbose.  
   Especially when you use element-centric XML, you have each element 
   name for every value listed twice in your XML document. 
   In addition, XML is not very clear for reading. 
   Don’t understand this incorrectly: XML is here to stay. 
   It is the standard for many things, for example for 
   calling Web services, for storing configurations, 
   for exchanging data, and more. 
   Nevertheless, a new simplified standard JSON evolved in last decade. 
   JSON is simpler, easier to read than XML, focused on data exchange. ',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\06_IntroducingJSON.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Always Encrypted', 
 N'docx',
 N'SQL Server 2016 introduced a new level of encryption, 
   the Always Encrypted (AE) feature. 
   This feature enables the same level of data protection 
   as encrypting the data in the client application. 
   Actually, although this is a SQL Server feature, 
   the data is encrypted and decrypted on the client side. 
   The encryption keys are never revealed to the 
   SQL Server Database Engine. This way, a DBA cannot also see 
   sensitive data without the encryption keys, 
   just by having sysadmin permissions on the SQL Server instance 
   with the encrypted data. 
   This way, AE makes a separation between the administrators 
   who manage the data and the users who own the data.',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\07_AlwaysEncrypted.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'JSON Functions', 
 N'docx',
 N'You don’t just produce JSON from T-SQL queries, 
   you can also read JSON data and present it in tabular format. 
   You can also extract scalar values and subdocuments from 
   a JSON document. You can modify a JSON document, 
   and you can test if the document is valid. 
   I am introducing the JSON functions that allow 
   you to perform the mentioned tasks in this article.',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\08_JSONFunctions.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Column Encryption', 
 N'docx',
 N'Backup encryption encrypts backups only. 
   It does not encrypt data in data files. You can encrypt 
   data in tables with T-SQL using column-level encryption. 
   Column-level encryption is present in SQL Server from 
   version 2008 onwards. You encrypt the data in a specific 
   column by using a symmetric key. You protect the symmetric key 
   with an asymmetric key or a certificate. 
   The keys and the certificate are stored inside your database 
   where the tables with the encrypted columns are. 
   You protect the asymmetric key or the certificate 
   with the database master key. ',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\09_ColumnEncryption.docx', 
                SINGLE_BLOB) AS doc;
---
INSERT INTO dbo.Documents
(Title, docType, docExcerpt, docContent)
SELECT N'Transparent Data Encryption', 
 N'docx',
 N'You might want to protect all of your data also against
   physical theft of your computer, your hard drives, 
   or database and log files. Once the SQL Server service is stopped, 
   it is possible to copy the database and the log files 
   and attach them to another instance of SQL Server. 
   If the data is not encrypted, it is fully exposed 
   to the attacker. Transparent data encryption (TDE) can help you 
   protecting data at rest, 
   when your SQL Server instance is not running.',
 bulkcolumn
FROM OPENROWSET(BULK 'C:\Apress\Ch08\10_TDE.docx', 
                SINGLE_BLOB) AS doc;
GO

SELECT *
FROM dbo.Documents;
GO

-- Check whether Semantic Language Statistics Database is installed
SELECT * 
FROM sys.fulltext_semantic_language_statistics_database;
GO
-- Install Semantic Language Statistics Database
-- Run the SemanticLanguageDatabase.msi from D:\x64\Setup
-- Attach the database
/*
CREATE DATABASE semanticsdb ON
 (FILENAME = 'C:\Program Files\Microsoft Semantic Language Database\semanticsdb.mdf'),
 (FILENAME = 'C:\Program Files\Microsoft Semantic Language Database\semanticsdb_log.ldf')
 FOR ATTACH;
GO
*/
-- Register it
/*
EXEC sp_fulltext_semantic_register_language_statistics_db
 @dbname = N'semanticsdb';
GO
*/
/* Check again
SELECT * 
FROM sys.fulltext_semantic_language_statistics_database;
GO
*/


-- Introducing Full-Text Search
/* Check the stoplists
SELECT *
FROM sys.fulltext_stoplists;
SELECT *
FROM sys.fulltext_stopwords;
GO

-- System stopwords
SELECT *
FROM sys.fulltext_system_stopwords 
WHERE language_id = 1033;
*/

-- Creating the stoplist
CREATE FULLTEXT STOPLIST SQLStopList
FROM SYSTEM STOPLIST;  
GO  
ALTER FULLTEXT STOPLIST SQLStopList
 ADD 'SQL' LANGUAGE 'English';
GO
-- Check the Stopwords list
SELECT w.stoplist_id,
 l.name,
 w.stopword,
 w.language
FROM sys.fulltext_stopwords AS w
 INNER JOIN sys.fulltext_stoplists AS l
  ON w.stoplist_id = l.stoplist_id
WHERE language = N'English'
  AND stopword LIKE N'S%';
GO

-- Test parsing
-- Check the correct stoplist id
SELECT * 
FROM sys.dm_fts_parser
(N'"Additivity of measures is not exactly a data warehouse design problem. 
   However, you have to realize which aggregate functions you will use 
   in reports for which measure, and which aggregate functions 
   you will use when aggregating over which dimension."', 1033, 5, 0);
SELECT * 
FROM sys.dm_fts_parser
('FORMSOF(INFLECTIONAL,'+ 'function' + ')', 1033, 5, 0);
GO

-- Full-text catalog
CREATE FULLTEXT CATALOG DocumentsFtCatalog;
GO
-- Full-text index
CREATE FULLTEXT INDEX ON dbo.Documents
( 
  docExcerpt Language 1033, 
  docContent TYPE COLUMN doctype
  Language 1033
  STATISTICAL_SEMANTICS
)
KEY INDEX PK_Documents
ON DocumentsFtCatalog
WITH STOPLIST = SQLStopList, 
	 CHANGE_TRACKING AUTO;
GO

-- Check the population status
SELECT name, status_description
FROM sys.dm_fts_active_catalogs
WHERE database_id = DB_ID();
GO

-- Full-Text Predicates
-- Simple query
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'data');
-- Logical operators - OR
SELECT id, title, docexcerpt
FROM dbo.Documents
WHERE CONTAINS(docexcerpt, N'data OR index');
-- Logical operators - AND NOT
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'data AND NOT mining');
-- Logical operators - parentheses
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docexcerpt, N'data AND (fact OR warehouse)');

-- Phrase
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'"data warehouse"');
-- Prefix
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'"add*"');
-- Proximity
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'NEAR(problem, data)');

-- Inflectional forms
-- The next query does not return any rows
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'presentation');
-- The next query returns a row
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'FORMSOF(INFLECTIONAL, presentation)');
GO

/*
-- Thesaurus
-- Edit the US English thesaurus file tsenu.xml to have the following content:
/*
<XML ID="Microsoft Search Thesaurus">
    <thesaurus xmlns="x-schema:tsSchema.xml">
	<diacritics_sensitive>0</diacritics_sensitive>
        <expansion>
            <sub>Internet Explorer</sub>
            <sub>IE</sub>
            <sub>IE5</sub>
        </expansion>
        <replacement>
            <pat>NT5</pat>
            <pat>W2K</pat>
            <sub>Windows 2000</sub>
        </replacement>
        <expansion>
            <sub>run</sub>
            <sub>jog</sub>
        </expansion>
        <expansion>
            <sub>need</sub>
            <sub>necessity</sub>
        </expansion>
    </thesaurus>
</XML>
*/
-- Load the US English file
EXEC sys.sp_fulltext_load_thesaurus_file 1033;
GO

-- Synonyms
-- The next query does not return any rows
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'need');
-- The next query returns a row
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE CONTAINS(docExcerpt, N'FORMSOF(THESAURUS, need)');
*/

-- FREETEXT
SELECT Id, Title, docExcerpt
FROM dbo.Documents
WHERE FREETEXT(docExcerpt, N'data presentation need');
GO


-- Full-Text Functions
-- Rank with CONTAINSTABLE
SELECT D.Id, D.Title, CT.[RANK], D.docExcerpt
FROM CONTAINSTABLE(dbo.Documents, docExcerpt, 
      N'data OR level') AS CT
 INNER JOIN dbo.Documents AS D
  ON CT.[KEY] = D.Id
ORDER BY CT.[RANK] DESC;

-- Rank with FREETEXTTABLE
SELECT D.Id, D.Title, FT.[RANK], D.docExcerpt
FROM FREETEXTTABLE (dbo.Documents, docExcerpt, 
      N'data level') AS FT
 INNER JOIN dbo.Documents AS D
  ON FT.[KEY] = D.Id
ORDER BY FT.[RANK] DESC;

-- Weighted terms
SELECT D.Id, D.Title, CT.[RANK], D.docExcerpt
FROM CONTAINSTABLE
      (dbo.Documents, docExcerpt, 
       N'ISABOUT(data weight(0.2), level weight(0.8))') AS CT
 INNER JOIN dbo.Documents AS D
  ON CT.[KEY] = D.Id
ORDER BY CT.[RANK] DESC;

-- Proximity term
SELECT D.Id, D.Title, CT.[RANK]
FROM CONTAINSTABLE (dbo.Documents, docContent, 
      N'NEAR((data, row), 30)') AS CT
 INNER JOIN dbo.Documents AS D
  ON CT.[KEY] = D.Id
ORDER BY CT.[RANK] DESC;


-- Statistical Semantic Search
-- Top 100 semantic key phrases
SELECT TOP (100)
 D.Id, D.Title, SKT.keyphrase, SKT.score
FROM SEMANTICKEYPHRASETABLE
      (dbo.Documents, doccontent) AS SKT
 INNER JOIN dbo.Documents AS D
  ON SKT.document_key = D.Id
ORDER BY SKT.score DESC;

-- Documents that are similar to document 1
SELECT SST.matched_document_key, 
 D.Title, SST.score
FROM SEMANTICSIMILARITYTABLE
     (dbo.Documents, doccontent, 1) AS SST
 INNER JOIN dbo.Documents AS D
  ON SST.matched_document_key = D.Id
ORDER BY SST.score DESC;

-- Key phrases that are common across two documents. 
SELECT SSDT.keyphrase, SSDT.score
FROM SEMANTICSIMILARITYDETAILSTABLE
      (dbo.Documents, docContent, 1,
       docContent, 4) AS SSDT
WHERE SSDT.keyphrase NOT IN (N'sarka', N'dejan')
ORDER BY SSDT.score DESC;
GO

-- Full Text Languages
SELECT *
FROM sys.fulltext_languages
ORDER BY name;
-- Semantic Search Languages
SELECT *
FROM sys.fulltext_semantic_languages
ORDER BY name;
GO



-- Quantitative Analysis

-- Analysis of Letters
-- Getting individual characters from strings
-- Splitting a single string
SELECT SUBSTRING(a.s, d.n, 1) AS Chr, d.n AS Pos,
  ASCII(SUBSTRING(a.s, d.n, 1)) AS Cod
FROM (SELECT 'TestWord AndAnotherWord' AS s) AS a
 INNER JOIN AdventureWorksDW2017.dbo.DateNums AS d 
  ON d.n <= LEN(a.s);

-- Spliting a string column of a table
SELECT a.docExcerpt AS Id,
  d.n AS Pos,
  SUBSTRING(a.docExcerpt, d.n, 1) AS Chr, 
  UPPER(SUBSTRING(a.docExcerpt, d.n, 1)) AS Chu, 
  ASCII(SUBSTRING(a.docExcerpt, d.n, 1)) AS Cod,
  ASCII(UPPER(SUBSTRING(a.docExcerpt, d.n, 1))) AS Cdu
FROM dbo.Documents AS a
 INNER JOIN AdventureWorksDW2017.dbo.DateNums AS d 
  ON d.n <= LEN(a.docExcerpt)
ORDER BY id, pos;

-- Quantitative analysis of letters
SELECT UPPER(SUBSTRING(a.docExcerpt, d.n, 1)) AS Chu,
  COUNT(*) AS Cnt
FROM dbo.Documents AS a
 INNER JOIN AdventureWorksDW2017.dbo.DateNums AS d 
  ON d.n <= LEN(a.docexcerpt)
WHERE ASCII(UPPER(SUBSTRING(a.docExcerpt, d.n, 1))) BETWEEN 65 AND 90
GROUP BY UPPER(SUBSTRING(a.docExcerpt, d.n, 1))
ORDER BY Cnt DESC;

-- Analysis of Words

-- Getting the words from the docExcerpt
SELECT display_term, LEN(display_term) AS trlen
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2;

-- Words length frequencies
WITH trCTE AS
(
SELECT display_term, LEN(display_term) AS trlen
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
),
trlCTE AS
(
SELECT trLen,
 COUNT(*) AS Cnt
FROM trCTE
GROUP BY trLen
)
SELECT trLen, Cnt,
 CAST(ROUND(100. * cnt / SUM(cnt) OVER(), 0) AS INT) AS Pct,
 CAST(REPLICATE('*', ROUND(100. * cnt / SUM(cnt) OVER(), 0))
  AS VARCHAR(50)) AS Hst
FROM trlCTE
ORDER BY trLen;

-- Terms with the first occurrence
-- Getting all terms 
SELECT Id, Title, display_term, occurrence,
 (LEN(docExcerpt) - LEN(REPLACE(docExcerpt, display_term, '')))
  / LEN(display_term) AS tfIndoc
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
ORDER BY Id, tfIndoc DESC;

-- Just the first occurence
-- Getting all terms 
SELECT Id, MIN(Title) AS Title,
 display_term AS Term, MIN(occurrence) AS firstOccurrence
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
GROUP BY Id, display_term
ORDER BY Id, firstOccurrence;
GO



-- Advanced Analysis of Text

-- Term Extraction
-- Getting all terms 
SELECT Id, Title, display_term AS Term, 
 (LEN(docExcerpt) - LEN(REPLACE(docExcerpt, display_term, '')))
 / LEN(display_term) AS tfIndoc
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
ORDER BY Id, tfIndoc DESC;

-- Overall term frequency
WITH termsCTE AS
(
SELECT Id, display_term AS Term, 
 (LEN(docExcerpt) - LEN(REPLACE(docExcerpt, display_term, ''))) /
  LEN(display_term) AS tfindoc
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
),
tfidfCTE AS
(
SELECT Term, SUM(tfindoc) AS tf,
 COUNT(id) AS df
FROM termsCTE
GROUP BY Term
)
SELECT Term,
 t.tf AS TF,
 t.df AS DF,
 d.nd AS ND,
 1.0 * t.tf * LOG(1.0 * d.nd / t.df) AS TFIDF
FROM tfidfCTE AS t
 CROSS JOIN (SELECT COUNT(DISTINCT id) AS nd 
             FROM dbo.Documents) AS d
ORDER BY TFIDF DESC, TF DESC, Term;
GO


-- Words Associations
-- Terms that appear together
WITH termsCTE AS
(
SELECT Id, display_term AS Term, MIN(occurrence) AS firstOccurrence
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 2
GROUP BY id, display_term
),
Pairs_CTE AS
(
SELECT t1.Id,
 t1.Term AS Term1, 
 t2.Term2
FROM termsCTE AS t1
 CROSS APPLY 
  (SELECT term AS Term2
   FROM termsCTE
   WHERE id = t1.id
     AND term <> t1.term) AS t2
)
SELECT Term1, Term2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Term1, Term2
ORDER BY Support DESC;
GO

-- Associations rules with confidence 
WITH termsCTE AS
(
SELECT id, display_term AS Term, MIN(occurrence) AS firstOccurrence
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"' + docExcerpt + '"', 1033, 5, 0)
WHERE special_term = N'Exact Match'
  AND LEN(display_term) > 3
GROUP BY Id, display_term
),
Pairs_CTE AS
(
SELECT t1.Id,
 t1.term AS Term1, 
 t2.Term2
FROM termsCTE AS t1
 CROSS APPLY 
  (SELECT term AS Term2
   FROM termsCTE
   WHERE id = t1.Id
     AND term <> t1.term) AS t2
),
rulesCTE AS
(
SELECT Term1 + N' ---> ' + Term2 AS theRule,
 Term1, Term2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Term1, Term2
),
cntTerm1CTE AS
(
SELECT term AS Term1,
 COUNT(DISTINCT id) AS term1Cnt
FROM termsCTE
GROUP BY term
)
SELECT r.theRule,
 r.Term1,
 r.Term2,
 r.Support,
 CAST(100.0 * r.Support / a.numDocs AS NUMERIC(5, 2)) AS SupportPct,
 CAST(100.0 * r.Support / c.term1Cnt AS NUMERIC(5, 2)) AS Confidence
FROM rulesCTE AS r 
 INNER JOIN cntTerm1CTE AS c
  ON r.Term1 = c.Term1
 CROSS JOIN (SELECT COUNT(DISTINCT id) 
             FROM termsCTE) AS a(numDocs)
WHERE r.Support > 1
ORDER BY Support DESC, Confidence DESC, Term1, Term2;
GO

-- Try to parse the document content
SELECT *
FROM dbo.Documents
CROSS APPLY sys.dm_fts_parser('"'  + doccontent + '"', 1033, 5, 0)
GO
-- Error

-- Content of the FTS index
SELECT *
FROM sys.dm_fts_index_keywords(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents'));  

-- Content on a document level
SELECT * 
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents'));
GO

-- Get document and column names
SELECT fts.document_id, d.Title, 
 fts.column_id, c.name, 
 fts.display_term, fts.occurrence_count
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents')) AS fts
 INNER JOIN dbo.Documents AS d
  ON fts.document_id = d.Id
 INNER JOIN sys.columns AS c
  ON c.column_id = fts.column_id AND
     C.object_id = OBJECT_ID('dbo.Documents')
ORDER BY NEWID();  -- shuffle the result
GO

-- Terms with numbers (some also internal representation)
SELECT fts.document_id, d.Title, 
 fts.column_id, c.name, fts.display_term, fts.occurrence_count
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents')) AS fts
 INNER JOIN dbo.Documents AS d
  ON fts.document_id = d.id
 INNER JOIN sys.columns AS c
  ON c.column_id = fts.column_id AND
     c.object_id = OBJECT_ID('dbo.Documents')
WHERE fts.display_term LIKE '%[0-9]%'
ORDER BY fts.display_term;
GO

-- Show just relevant terms in the document content
SELECT fts.document_id, d.Title, 
 fts.column_id, c.name, fts.display_term, fts.occurrence_count
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents')) AS fts
 INNER JOIN dbo.Documents AS d
  ON fts.document_id = d.Id
 INNER JOIN sys.columns AS c
  ON c.column_id = fts.column_id AND
     C.object_id = OBJECT_ID('dbo.Documents')
WHERE fts.display_term <> N'END OF FILE'
  AND LEN(fts.display_term) > 3
  AND fts.column_id = 5
  AND fts.display_term NOT LIKE '%[0-9]%'
ORDER BY fts.document_id, fts.occurrence_count DESC;
GO

-- Associations rules with confidence for the document content
-- Using temp tables

-- #rules
WITH termsCTE AS
(
SELECT document_id AS Id,  display_term AS Term
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents'))
WHERE display_term <> N'END OF FILE'
  AND LEN(display_term) > 3
  AND column_id = 5
  AND display_term NOT LIKE '%[0-9]%'
  AND display_term NOT LIKE '%[.]%'
  AND display_term NOT IN (N'dejan', N'sarka')
),
Pairs_CTE AS
(
SELECT t1.Id,
 t1.term AS Term1, 
 t2.Term2
FROM termsCTE AS t1
 CROSS APPLY 
  (SELECT term AS Term2
   FROM termsCTE
   WHERE id = t1.Id
     AND term <> t1.Term) AS t2
),
rulesCTE AS
(
SELECT Term1 + N' ---> ' + Term2 AS theRule,
 Term1, Term2, COUNT(*) AS Support
FROM Pairs_CTE
GROUP BY Term1, Term2
)
SELECT *
INTO #rules
FROM rulesCTE;

-- #cntTerm1
WITH termsCTE AS
(
SELECT document_id AS Id,  display_term AS Term
FROM sys.dm_fts_index_keywords_by_document(
      DB_ID('FTSSS'), OBJECT_ID('dbo.Documents'))
WHERE display_term <> N'END OF FILE'
  AND LEN(display_term) > 3
  AND column_id = 5
  AND display_term NOT LIKE '%[0-9]%'
  AND display_term NOT LIKE '%[.]%'
  AND display_term NOT IN (N'dejan', N'sarka')
),
cntTerm1CTE AS
(
SELECT term AS term1,
 COUNT(DISTINCT id) AS term1Cnt
FROM termsCTE
GROUP BY term
)
SELECT *
INTO #cntTerm1
FROM cntTerm1CTE;

-- Final query
SELECT r.theRule,
 r.Term1,
 r.Term2,
 r.Support,
 CAST(100.0 * r.Support / a.numDocs AS NUMERIC(5, 2))
  AS SupportPct,
 CAST(100.0 * r.Support / c.term1Cnt AS NUMERIC(5, 2))
  AS Confidence
FROM #rules AS r 
 INNER JOIN #cntTerm1 AS c
  ON r.Term1 = c.Term1
 CROSS JOIN (SELECT COUNT(DISTINCT id) 
             FROM dbo.Documents) AS a(numDocs)
WHERE r.Support > 1
  AND r.Support / c.term1Cnt < 1
ORDER BY Support DESC, Confidence DESC, Term1, Term2;
GO


-- Clean up
DROP TABLE IF EXISTS #cntTerm1;
DROP TABLE IF EXISTS #rules;
GO
USE master;
DROP DATABASE FTSSS;
GO

