-- check out the Zip Codes and their correspondence to Orders
SELECT o.*
   FROM [SQLBook].[dbo].[Orders] o
   LEFT JOIN [SQLBook].[dbo].[ZipCensus] z
   ON z.zcta5 = o.ZipCode
   WHERE z.zcta5 IS NULL
   ORDER BY o.ZipCode;

-- delete the orders with no Zip Code
DELETE FROM o
   FROM [SQLBook].[dbo].[Orders] o
   LEFT JOIN [SQLBook].[dbo].[ZipCensus] z
   ON z.zcta5 = o.ZipCode
   WHERE z.zcta5 IS NULL;

 -- Insert a row for unknown Customer
INSERT INTO Customers
VALUES (0,0,'','UNKNOWN')


-- check out order lines with no correspondece in the Orders table (no OrderId)
SELECT OrderLineId,
	   OrderLines.OrderID AS [OrderId from OrderLines],
	   ProductId,
	   ShipDate,
	   BillDate,
	   UnitPrice,
	   OrderLines.NumUnits,
	   OrderLines.TotalPrice,
	   Orders.OrderId,
	   Orders.CustomerId
FROM OrderLines
LEFT JOIN Orders ON Orders.OrderId = OrderLines.OrderId
WHERE Orders.OrderId IS NULL
ORDER BY Orders.OrderId

-- create a table named WrongOrders that contains the orders from OrderLines with no correspondence in the Orders table
SELECT * 
INTO WrongOrders
FROM
(
	SELECT OrderLineId,
	   OrderLines.OrderID AS [OrderId from OrderLines],
	   ProductId,
	   ShipDate,
	   BillDate,
	   UnitPrice,
	   OrderLines.NumUnits,
	   OrderLines.TotalPrice,
	   Orders.OrderId,
	   Orders.CustomerId
	FROM OrderLines
	LEFT JOIN Orders ON Orders.OrderId = OrderLines.OrderId
	WHERE Orders.OrderId IS NULL

) AS DeletedOrders

SELECT TOP(10) * FROM WrongOrders

SELECT *
FROM ZipCensus
ORDER BY zcta5

SELECT COUNT(*)
FROM OrderLines

SELECT * FROM Orders
WHERE OrderId=1599115


-- delete the records from OrderLines that were already included in the WrongOrders table
DELETE FROM OrderLines
FROM OrderLines
LEFT JOIN Orders ON Orders.OrderId = OrderLines.OrderId
WHERE Orders.OrderId IS NULL

SELECT COUNT(*)
FROM WrongOrders

SELECT o.*
   FROM [SQLBook].[dbo].[ZipCounty] o
   LEFT JOIN [SQLBook].[dbo].[ZipCensus] z
   ON z.zcta5 = o.ZipCode
   WHERE z.zcta5 IS NULL
   ORDER BY o.ZipCode;

-- created a table called InexistentZips for Zip Codes from ZipCounty that don't have a correspondent in ZipCensus
SELECT *
INTO InexistentZips
FROM
(
	SELECT ZipCode,
		ZipCounty.Latitude,
		ZipCounty.Longitude,
		POName,
		ZipClass,
		CountyFIPS,
		ZipCounty.State,
		CountyName,
		CountyPop,
		Countyhu,
		CountyLandAreaMiles,
		CountyWaterAreaMiles
	FROM ZipCounty
	LEFT JOIN ZipCensus ON ZipCounty.ZipCode=ZipCensus.zcta5
	WHERE ZipCensus.zcta5 IS NULL
) AS NoZips

-- deleted the from ZipCounty the zip codes that were added to the InexistentZips table
DELETE FROM ZipCounty
FROM ZipCounty
LEFT JOIN ZipCensus ON ZipCounty.ZipCode=ZipCensus.zcta5
WHERE ZipCensus.zcta5 IS NULL
