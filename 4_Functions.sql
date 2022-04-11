USE SQLBook
GO

/* 1. Create a function that shows the total number of orders by year per ZipCode 
(the ZipCode will be provided by the user) */

-- first check if there is an already existing function with the same name and if yes delete it 

IF object_id(N'OrdersPerZip', N'IF') IS NOT NULL
    DROP FUNCTION OrdersPerZip
GO

CREATE FUNCTION OrdersPerZip
(
	@zip varchar(255) -- the @zip variable will take the zip code provided by the user
)
RETURNS TABLE 
AS
RETURN 
(
SELECT ZipCode,
	   YEAR(OrderDate) AS Order_Year,
	   COUNT(OrderId) AS [Number of Orders]
FROM Orders
WHERE ZipCode=@zip
GROUP BY YEAR(OrderDate),ZipCode 
);

GO

-- execute the function
SELECT * FROM OrdersPerZip('19081')
ORDER BY Order_Year
GO

/* 2. Create a function that shows the top 10 customers (by total orders value),
by Zip Code (the zip code will be provided by the user)*/

-- delete function if it already exists
IF object_id(N'Top10CustomersPerZip', N'IF') IS NOT NULL
    DROP FUNCTION Top10CustomersPerZip
GO

CREATE FUNCTION Top10CustomersPerZip
(
	@zip varchar(50)
)
RETURNS TABLE
AS
RETURN
(
SELECT 
	 [Customer ID],
	 [Total Amount Spent]	
-- used a derived table (subquery) to get an ordered table of all the customers and their total amount spent (descending), filtered by zipcode.
FROM (
	SELECT C.CustomerId AS [Customer ID],
		O.ZipCode AS [Zip Code],
        SUM(O.TotalPrice) AS [Total Amount Spent],
		-- used a window function to create a Row_number column that assigns an ordering value based on the total amount spent (descending)
		ROW_NUMBER() OVER (PARTITION BY O.ZipCode ORDER BY SUM(O.TotalPrice) DESC) AS [Row_number]
	FROM Orders AS O
	JOIN Customers AS C ON O.CustomerId=C.CustomerId
	WHERE O.ZipCode=@zip
	GROUP by C.CustomerID,O.ZipCode
	)z
-- filtered the top 10 customers (by total order value), using the Row_number column
WHERE [Row_number] BETWEEN 1 AND 10
);
GO

-- executed the function
SELECT * FROM Top10CustomersPerZip('19081');
GO

/* 3. Create a function that shows the top 10 counties in terms of number of orders, 
between 2 dates provided by the user*/

IF object_id(N'Top10CountiesByDate', N'IF') IS NOT NULL
    DROP FUNCTION Top10CountiesByDate
GO

CREATE FUNCTION Top10CountiesByDate
(
	@start_date DateTime,
	@end_date DateTime
)
RETURNS TABLE
AS
RETURN
(
SELECT TOP (10)
	ZC.CountyName AS County,
  	COUNT(O.OrderId) AS [Number of Orders]
FROM ZipCounty AS ZC
JOIN Orders AS O ON ZC.ZipCode=O.ZipCode
WHERE O.OrderDate BETWEEN @start_date AND @end_date
GROUP BY ZC.CountyName
ORDER BY [Number of Orders] DESC
);
GO

-- execute the function
SELECT * FROM Top10CountiesByDate('2015-09-01','2015-12-01');
GO
SELECT * FROM Top10CountiesByDate('2015-01-01','2016-01-01');
GO

/* 4. Find the top selling product categories (in terms of number of units sold),
during a period defined by the user*/

IF object_id(N'TopProductsByDate', N'IF') IS NOT NULL
    DROP FUNCTION TopProductsByDate
GO

CREATE FUNCTION TopProductsByDate
(
	@start_date DateTime,
	@end_date DateTime
)
RETURNS TABLE
AS
RETURN
(
SELECT TOP(10)
		P.GroupName AS [Product Category],
		SUM(OL.NumUnits) AS [Number of Units Sold],
		FORMAT(SUM(OL.TotalPrice),'N0') AS [Total revenue generated]
FROM Products as P
JOIN OrderLines AS OL ON P.ProductId=OL.ProductId
WHERE OL.BillDate BETWEEN @start_date AND @end_date
GROUP BY P.GroupName	
ORDER BY [Number of Units Sold] DESC
);
GO

SELECT * FROM TopProductsByDate('2015-01-01','2016-01-01');
GO
SELECT * FROM TopProductsByDate('2016-01-01','2016-02-01');
GO

/* 5. Show a history of the last 50 orders for a product ID selected by the user */

IF object_id(N'ProductOrderHistory', N'IF') IS NOT NULL
    DROP FUNCTION ProductOrderHistory
GO

CREATE FUNCTION ProductOrderHistory
(
	@product AS int
)
RETURNS TABLE
AS
RETURN
(
SELECT TOP(50)
	   OL.ProductId,
	   OL.OrderId,
	   Customers.CustomerId,
	   O.OrderDate,
	   OL.ShipDate,
	   OL.BillDate,
	   OL.NumUnits,	   
	   OL.TotalPrice,
	   --Campaigns.CampaignName,
	   O.CampaignId
FROM OrderLines AS OL
JOIN Orders AS O ON O.OrderId=OL.OrderId
JOIN Customers ON Customers.CustomerId = O.CustomerId
JOIN Campaigns ON Campaigns.CampaignId=O.CampaignId
WHERE ProductID=@product
ORDER BY O.OrderDate DESC
);
GO

SELECT * FROM ProductOrderHistory(10004);
GO
SELECT * FROM ProductOrderHistory(12826);
GO

/* 6. Show top 20 best selling products (based on number of units) 
within a month provided by the user */

IF object_id(N'TopProductsMonth', N'IF') IS NOT NULL
    DROP FUNCTION TopProductsMonth
GO

CREATE FUNCTION TopProductsMonth
(
	@start_date DateTime
)
RETURNS TABLE
AS
RETURN
(
SELECT TOP(20)
	OrderLines.ProductId,
	SUM(OrderLines.NumUnits) AS [Number of units sold]
FROM OrderLines
JOIN Orders ON OrderLines.OrderId=Orders.OrderId
WHERE OrderDate BETWEEN @start_date AND DATEADD(month, 1, @start_date)
GROUP BY OrderLines.ProductId
ORDER BY SUM(OrderLines.NumUnits) DESC
);
GO

SELECT * FROM TopProductsMonth('2015-11-01');
GO
SELECT * FROM TopProductsMonth('2016-01-01');
GO

/* 7. Show the best selling product from each product category, 
within a timeframe provided by the user*/

IF object_id(N'TopProductCategoryDate', N'IF') IS NOT NULL
    DROP FUNCTION TopProductCategoryDate
GO

CREATE FUNCTION TopProductCategoryDate
(
	@start_date DateTime,
	@end_date DateTime
)
RETURNS TABLE
AS
RETURN
(
SELECT
	[Product Category],
	[Product ID],
	[Total Units Sold]
FROM
	(
	SELECT Products.GroupName AS [Product Category],
		Products.ProductId AS [Product ID],
		SUM(OrderLines.NumUnits) AS [Total Units Sold],
		ROW_NUMBER() OVER(PARTITION BY Products.GroupName ORDER BY SUM(OrderLines.NumUnits) DESC) AS [Row_number]
	FROM Products
	JOIN OrderLines ON OrderLines.ProductID=Products.ProductID
	JOIN Orders ON OrderLines.OrderId=Orders.OrderId
	WHERE Orders.OrderDate BETWEEN @start_date AND @end_date
	GROUP BY Products.ProductId,Products.GroupName
	)p
WHERE [Row_number]=1
)
;
GO

SELECT * FROM TopProductCategoryDate('2015-01-01','2016-01-01');
GO
SELECT * FROM TopProductCategoryDate('2015-12-01','2016-01-01');


/* 8. Show the best Campaign IDs (in terms of number of products sold), 
by year, for a product ID selected by the user */

IF object_id(N'BestCampaignForProductYearly', N'IF') IS NOT NULL
    DROP FUNCTION BestCampaignForProductYearly
GO

CREATE FUNCTION BestCampaignForProductYearly
(
	@product int
)
RETURNS TABLE
AS
RETURN
(
SELECT [Year], 
	[Campaign],
	[Number of units sold]
FROM (
	SELECT 
		YEAR(Orders.OrderDate) AS Year,
		Orders.CampaignId as Campaign,
		SUM(OrderLines.NumUnits) AS [Number of units sold],
		ROW_NUMBER() OVER (PARTITION BY YEAR(Orders.OrderDate) ORDER BY SUM(OrderLines.NumUnits) DESC) AS [Row Number]
	FROM Campaigns
	JOIN Orders ON Orders.CampaignId=Campaigns.CampaignId
	JOIN OrderLines ON OrderLines.OrderId=Orders.OrderId
	WHERE OrderLines.ProductId=@product AND YEAR(Orders.OrderDate) IS NOT NULL
	GROUP BY Orders.CampaignId,YEAR(Orders.OrderDate)
	) c
WHERE [Row Number] IN (1,2,3)
);
GO

SELECT * FROM BestCampaignForProductYearly(10004);
GO
SELECT * FROM BestCampaignForProductYearly(13298);
GO


/* 9. Find the difference between the amount spent per year/household 
over subsequent years for a Household Id provided by the user */

IF object_id(N'YearlyAmountSpentPerHousehold', N'IF') IS NOT NULL
	DROP FUNCTION YearlyAmountSpentPerHousehold
GO

CREATE FUNCTION YearlyAmountSpentPerHousehold
(
 @household int
)
RETURNS TABLE
AS
RETURN
(
SELECT Household,
	   [Order Year],
	   [Total Amount Spent Current Year],
	   [Total Amount Spent Previous Year],
	   [Total Units Ordered Current Year],
	   [Amount Difference] = [Total Amount Spent Current Year] - [Total Amount Spent Previous Year],
	   [Amount Difference Type] =
				CASE WHEN [Total Amount Spent Current Year] - [Total Amount Spent Previous Year]<0 THEN 'Decreased' 
					WHEN [Total Amount Spent Current Year] - [Total Amount Spent Previous Year] = 0 THEN 'No difference'
					WHEN [Total Amount Spent Current Year]/IIF([Total Amount Spent Previous Year]=0,1,[Total Amount Spent Previous Year]) > 1 THEN 'Increased by more than 100%'
					WHEN [Total Amount Spent Current Year]/IIF([Total Amount Spent Previous Year]=0,1,[Total Amount Spent Previous Year]) > 0.5 THEN 'Increased by more than 50%'
					WHEN [Total Amount Spent Current Year]/IIF([Total Amount Spent Previous Year]=0,1,[Total Amount Spent Previous Year])> 0.25 THEN 'Increased by more than 25%'
					ELSE 'Increased by less than 25%'
				END
	   
FROM (
	SELECT Customers.HouseholdId AS Household,
		YEAR(Orders.OrderDate) AS [Order Year],
		SUM(Orders.TotalPrice) AS [Total Amount Spent Current Year],
		SUM(Orders.NumUnits) AS [Total Units Ordered Current Year],
		LAG(SUM(Orders.TotalPrice),1,0) OVER (PARTITION BY Customers.HouseholdId ORDER BY YEAR(Orders.OrderDate)) AS [Total Amount Spent Previous Year]
	FROM Customers
	JOIN Orders ON Customers.CustomerId = Orders.CustomerId
	WHERE Customers.HouseholdId = @household
	GROUP BY YEAR(Orders.OrderDate), Customers.HouseholdId
	) h
);
GO

SELECT * FROM YearlyAmountSpentPerHousehold(19885296);
GO
SELECT * FROM YearlyAmountSpentPerHousehold(36178184);
GO

/* 10. Highlight the locations (based on latitude and longitude) with orders with a value higher than an amount provided by the user */

IF object_id(N'LocationsWithOrderAmount', N'IF') IS NOT NULL
	DROP FUNCTION LocationsWithOrderAmount
GO

CREATE FUNCTION LocationsWithOrderAmount
(
	@order_amount money
)
RETURNS TABLE
AS
RETURN
(
 SELECT ZipCensus.Longitude,
	ZipCensus.Latitude,
	ZipCensus.zcta5 AS [Zip Code],
	Orders.TotalPrice AS [Order Value]
FROM ZipCensus
JOIN Orders ON Orders.ZipCode = ZipCensus.zcta5
WHERE Orders.TotalPrice >= @order_amount
	AND ZipCensus.Latitude BETWEEN 24 AND 50 AND
    ZipCensus.Longitude BETWEEN -125 AND -65
);
GO

SELECT * FROM LocationsWithOrderAmount(5000);
GO