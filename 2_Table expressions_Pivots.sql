USE SQLBook
GO


/* Calculate the number of orders assigned to each County */
/* We'll first change the data type of the ZipCode field, to match between the ZipCounty and Orders tables*/

ALTER TABLE ZipCounty
ALTER COLUMN ZipCode VARCHAR(50) NOT NULL;
GO

-- Using a Common Table Expression

WITH total_ord_arg(zip,num)
AS
(	
	SELECT ZipCode, COUNT(*)
	FROM Orders
	GROUP BY ZipCode
)
SELECT ZipCounty.CountyName,
	   SUM(total_ord_arg.num) AS [Total Number of Orders]
FROM ZipCounty
FULL JOIN total_ord_arg ON ZipCounty.ZipCode = total_ord_arg.zip
GROUP BY ZipCounty.CountyName
ORDER BY [Total Number of Orders] DESC;
GO

/* Same result as the query above (Calculate the number of orders assigned to each County), but without using common table expression */

SELECT ZipCounty.CountyName,
	   COUNT(Orders.OrderId) AS [Number of orders]
FROM ZipCounty
FULL JOIN Orders ON ZipCounty.ZipCode = Orders.ZipCode
GROUP BY ZipCounty.CountyName
ORDER BY [Number of orders] DESC;
GO

/* Find the average number of orders per State*/

WITH order_val
AS
(
	SELECT State,COUNT(*) AS [Number of orders]
	FROM Orders
	GROUP BY State
)
SELECT AVG([Number of orders]) AS [Average number of orders per State]
FROM order_val;
GO

/* Which percent of all the existing products offered by the company corresponds to products included in the "Artwork" category? */

/* I first did a basic count, to make sure the percentage seems reasonable: */

SELECT GroupName, COUNT(*) AS [Number of Products per category]
FROM Products
GROUP BY GroupName
ORDER BY [Number of Products per category];
GO

/* Calculated the percentage for ARTWORK*/

-- attributed 100 to each row that corresponds to an ARTWORK product and 0 to the rest; then calculated the average of all rows to find the Artwork percentage
WITH pct AS 
(
	SELECT IIF([GroupName]='ARTWORK',100.0,0) AS [All Categories]
	FROM Products
)
SELECT FORMAT(AVG([All Categories]), N'N2') AS [Artwork percent]
FROM pct;
GO


/* Which percent of all the existing products corresponds to products from Artwork and Game categories? */

WITH 
a AS
(
	SELECT IIF([GroupName]='ARTWORK',100.0,0) AS acat
	FROM Products
),
g AS
(	SELECT IIF([GroupName]='GAME',100.0,0) AS gcat
	FROM Products
)
SELECT FORMAT(AVG(a.acat), N'N2') AS [Artwork percent],
	FORMAT(AVG(g.gcat), N'N2') AS [Game percent]
FROM a,g;
GO

/* And now let's calculate percentages for all categories in a more conventional way */

WITH TotalProducts 
AS
( SELECT COUNT(ProductId) AS [Total Number of Products] 
	     FROM Products AS P2
),

GroupedProducts 
AS
(
	SELECT GroupName
		 , COUNT(GroupName) AS [Number of Products per category]
		 , MAX([Total Number of Products]) AS [Total Number of Products]
	FROM Products AS P
	-- cross join will join each row of the Products table with Total Products (like a Cartesian product)
	CROSS JOIN TotalProducts AS TP
	GROUP BY GroupName 
)

SELECT GroupName
	, [Number of Products per category]
	, [Total Number of Products]
	, FORMAT(100.0 * [Number of Products per category]/[Total Number of Products],N'N2') AS [Category Percent]
FROM GroupedProducts

/* Categorize the discounts associated with each campaign in 4 categories: no discount, under 15%, between 15%-30% or over 30%.
Then look at all the orders placed in 2015 and 2016 and count how many orders were placed under each discount category */

WITH disc AS
(
	SELECT CampaignId,
		   Channel,
		   Discount,
		   DiscountType=
			CASE WHEN Discount=0 THEN 'No discount' 
			    WHEN Discount<15 THEN 'Under 15 percent'
				WHEN Discount>=15 AND Discount<=30 THEN 'Between 15 and 30 percent'
				ELSE 'Over 30 percent'
			END 
	FROM Campaigns
)

SELECT YEAR(Orders.OrderDate) AS [Order Year],
	   IIF(GROUPING(disc.DiscountType)=1,'Total number of orders',disc.DiscountType) AS [Discount Type],
	   FORMAT(COUNT(Orders.OrderId),'N0') AS [Number of Orders]
FROM disc
JOIN Orders ON Orders.CampaignId=disc.CampaignId
GROUP BY ROLLUP(YEAR(Orders.OrderDate),disc.DiscountType)
HAVING YEAR(Orders.OrderDate)=2016 OR YEAR(Orders.OrderDate) = 2015
ORDER BY YEAR(Orders.OrderDate), DiscountType DESC;
GO


/* Which products sold the highest number of units during the year they were first introduced in the company's offer? 
Add the year the product was introduced for each record.
We'll consider that 2012 is the first available year just for the purpose of this query */

WITH FirstYear(categ,prod,y2012,y2013,y2014,y2015,y2016)
AS
(
	SELECT Products.GroupName AS [Product Category],
	   Products.ProductId,	   
	   SUM(IIF(YEAR(OrderLines.BillDate)=2012,NumUnits,NULL)) AS [Total units sold 2012],
       SUM(IIF(YEAR(OrderLines.BillDate)=2013,NumUnits,NULL)) AS [Total units sold 2013],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits,NULL)) AS [Total units sold 2014],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)) AS [Total units sold 2015],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)) AS [Total units sold 2016]
	FROM Products
	JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
	WHERE YEAR(OrderLines.BillDate) IN (2012,2013,2014,2015,2016)
	GROUP BY Products.GroupName, Products.ProductId
)
SELECT categ AS [Product Category],
	prod as [Product ID],
	COALESCE(y2012, y2013, y2014, y2015, y2016) AS [Units sold in the first year the product was introduced],
	CASE COALESCE(y2012, y2013, y2014, y2015, y2016)
		 WHEN y2012 THEN 2012
		 WHEN y2013 THEN 2013
		 WHEN y2014 THEN 2014
		 WHEN y2015 THEN 2015
		 WHEN y2016 THEN 2016
	END AS [Year the product was introduced]
FROM FirstYear
ORDER BY [Units sold in the first year the product was introduced] DESC;
GO


/* Calculate the average number of units/product that were sold in 2015 and 2016. 
For 2015 ignore the NULLs and for 2016 assume that the NULLs are due to data entry omissions and replace them with 1 (assume each product was sold at least once)*/

WITH avgyear(categ,prod,y2015,y2016)
AS
(
	SELECT Products.GroupName AS [Product Category],
		Products.ProductId,	   
		SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)) AS [Total units sold 2015],
		SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)) AS [Total units sold 2016]
	FROM Products
	LEFT JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
	WHERE YEAR(OrderLines.BillDate) IN (2015,2016)
	GROUP BY Products.GroupName, Products.ProductId
)
SELECT AVG(y2015) AS [Average number of units sold/product in 2015],
	   AVG(ISNULL(y2016,1)) AS [Average number of units sold/product in 2016]
FROM avgyear;
GO


/* Calculate the total revenue generated by state each year between 2014-2016. Show each year's revenue in a separate column. */

SELECT 
	pvt.State,
	pvt.[2014] AS [Total Revenue 2014],
	pvt.[2015] AS [Total Revenue 2015],
	pvt.[2016] AS [Total Revenue 2016]
FROM(
	SELECT State,
		SUM(TotalPrice) AS [Total Revenue per year],
		YEAR(OrderDate) AS [Order Year]
	FROM Orders
	GROUP BY State, YEAR(OrderDate)
	) AS ordyear
PIVOT
(
	SUM([Total Revenue per year])
	FOR [Order Year]
	IN ([2014],[2015],[2016])
) AS pvt
ORDER BY [Total Revenue 2016] DESC;
GO

/* Double- checking the original table that was pivoted in the query above*/

SELECT State,
	SUM(TotalPrice) AS [Total Revenue per year],
	YEAR(OrderDate) AS [Order Year]
FROM Orders
GROUP BY State, YEAR(OrderDate)
ORDER BY State, [Order Year];
GO

/* Calculate the average unit price per product category in 2014, 2015 and 2016. Show each year's average unit price in a separate column*/
/* I checked first the original table to be pivoted*/

SELECT Products.GroupName AS [Product Category],
	   AVG(OrderLines.UnitPrice) AS [Avg Unit Price],
	   YEAR(OrderLines.BillDate) AS [Order Year]
FROM Products
JOIN OrderLines ON Products.ProductId = OrderLines.ProductId
GROUP BY Products.GroupName, YEAR(OrderLines.BillDate)
ORDER BY Products.GroupName, [Order Year];
GO

/* Pivoting the table generated above*/

SELECT 
	pvt.[Product Category],
	pvt.[2014] AS [Avg Unit Price 2014],
	pvt.[2015] AS [Avg Unit Price 2015],
	pvt.[2016] AS [Avg Unit Price 2016]
FROM
	(
	SELECT Products.GroupName AS [Product Category],
		AVG(OrderLines.UnitPrice) AS [Avg Unit Price],
		YEAR(OrderLines.BillDate) AS [Order Year]
	FROM Products
	JOIN OrderLines ON Products.ProductId = OrderLines.ProductId
	GROUP BY Products.GroupName, YEAR(OrderLines.BillDate)	
	) AS prodyear
PIVOT
(
	AVG([Avg Unit Price])
	FOR [Order Year] IN ([2014],[2015],[2016])	
) AS pvt
ORDER BY [Avg Unit Price 2016] DESC;
GO

/* Show a list of the top households in 2016 in terms of number of units purchased from the Artwork, Games and Occasion categories. 
Add the corresponding State for each household. */

/* Created the table to be pivoted first */

SELECT Customers.HouseholdId AS [Household],
	   SUM(OrderLines.NumUnits) AS [Number of Units Purchased],
	   Products.GroupName AS [Product Category]
FROM Customers
JOIN Orders ON Customers.CustomerId=Orders.CustomerId
JOIN OrderLInes ON OrderLines.OrderId=Orders.OrderId
JOIN Products ON Products.ProductId=OrderLines.ProductId
WHERE YEAR(Orders.OrderDate)=2016
GROUP BY Products.GroupName,Customers.HouseHoldId
ORDER BY [Number of Units Purchased] DESC;
GO

/* Pivoting the table above*/

SELECT pvt.[Household],
	   pvt.[State],
	   pvt.[ARTWORK],
	   pvt.[BOOK],
	   pvt.[OCCASION],
	   COALESCE(pvt.[ARTWORK],0)+COALESCE(pvt.[BOOK],0)+COALESCE(pvt.[OCCASION],0) AS [Total]
FROM (
		SELECT Customers.HouseholdId AS [Household],
			   SUM(OrderLines.NumUnits) AS [Number of Units Purchased],
			   Products.GroupName AS [Product Category],
			   Orders.State AS [State]
		FROM Customers
		JOIN Orders ON Customers.CustomerId=Orders.CustomerId
		JOIN OrderLInes ON OrderLines.OrderId=Orders.OrderId
		JOIN Products ON Products.ProductId=OrderLines.ProductId
		WHERE YEAR(Orders.OrderDate)=2016
		GROUP BY Orders.State,Products.GroupName,Customers.HouseHoldId
	) AS house
PIVOT
(	
	SUM([Number of Units Purchased])
	FOR [Product Category] IN ([ARTWORK],[BOOK],[OCCASION])
) AS pvt
ORDER BY [Total] DESC; 
GO













		






