DECLARE @currentWeekEnd VARCHAR(8) SET @currentWeekEnd = Format((getdate() - datepart(weekday, getdate())), 'yyyyMMdd')
DECLARE @currentWeekStart VARCHAR(8) SET @currentWeekStart = Format((getdate() - datepart(weekday, getdate())- 6), 'yyyyMMdd')

SELECT
	dboDispatch.Location
	,dboDispatch.[Delivery Subtotal]
	,dboDispatch.#Trucks
	,PivotedAccessorialData.[Custom Quote]
	,PivotedAccessorialData.[Off Day Loading]
	,PivotedAccessorialData.[Transfer/Dock Delay 1 Hour]
	,PivotedAccessorialData.[Stops Over $3000]
	,PivotedAccessorialData.Guarantees
	--,dboBillingAdj.[Invoice Adjustments]
	--,[Invoice Total] = [Delivery Subtotal] + [Invoice Adjustments]

FROM

	(

		SELECT
			Branches.Location
			,[Delivery Subtotal] = SUM(Dispatch.ClientTotal)
			,[#Trucks] = COUNT(Dispatch.Id)
			

		FROM Dispatch
	
			JOIN DeliveryTrucks on DeliveryTrucks.Name = Dispatch.ServiceUnitName
			JOIN Branches on Branches.Id = DeliveryTrucks.BranchId
		
		WHERE 
			Dispatch.InstanceId = 11 AND
			DateKey BETWEEN @currentWeekStart AND @currentWeekEnd

		GROUP BY
			Branches.Location

	) dboDispatch

LEFT JOIN

	(

		SELECT
			Branches.Location
			,[Invoice Adjustments] = SUM(BillingAdjustments.ClientAmount)

		FROM BillingAdjustments
			JOIN Branches on Branches.Id = BillingAdjustments.BranchId
			JOIN BillingAdjustmentTypes on BillingAdjustmentTypes.Id = BillingAdjustments.TypeId

		WHERE 
			DateKey = @currentWeekEnd AND
			Branches.DivisionId = 5 AND
			IsInvoiced = 1

		GROUP BY
			Branches.Location

	) dboBillingAdj

ON dboDispatch.Location = dboBillingAdj.Location

LEFT JOIN

(

	SELECT *

	FROM

	(

			SELECT
				Branches.Location
				,DispatchLevelChargeTypes.Name
				,[Amount] = SUM(DispatchLevelCharges.ClientRate)

			FROM DispatchLevelCharges
				JOIN DispatchLevelChargeRates on DispatchLevelChargeRates.Id = DispatchLevelCharges.RateId
				JOIN DispatchLevelChargeTypes on DispatchLevelChargeTypes.Id = DispatchLevelChargerates.TypeId
				JOIN Dispatch on Dispatch.Id = DispatchLevelCharges.DispatchId
				JOIN Branches on Branches.Id = DispatchLevelChargeRates.BranchId

			WHERE
				Dispatch.InstanceId = 11 AND
				Dispatch.DateKey BETWEEN @currentWeekStart AND @currentWeekEnd

			GROUP BY
				Branches.Location
				,DispatchLevelChargeTypes.Name

		UNION ALL

			SELECT
				Branches.Location
				,StopLevelChargeTypes.Name
				,[Amount] = SUM(StopLevelCharges.ClientRate)

			FROM StopLevelCharges

				JOIN StopLevelChargeRates on StopLevelChargeRates.Id = StopLevelCharges.RateId
				JOIN StopLevelChargeTypes on StopLevelChargeTypes.Id = StopLevelChargeRates.TypeId
				JOIN DispatchStops on DispatchStops.Id = StopLevelCharges.StopId
				JOIN Dispatch on Dispatch.Id = DispatchStops.DispatchDetails_Id
				JOIN Branches on Branches.Id = StopLevelChargeRates.BranchId
	
			WHERE 
				Branches.DivisionId = 5 AND
				Dispatch.DateKey BETWEEN @currentWeekStart AND @currentWeekEnd AND
				StopLevelChargetypes.Id = 63

			GROUP BY 
				Branches.Location
				,StopLevelChargeTypes.Name

		UNION ALL

			SELECT
				Branches.Location
				,[Name] = 'Guarantees'
				,[Amount] = SUM(Dispatch.ClientGuarantee)
			FROM Dispatch

				JOIN DeliveryTrucks on DeliveryTrucks.Name = Dispatch.ServiceUnitName
				JOIN Branches on Branches.Id = DeliveryTrucks.BranchId

			WHERE 
				DateKey BETWEEN @currentWeekStart AND @currentWeekEnd
				AND Dispatch.InstanceId = 11

			GROUP BY
				Branches.Location
	) AccessorialData

	PIVOT
	(
		SUM(AccessorialData.Amount)

		FOR Name in
		(
			[Custom Quote],
			[Off Day Loading],
			[Transfer/Dock Delay 1 Hour],
			[Stops Over $3000],
			[Guarantees]
		)

	) as DataPivot
) PivotedAccessorialData

ON dboDispatch.Location = PivotedAccessorialData.Location
