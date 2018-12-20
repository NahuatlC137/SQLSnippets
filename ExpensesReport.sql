--sql extraction for quickbooks

DECLARE @TrailingWeekEnd VARCHAR(8) SET @TrailingWeekEnd = 20171104 --Format((getdate() - datepart(weekday, getdate()) - 7), 'yyyyMMdd')
DECLARE @TrailingWEStart VARCHAR(8) SET @TrailingWEStart = 20171029 --Format((getdate() - datepart(weekday, getdate()) - 13), 'yyyyMMdd')
DECLARE @RefNumber VARCHAR(13) SET @RefNumber = CONCAT('WE ', (CONVERT(VARCHAR(10), CAST(@TrailingWeekEnd as DATE), 101)))
DECLARE @TransactionDate VARCHAR(10) SET @TransactionDate = CONVERT(VARCHAR(10), CAST(@TrailingWeekEnd as DATE), 101)
DECLARE @Description VARCHAR(21) = 'Settlements - '

;WITH TPIStatementCharge as (

		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = DriverCompensation.PaybackAmount
			,[DescType] = 'Debt Payback'
			,[Item] = 'Debt Payback'
			,[AR Account] = 'Debt Payback'
			,[Class] = 'Contractor Expense Passthrough'
		FROM DriverCompensation
			JOIN Businesses on Businesses.UId = DriverCompensation.BusinessId
		WHERE
			DriverCompensation.WeekEnd = @TrailingWeekEnd

UNION ALL

		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = DriverCompensation.VehicleDepositAccumulation
			,[DescType] = 'Vehicle Security Deposit'
			,[Item] = 'Vehicle Security Deposit'
			,[AR Account] = 'Vehicle Security Deposit'
			,[Class] = 'Contractor Expense Passthrough'
		FROM DriverCompensation
			JOIN Businesses on Businesses.UId = DriverCompensation.BusinessId
		WHERE
			DriverCompensation.WeekEnd = @TrailingWeekEnd

UNION ALL

		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = DriverCompensation.BondDepositAccumulation
			,[DescType] = 'Contractor Performance Bond'
			,[Item] = 'CMS - IC Exp-CPB'
			,[AR Account] = 'IC Deposits:CPB'
			,[Class] = 'Contractor Expense Passthrough'
		FROM DriverCompensation
			JOIN Businesses on Businesses.UId = DriverCompensation.BusinessId
		WHERE
			DriverCompensation.WeekEnd = @TrailingWeekEnd

UNION ALL

		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = DriverCompensation.AdminFee
			,[DescType] = 'Admin Fee'
			,[Item] = 'Admin Fee'
			,[AR Account] = 'Administration Fee'
			,[Class] = 'Contractor Expense Passthrough'
		FROM DriverCompensation
			JOIN Businesses on Businesses.UId = DriverCompensation.BusinessId
		WHERE
			DriverCompensation.WeekEnd = @TrailingWeekEnd

UNION ALL
		
		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = (COUNT(ROUTES.Id) * 5)
			,[DescType] = 'Tablets'
			,[Item] = 'IC Exp-Tablets'
			,[AR Account] = 'IC Receivables:Tablets'
			,[Class] = 'Corporate Office:Information Technology'
		FROM Routes
			JOIN DeliveryTrucks on CONCAT(DeliveryTrucks.Name, DeliveryTrucks.InstanceId) = CONCAT(Routes.ServiceUnitName, Routes.InstanceId)
			JOIN Branches on Branches.Id = DeliveryTrucks.BranchId
			JOIN Businesses on Businesses.UId = Routes.BusinessId
		WHERE 
			Routes.DateKey BETWEEN @TrailingWEStart AND @TrailingWeekEnd AND
			Routes.InstanceId <> 11

		GROUP BY
			Branches.Location,
			Businesses.BusinessId

UNION ALL

		SELECT 
			[BusinessId] = TruckInsuranceInvoices.BusinessId
			,[Price] = TruckInsuranceInvoices.WeeklyAmount
			,[DescType] = 'Workers Compensation'
			,[Item] = 'CMS - IC Exp-Insurance-WC'
			,[AR Account] = 'IC Receivables:Insurance-WC'
			,[Class] = 'Contractor Expense Passthrough'
		FROM TruckInsuranceInvoices
			JOIN PLWeekEndings on PLWeekEndings.Month = TruckInsuranceInvoices.Month
		WHERE WeekEnding = @TrailingWeekEnd

UNION ALL

		SELECT 
			[BusinessId] = Businesses.BusinessId
			,[Price] = DriverCompensation.TruckAmount
			,[DescType] = 'Vehicle Expense'
			,[Item] = 'Vehicle Expense'
			,[AR Account] = 'Vehicle Expense'
			,[Class] = 'Contractor Expense Passthrough'
		FROM DriverCompensation
			JOIN Businesses on Businesses.UId = DriverCompensation.BusinessId
		WHERE
			DriverCompensation.WeekEnd = @TrailingWeekEnd
)

SELECT
	[RefNumber] = @RefNumber
	,[BusinessId]
	,[Transaction Date] = @TransactionDate
	,[Description] = CONCAT(@Description, [DescType])
	,[Item]
	,[Price]
	,[AR Account]
	,[Class]

FROM TPIStatementCharge
