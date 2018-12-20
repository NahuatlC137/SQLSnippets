-- When restructuring/new locations, used for billing client.

DECLARE @weekendDate VARCHAR(8)
	SELECT @weekendDate = Format((getdate() - datepart(weekday, getdate())), 'yyyyMMdd')

DECLARE @startWeekDate VARCHAR(8)
	SELECT @startWeekDate = Format((getdate() - datepart(weekday, getdate())-6), 'yyyyMMdd')


DECLARE @newRateLocations TABLE (LocationIds INT)
	INSERT @newRateLocations(LocationIds) VALUES
	--Keep Sites
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999),	--SITE
	(999)	--SITE

SELECT
	@weekendDate as WeekendDate,
	dboDispatch.Name, 
	dboDispatch.Location,
	dboDispatch.Id,
	dboDispatch.BusinessId,
	dboDispatch.Miles,
	dboDispatch.[0 to <201],
	dboDispatch.[201 to <251],
	dboDispatch.[251 to <301],
	dboDispatch.Quote,
	dboDispatchStopsNDR.NotDeliveryReason,
	dboDispatchCharges.[Delayed (+30)],
	dboDispatchCharges.[Delayed (+60)]

FROM

(
	
-- dboDispatch Query

	SELECT
		Dispatch.DateKey,
		Divisions.Name, 
		Branches.Location,
		Dispatch.Id,
		Businesses.BusinessId,
		Dispatch.Miles,
		SUM(CASE WHEN Miles >= 0 AND Miles < 201 THEN 1 END) AS '0 to <201',
		SUM(CASE WHEN Miles >= 201 AND Miles < 251 THEN 1 END) AS '201 to <251',
		SUM(CASE WHEN Miles >= 251 AND Miles < 301 THEN 1 END) AS '251 to <301',
		SUM(CASE WHEN Miles >=301 THEN 1 END) AS 'Quote'
		
	FROM Dispatch
		JOIN DeliveryTrucks on DeliveryTrucks.Name = Dispatch.ServiceUnitName
		JOIN Branches on Branches.id = DeliveryTrucks.BranchId
		JOIN Divisions on Divisions.Id = Branches.DivisionId
		JOIN Businesses on Businesses.UId = Dispatch.BusinessId

	WHERE 
		Dispatch.DateKey BETWEEN @startWeekDate AND @weekendDate AND
		
		Branches.Id IN (SELECT * FROM @newRateLocations)

	GROUP BY 
		Dispatch.DateKey,
		Divisions.Name, 
		Branches.Location,
		Dispatch.Id,
		Businesses.BusinessId,
		Dispatch.Miles
) dboDispatch
-- End dboDispatch

LEFT JOIN

(

-- dboDispatchStopsNDR Query

	SELECT
		Dispatch.Id,
		 
		SUM(CASE WHEN DispatchStops.NotDeliveryReason = 3 OR DispatchStops.NotDeliveryReason = 7 THEN 1 END) AS NotDeliveryReason

	FROM DispatchStops
		JOIN Dispatch ON Dispatch.Id = DispatchStops.DispatchDetails_Id
		JOIN DeliveryTrucks ON DeliveryTrucks.Name = Dispatch.ServiceUnitName
		JOIN Branches ON Branches.Id = DeliveryTrucks.BranchId

	WHERE
		NotDeliveryReason IN (
			3,		-- Refused AF
			7		-- Not At Home AF
			) AND

		DateKey BETWEEN @startWeekDate AND @weekendDate AND

		Branches.Id IN (SELECT * FROM @newRateLocations)

	GROUP BY Dispatch.Id
) dboDispatchStopsNDR

-- END OF dboDispatchStopsNDR

on dboDispatch.Id = dboDispatchStopsNDR.Id

LEFT JOIN
(

--DispatchCharges Query

SELECT 
		Dispatch.Id,
		SUM(CASE WHEN DispatchLevelChargeTypes.Id = 53 THEN 1 ELSE NULL END) AS 'Delayed (+30)',
		SUM(CASE WHEN DispatchLevelChargeTypes.id = 54 THEN 1 ELSE NULL END) AS 'Delayed (+60)'

	FROM DispatchLevelCharges

		JOIN DispatchLevelChargeRates ON DispatchLevelChargeRates.Id = DispatchLevelCharges.RateId
		JOIN DispatchLevelChargeTypes ON DispatchLevelChargeTypes.Id = Dispatchlevelchargerates.TypeId

		JOIN Dispatch ON Dispatch.Id = DispatchLevelCharges.DispatchId
		JOIN DeliveryTrucks ON DeliveryTrucks.Name = Dispatch.ServiceUnitName
		JOIN Branches ON Branches.Id = DeliveryTrucks.BranchId

	WHERE

		Branches.Id IN (SELECT * FROM @newRateLocations) AND

		Dispatch.DateKey BETWEEN @startWeekDate AND @weekendDate AND

		-- Dock Delays
		DispatchLevelChargeTypes.Id in (53,54)

	GROUP BY Dispatch.Id
) dboDispatchCharges

--END OF DispatchCharges

ON dboDispatch.Id = dboDispatchCharges.Id
