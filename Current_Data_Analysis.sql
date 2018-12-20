
--SUCCESSFUL TRANSACTIONS--
	SELECT
		PKT.TransactionID
	INTO #SuccessfulTransactions
	FROM [SERVER].[dw].[AlphaTangoTransactions] ATF
	JOIN Sandbox.dbo.PumaKiloTransactions PKT
		ON CAST(PKT.TransactionID AS VARCHAR) = ATF.TransactionReferenceNumber AND ATF.DealerNumber = '27506'
	WHERE
		ATF.ReversalIndicator = ''
	AND
		ATF.TransactionReferenceNumber != 'NA'

--SUBMISSION BASE--

	SELECT
		*
	INTO #SubmissionBase
	FROM [Sandbox].[dbo].[PumaKiloTransactions] PKT
	WHERE
		TRAMT != '0'
	AND
		(REV = '' AND REVTRCD = '')
	AND
		CAST(APINT AS DECIMAL) + CAST(APCUR AS DECIMAL) != 0
		

--REMOVING DUPLICATE VALUES
		SELECT
			HPSNumber
			,TransactionID
			,[Key] = TRDATE + HPSNumber + TRAMT
		INTO #DupBase
		FROM #SubmissionBase

		SELECT
			[Key]
			,Count = Count(*)
		INTO #Dups
		FROM #DupBase
		GROUP BY [Key]
		HAVING COUNT(*) > 1

		SELECT DB.*
		INTO #CleanSubmissionBase
		FROM #DupBase DB
		LEFT JOIN #Dups D ON D.[Key] = DB.[Key]
		WHERE D.[Key] IS NULL

  SELECT
	PKT.*
	,AR.AccountNumber
  INTO #FinalSubmissionLoad
  FROM [Sandbox].[dbo].[PumaKiloTransactions] PKT
  JOIN [Sandbox].[dbo].[PumaKiloAccountReference] AR ON AR.HPS = PKT.HPSNumber
  WHERE
		TransactionID NOT IN (SELECT TransactionID FROM #SuccessfulTransactions)
	AND
		TransactionID IN (SELECT TransactionID FROM #CleanSubmissionBase)

SELECT
	AccountNumber
	,[TRDATE] = LEFT(TRDATE,4)+'-'+SUBSTRING(TRDATE,5,2)+'-'+RIGHT(TRDATE,2)
	,[IsReversal] = NULL
	,[Amount] = ABS(CAST(APINT AS DECIMAL) + CAST(APCUR AS DECIMAL))
	,[Reference] = TransactionID
	,[Comment] = 'BLANK'
	,[Deposit] = 'BLANK'
	,[PaymentType] = CASE
						WHEN (TRCD = 'ST' OR TRCD = 'RT') AND CAST(TRAMT AS DECIMAL) > 0 THEN 'PRNDRADJ'
						WHEN (TRCD = 'ST' OR TRCD = 'RT') AND CAST(TRAMT AS DECIMAL) < 0 THEN 'PRNCRADJ'
						ELSE 'PAYMENT' END
	,[PayeeInfo] = CASE
						WHEN (TRCD = 'ST' OR TRCD = 'RT') AND CAST(TRAMT AS DECIMAL) > 0 THEN 'PUMA KILO - CPI PRIN DEBIT ADJ'
						WHEN (TRCD = 'ST' OR TRCD = 'RT') AND CAST(TRAMT AS DECIMAL) < 0 THEN 'PUMA KILO - CPI PRIN CREDIT ADJ'
						ELSE 'CITIZENS FINANCE CO' END
	,Batch = NTILE(4) OVER(ORDER BY HPSNumber)
INTO #Batches
FROM #FinalSubmissionLoad

SELECT * FROM #Batches WHERE Batch = 4
