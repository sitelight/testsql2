WITH CustomerDetails AS (
    SELECT
CASE 
    WHEN customer_details.[Customer ID] LIKE 'URI_%' THEN '1' + SUBSTRING(customer_details.[Customer ID], 5, LEN(customer_details.[Customer ID])-4)
    WHEN customer_details.[Customer ID] LIKE 'UFA_%' THEN '2' + SUBSTRING(customer_details.[Customer ID], 5, LEN(customer_details.[Customer ID])-4)
    ELSE customer_details.[Customer ID]
END 
AS ID, *
FROM [ubdata].[dbo].[Customer Details] AS customer_details
) 
,
LoanDetails AS (
SELECT *
FROM [ubdata].[dbo].[Loan Details] AS loan_details
) 
,
LitigationDetails AS (
SELECT 
  CaseID,
  MIN(CASE WHEN StatusSecondaryTypeID IN (42, 49, 71, 21, 50, 51, 44, 45, 46, 47, 43, 25, 23, 29, 27, 28, 29, 48, 19, 22, 20, 17, 18)
           THEN EffectiveDate END) AS LTGTN_START_DTE,
  MAX(CASE WHEN StatusSecondaryTypeID IN (31, 32, 33, 34, 35, 36, 37, 38)
           THEN EffectiveDate END) AS LTGTN_END_DTE,
  MIN(CASE WHEN StatusSecondaryTypeID IN (9, 10, 11, 12, 13)
           THEN EffectiveDate END) AS PRE_LTGTN_START_DTE,
  MAX(CASE WHEN StatusSecondaryTypeID IN (42, 49)
           THEN EffectiveDate END) AS PRE_LTGTN_END_DTE,
  STRING_AGG(CAST(StatusSecondaryTypeID AS VARCHAR), ',') AS [StatusSecondaryTypeIDs present in the record]
FROM StatusSecondary
GROUP BY CaseID
)
SELECT 
(SELECT STRING_AGG(a.[First name] + ' ' + a.Surname, ', ') FROM Applicant_TBL a WHERE a.CaseID = Case_TBL.CaseID GROUP BY a.CaseID) AS ACC_NAME,
Case_TBL.AccountNumber AS MORTGAGE_ID,
CONCAT('000000', Case_TBL.AccountNumber, RIGHT('00' + SUBSTRING(Case_TBL.CaseReference, CHARINDEX('-', Case_TBL.CaseReference) + 1, 2), 2)) AS ACC_NO,
RIGHT(Case_TBL.[Original Reference], CHARINDEX('-', REVERSE(Case_TBL.[Original Reference])) - 1) AS UB_SUB_LOAN_ID,
FORMAT(CONVERT(DATE, Loan_TBL.[AIBCompletionDate]),'yyyy-MM-dd') AS ACC_SETUP_DTE,
CaseInformation.CurBal AS BAL_FOR_INT,
CASE WHEN CaseInformation.OutstandingArrears > 0 THEN 'Y' ELSE 'N' END AS ARREARS_IND,
'IE' AS CNTRY_OF_RISK,
CaseInformation.CurBal AS BAL_AMT,
CustomerDetails.[Borrower Residency] AS CNTRY_OF_ULTIMATE_RISK_CDE,
CustomerDetails.[Borrower Residency] AS ISO_CNTRY_CDE,
FORMAT(Index_TBL.[Index rate] * 100, 'N2') AS BASE_RTE,

ddi.BIC AS BIC,
ddi.SortCode AS BR_CDE_FK,
CASE 
	LOWER(Status_TBL.Status)
	WHEN 'redeemed' THEN FORMAT(StatusHistory_TBL.[Effective date], 'yyyy-MM-dd')
    ELSE NULL
END AS CLOSE_DTE,
CASE 
    WHEN 
		(SELECT COUNT(1) FROM Facilitator WHERE Facilitator.CaseID = Case_TBL.CaseID AND Facilitator.FacilitatorTypeID = 3) > 0
    THEN 
        'Y'
    ELSE 
        'N' 
END AS GUARANTOR_IND,
FORMAT(CONVERT(DATE, CaseInformation.MaturityDate),'yyyy-MM-dd') AS CNTRACT_MATURITY_DTE,
CASE
    WHEN CaseInformation.DateFirstInArrears IS NULL THEN 0
    ELSE DATEDIFF(DAY, CaseInformation.DateFirstInArrears, GETDATE())
END AS DAYS_IN_ARREARS,
cms.CMS AS CURR_TOT_INSTALMT_AMT,
365 AS DAY_CNT_CONVENTION_CDE,
FORMAT(CaseInformation.DateFirstInArrears, 'yyyy-MM-dd') AS ARREARS_DTE,
FORMAT(CaseInformation.CurrentRateEffectiveDate,'yyyy-MM-dd') AS CURR_RT_EFF_DT,
FORMAT(CaseInformation.PayRateNow * 100, 'N2') AS DR_INT_RTE,
Loan_TBL.[Original loan amount] AS DRAWN_BAL_AT_ORIGINATION_AMT,
FORMAT(CONVERT(DATE, [LoanDetails].[Origination Date]),'yyyy-MM-dd') AS FIRST_TRANS_DTE,
CASE 
    WHEN Loan_TBL.FirstTimeBuyer = 1 
    THEN 'Y'
    ELSE 'N' 
END AS FIRST_TIME_BUYER_IND,
(SELECT Name FROM PaymentFrequency WHERE Id = Loan_TBL.PaymentFrequencyID) AS INT_PMT_FREQ_CDE,
CASE
	WHEN LOWER(Index_TBL.[ProductType]) IN ('fixed', 'fixed (mars)', 'fixed (sco22)', 'staff') THEN 'F'
    ELSE 'V'
END
AS FIX_FLOATING_IND,
FORMAT(CaseInformation.CurrentRateEffectiveDate,'yyyy-MM-dd') AS PRICING_DTE,
Index_TBL.[Index name] AS FUNDING_CATEGORY,
FORMAT(CONVERT(DATE, Rate_TBL.[Period 1 end]),'yyyy-MM-dd') AS FXD_INT_END_DTE,
ddi.IBAN AS IBAN,
CaseInformation.AibProductCode AS SRCE_PROD_CDE_FK,
CASE 
WHEN AraHistory.DSTResolutionOptionID = 4
	THEN FORMAT(CONVERT(DATE, AraHistory.ProjectedEndDate),'yyyy-MM-dd')
WHEN LOWER(Index_TBL.[ProductType]) IN ('fixed', 'fixed (mars)', 'fixed (sco22)', 'staff') AND LOWER(Loan_TBL.[Repayment method]) = 'interest only'
    THEN FORMAT(CONVERT(DATE, Rate_TBL.[Period 1 end]),'yyyy-MM-dd')
WHEN LOWER(Loan_TBL.[Repayment method]) = 'interest only'
	THEN FORMAT(CONVERT(DATE, CaseInformation.MaturityDate), 'yyyy-MM-dd')
ELSE NULL
END AS INT_ONLY_END_DTE,
CASE WHEN LOWER(Loan_TBL.[Repayment method]) = 'interest only' THEN 'Y' ELSE 'N' END AS INT_ONLY_IND,
NULL AS CURR_PRNCPL_INSTALMT_AMT,
--NULL AS INTERNAL_WRITE_DOWN_PROV_AMT_E,
--NULL AS INTERNAL_WRITE_DOWN_PROV_AMT_L,
--NULL AS INTERNAL_WRITE_DWN_ASSET_AMT_E,
--NULL AS INTERNAL_WRITE_DWN_ASSET_AMT_L,
--NULL AS INTERNAL_WRITE_DWN_ASSET_AMT_T,
Loan_TBL.CreditGradeOverride AS OVERRIDE_GRD,
Status_TBL.Status AS ACC_STA_CDE,
Loan_TBL.Currency AS ISO_CRNCY_CDE,
FORMAT((SELECT TOP 1 tx.[Transaction date] 
FROM Transaction_TBL tx, TransactionType_TBL tty 
WHERE tx.TransactionTypeId = tty.TransactionTypeID 
AND LOWER(tty.[Transaction category]) = 'pmt' 
AND tx.CaseID = Case_TBL.CaseID 
AND tx.[Transaction amount] < 0
ORDER BY tx.[Transaction date] DESC), 'yyyy-MM-dd') AS LAST_DR_DTE,
FORMAT(DATEADD(month, DATEDIFF(month, 0, GETDATE())+1, 0), 'yyyy-MM-dd') AS NEXT_INT_CHARGE,
CASE
    WHEN MarpTypeHistory.MarpTypeID = 1 THEN
        (SELECT TOP 1 FORMAT(ChangedOnDate, 'yyyy-MM-dd')
         FROM MarpTypeHistory 
         WHERE MarpTypeID = 1
		 AND CaseID = Case_TBL.CaseID
         ORDER BY ChangedOnDate DESC)
    WHEN MarpTypeHistory.MarpTypeID IN (3, 4) THEN
        (SELECT TOP 1 FORMAT(ChangedOnDate, 'yyyy-MM-dd') 
         FROM MarpTypeHistory 
         WHERE MarpTypeID IN (3, 4)
         AND CaseID = Case_TBL.CaseID
         ORDER BY ChangedOnDate DESC)
    ELSE NULL
END AS MARP_DTE,
CASE
    WHEN MarpTypeHistory.MarpTypeID IN (3, 4) THEN 'M'
    WHEN MarpTypeHistory.MarpTypeID = 1 THEN 'O'
    WHEN Case_TBL.RegulatoryBodyId = 2 AND
         LOWER(Loan_TBL.Purpose) = 'btl' AND
         MonthlyBalances_TBL.Arrears > 0 THEN 'N'
    WHEN Case_TBL.RegulatoryBodyId = 1 AND
         LOWER(Loan_TBL.Purpose) = 'pdh' AND
         MonthlyBalances_TBL.Arrears < 0 THEN NULL
    ELSE NULL
END AS MARP_FLAG,
CASE 
    WHEN MarpTypeHistory.MarpTypeID IN (3, 4) THEN 'Y'
    ELSE 'N'
END AS MARP_IND,
CASE 
        WHEN DAY(GETDATE()) > Case_TBL.PaymentDay 
        THEN CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
        ELSE CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
END AS NEXT_PRINCP_CHARGE,
(CaseInformation.CurBal - CaseInformation.ArrearsLME) AS NET_LIMIT_FOR_PRNCPL,
FORMAT(CONVERT(DATE, Loan_TBL.[AIBCompletionDate]), 'yyyy-MM-dd') AS DRAWN_BAL_ORIGINATION_DTE,
CASE 
        WHEN DAY(GETDATE()) > Case_TBL.PaymentDay 
        THEN CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
        ELSE CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
END AS NEXT_RPMT_DTE,
CASE 
        WHEN DAY(GETDATE()) > Case_TBL.PaymentDay 
        THEN CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
        ELSE CASE
            WHEN Case_TBL.PaymentDay > DAY(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)))
            THEN FORMAT(EOMONTH(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)), 'yyyy-MM-dd')
            ELSE FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) + Case_TBL.PaymentDay - 1, 'yyyy-MM-dd')
            END
END AS NXT_INT_PMT_DTE,

FORMAT(CONVERT(DATE, Rate_TBL.[Period 1 end]), 'yyyy-MM-dd') AS NXT_REPRICING_DTE,
FORMAT(CONVERT(DATE, ISNULL(Rate_TBL.[Period 1 end], CaseInformation.MaturityDate)), 'yyyy-MM-dd') AS NXT_RESET_DTE,
ISNULL(Loan_TBL.Originator, 'ULSTER BANK') AS ORIGINATION_ENTITY,
cms.CMS AS PAYMENT_AMOUNT,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -10, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_10,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -11, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_11,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -12, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_12,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -3, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_3,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -4, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_4,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -5, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_5,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -6, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_6,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -7, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_7,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -8, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_8,
(
	SELECT rd.[Payments received] FROM ReceivedDue_TBL rd
	WHERE FORMAT(rd.[Month end], 'yyyy-M') = FORMAT(DATEADD(month, -9, GETDATE()), 'yyyy-M')
	AND rd.CaseID = Case_TBL.CaseID
) AS PMT_HIS_9,
CASE 
    WHEN MarpTypeHistory.MarpTypeID = '4' THEN 'Y' 
    ELSE NULL 
END AS PRE_ARREARS,
--MonthlyBalances_TBL.PriArrears AS PRNCPL_ARREARS_AMT,
CaseInformation.OutstandingArrears AS ARREARS_AMT,
--ArrearsStaging.ArrearsAmount AS ARREARS_AMT,
--CONVERT(varchar, Rate_TBL.[Period 1 end], 23) AS LOAN_REVIEW_DATE,
CONVERT(varchar,Case_TBL.PaymentDay, 23) AS REG_RPMT_DAY,
CASE 
    WHEN DV_LoanTermRemaining.[Remaining term] < 0
    THEN 0
    ELSE DV_LoanTermRemaining.[Remaining term]
END AS REMAINING_TERM,
CASE
	(SELECT Name FROM PaymentFrequency WHERE Id = Loan_TBL.PaymentFrequencyID)
	WHEN 'Annually' THEN 'Y' ELSE 'M'
END AS TERM_UNIT,
CASE 
    WHEN (
        SELECT COUNT(1) FROM CaseSecurity cs
        LEFT JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY SecurityID ORDER BY EffectiveDate DESC) as rn
	    FROM SecurityStatusHistory) sh ON sh.SecurityID = cs.SecurityID AND sh.rn = 1
        WHERE sh.StatusID <> 6 AND cs.CaseID = Case_TBL.CaseID
        ) = 0 
	THEN 'N'
    ELSE 'Y'
END AS SECURED_IND,
cms.CMS AS RPMT_DUE_AMT,
Case_TBL.PurposeCode AS PURPOSE_CDE,
CONVERT(varchar, ROUND(Case_TBL.SectorCode, 0)) AS SECTOR_CDE_FK,
CASE WHEN (SELECT COUNT(1) FROM Applicant_TBL WHERE Applicant_TBL.WithholdCommunication = 1 AND CaseID = Case_TBL.CaseID) > 0 
	 THEN 'Y' 
	 ELSE 'N' 
END AS STOP_NOTICES,
DATEDIFF(month, Loan_TBL.[Completion Date], CaseInformation.[MaturityDate]) AS TERM_NO_UNITS,
CaseInformation.OutstandingArrears AS TOT_ARREARS_EXCL_TRS_AMT, -- Tax Relief at Source no longer applicable
(SELECT Name FROM PaymentFrequency WHERE Id = Loan_TBL.PaymentFrequencyID) AS TOT_INSTALMT_PMT_FREQ_CDE, 
NULL AS CANCELLED_EXPIRED,
--CASE WHEN (DirectDebitInstructions.DDStatusID = '2') THEN 'Direct Debit' ELSE
--(SELECT TOP 1 tty.[Transaction description] 
--FROM Transaction_TBL tx, TransactionType_TBL tty 
--WHERE tx.TransactionTypeId = tty.TransactionTypeID 
--AND LOWER(tty.[Transaction category]) = 'pmt' 
--AND tx.CaseID = Case_TBL.CaseID 
--AND tx.[Transaction amount] < 0
--ORDER BY tx.[Transaction date] DESC) END AS PAYMENT_METHOD,
CASE 
    WHEN DirectDebitInstructions.DDStatusID = '2' THEN 'Direct Debit'
    WHEN (
        SELECT TOP 1 tty.[Transaction description] 
        FROM Transaction_TBL tx
        INNER JOIN TransactionType_TBL tty ON tx.TransactionTypeId = tty.TransactionTypeID 
        WHERE LOWER(tty.[Transaction category]) = 'pmt' 
        AND tx.CaseID = Case_TBL.CaseID 
        AND tx.[Transaction amount] < 0
        ORDER BY tx.[Transaction date] DESC
    ) = 'Direct Debit Payment' THEN 'Direct Debit'
    ELSE (
        SELECT TOP 1 tty.[Transaction description] 
        FROM Transaction_TBL tx
        INNER JOIN TransactionType_TBL tty ON tx.TransactionTypeId = tty.TransactionTypeID 
        WHERE LOWER(tty.[Transaction category]) = 'pmt' 
        AND tx.CaseID = Case_TBL.CaseID 
        AND tx.[Transaction amount] < 0
        ORDER BY tx.[Transaction date] DESC
    )
END AS PAYMENT_METHOD,
NULL AS DOWNGRADE_INDICATOR,
(SELECT TOP 1 Grade FROM CreditGrade WHERE CaseID = Case_TBL.CaseID ORDER BY DateOfChange DESC) AS ACCOUNT_GRADE,
(CASE 
WHEN StatusSecondaryType.StatusSecondaryTypeID IN (42,49,71,21,50,51,44,45,46,47,43,25,23,29,27,28,29,48,19,22,20,17,18,31,32,33,34,35,36,37,38,9,10,11,12,13,42,49)
THEN StatusSecondaryType.StatusDescription 
ELSE NULL
END) AS LEGAL_STA_DESCR,
FORMAT(LitigationDetails.LTGTN_END_DTE, 'yyyy-MM-dd') AS LTGTN_END_DTE,
FORMAT(LitigationDetails.LTGTN_START_DTE, 'yyyy-MM-dd') AS LTGTN_START_DTE,
FORMAT(LitigationDetails.PRE_LTGTN_END_DTE, 'yyyy-MM-dd') AS PRE_LTGTN_END_DTE,
FORMAT(LitigationDetails.PRE_LTGTN_START_DTE, 'yyyy-MM-dd') AS PRE_LTGTN_START_DTE
FROM Case_TBL
INNER JOIN Loan_TBL ON Loan_TBL.CaseID = Case_TBL.CaseID
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY CaseID DESC) AS rn
	FROM Applicant_TBL
) Applicant_TBL ON Applicant_TBL.CaseID = Case_TBL.CaseID and Applicant_TBL.rn = 1
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY ID ORDER BY ID DESC) AS rn
	FROM CustomerDetails
) CustomerDetails ON CustomerDetails.ID = Applicant_TBL.BorrowerID and CustomerDetails.rn = 1
LEFT JOIN LoanDetails ON LoanDetails.[Loan ID] = LEFT(Case_TBL.[Original Reference], CHARINDEX('-', Case_TBL.[Original Reference]) - 1)
    AND LoanDetails.[Sub Loan ID] = RIGHT(Case_TBL.[Original Reference], CHARINDEX('-', REVERSE(Case_TBL.[Original Reference])) - 1) 
LEFT JOIN CaseInformation ON CaseInformation.CaseID = Case_TBL.CaseID
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY Date DESC) AS rn
	FROM MonthlyBalances_TBL
) MonthlyBalances_TBL ON MonthlyBalances_TBL.CaseID = Case_TBL.CaseID and MonthlyBalances_TBL.rn = 1
LEFT JOIN Rate_TBL ON Rate_TBL.CaseID = Case_TBL.CaseID
LEFT JOIN Index_TBL ON Rate_TBL.IndexID = Index_TBL.IndexID
LEFT JOIN (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY [CMS Month] DESC) AS rn
	FROM CMSHistory_TBL
) cms ON cms.CaseID = Case_TBL.CaseID AND cms.rn = 1
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY EffectiveDate DESC) AS rn
	FROM AraHistory
) AraHistory ON AraHistory.CaseID = Case_TBL.CaseID and AraHistory.rn = 1

LEFT JOIN (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY ChangedOnDate DESC) as RN 
	FROM MarpTypeHistory
) MarpTypeHistory ON MarpTypeHistory.CaseID = Case_TBL.CaseID AND MarpTypeHistory.rn = 1
LEFT JOIN (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY NextCollection DESC) as rn
	FROM DirectDebitInstructions
	WHERE DDStatusID = 2
) ddi ON ddi.CaseID = Case_TBL.CaseID and ddi.rn = 1
LEFT JOIN DV_LoanTermRemaining ON Case_TBL.CaseID = DV_LoanTermRemaining.CaseID
LEFT JOIN (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY Datechanged DESC) as rn
	FROM StatusHistory_TBL
) StatusHistory_TBL ON StatusHistory_TBL.CaseID = Case_TBL.CaseID AND StatusHistory_TBL.rn = 1
LEFT JOIN (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY ChangedOnDate DESC) as rn
	FROM StatusSecondary
) StatusSecondary ON StatusSecondary.CaseID = Case_TBL.CaseID AND StatusSecondary.rn = 1
LEFT JOIN StatusSecondaryType ON StatusSecondaryType.StatusSecondaryTypeID = StatusSecondary.StatusSecondaryTypeID
LEFT JOIN LitigationDetails ON LitigationDetails.CaseID = Case_TBL.CaseID
LEFT JOIN Status_TBL ON Status_TBL.StatusID = StatusHistory_TBL.StatusID
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY CaseId ORDER BY CaseId DESC) AS rn
	FROM MissedOrLatePayments
) MissedOrLatePayments ON MissedOrLatePayments.CaseId = Case_TBL.CaseID and MissedOrLatePayments.rn = 1
LEFT JOIN (
	SELECT *, 
	ROW_NUMBER() OVER (PARTITION BY CaseID ORDER BY CaseID DESC) AS rn
	FROM DirectDebitInstructions
) DirectDebitInstructions ON DirectDebitInstructions.CaseID = Case_TBL.CaseID and DirectDebitInstructions.rn = 1
ORDER BY ACC_NO