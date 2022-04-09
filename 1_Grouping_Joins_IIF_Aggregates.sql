USE SQLBook
GO

/* Removed the test records added throughout the script - to be able to rerun it without insert errors */
DELETE FROM Products
WHERE ProductId=15000;
GO

DELETE FROM Customers
WHERE CustomerId=189560;
GO

/* Find the average monthly fee paid by Subcribers, based on RatePlan */

SELECT RatePlan
	 , AVG(MonthlyFee) AS [Average Monthly Fee]
FROM Subscribers
GROUP BY RatePlan;
GO

/*Calculate the average monthly fee paid by Subscribers, grouped by Channel, RatePlan and Market*/

SELECT Channel, RatePlan, Market
	 , AVG(MonthlyFee) AS [Average Monthly Fee]
FROM Subscribers
GROUP BY Market, RatePlan,Channel;
GO

/* Count the Active Subscribers only, grouped by RatePlan and Market and calculate the average monthly fee paid by each category */

SELECT RatePlan, Market, IsActive
	 , COUNT(*) AS [Number of Subscribers]
	 , AVG(MonthlyFee) AS [Average Monthly Fee]
FROM Subscribers
GROUP BY IsActive, Market, RatePlan
-- HAVING is used to filter the grouped data
HAVING IsActive = 1;
GO

/* Count the subscribers from each Market and include subtotals calculated per each Market */

-- GROUPING indicates whether a column expression in a GROUP BY is aggregated (=1) or not (=0)
-- In this case, we use it to create the labels for the subtotals and grand total.
-- FORMAT helps format the display of the result

SELECT 
	IIF(GROUPING(Market)=1,'All Markets',Market) AS Market,
	IIF(GROUPING(RatePlan)=1,'Total',RatePlan) AS RatePlan, 
	FORMAT(COUNT(*),N'N0') AS [Number of subscribers]
FROM Subscribers
-- ROLLUP returns the subtotals and grand total for Market
GROUP BY ROLLUP(Market,RatePlan);
GO


/* What is the total the number of products ordered within each category (GroupName), grouped by the customer's gender?  */

SELECT IIF(GROUPING(p.GroupName)=1, 'All Groups', p.GroupName) AS GroupName,
	   IIF(GROUPING(c.Gender)=1,'Total',c.Gender) AS Gender,
	   FORMAT(COUNT(*),N'N0') AS [Number of products ordered by Gender],
	   FORMAT(SUM(ol.UnitPrice*ol.NumUnits),N'N0') AS [Total Amount Spent]
FROM Products AS p
-- JOIN is the short version of INNER JOIN - it displays only the rows that have a match in both joined tables.
JOIN OrderLines AS ol ON ol.ProductID=p.ProductID
JOIN Orders AS o ON o.OrderID=ol.OrderID
JOIN Customers AS c ON c.CustomerID=o.CustomerID
-- ROLLUP returns subtotals (per groups) and the grand total
GROUP BY ROLLUP(p.GroupName,c.Gender);
GO

/* Calculate the total amount spent by customer (using Customer ID) and the total number of orders per customer. Include the customers with no orders */
/* Added first a test customer with no attached orders to test the left join*/

INSERT INTO Customers
VALUES(189560, 1234567, 'M','Test');
GO

SELECT 
	Customers.CustomerId,
	SUM(Orders.TotalPrice)AS [Total Amount Spent],
	COUNT(Orders.OrderID) AS [Total Number of Orders]
FROM Customers
-- LEFT JOIN preserves all rows from the left side (in this case Customers). 
-- We use LEFT JOIN here to make sure we also include the customers with no entries in the Orders table
LEFT JOIN Orders ON Customers.CustomerId = Orders.CustomerID
GROUP BY Customers.CustomerId
ORDER BY [CustomerID] DESC;
GO

/* Show a list of the products that have never been included in an order*/
/* Added a test product with no attached orders*/

INSERT INTO Products
VALUES(15000,'','OT','OTHER','N',30);
GO

SELECT 
	Products.ProductId,
	SUM(OrderLines.NumUnits) AS ['Total Units Sold']
FROM Products
LEFT JOIN OrderLines ON Products.ProductId = OrderLines.ProductId
-- WHERE filters the rows of the joined tables, based on the IS NULL condition
-- The filtering happens before grouping
WHERE OrderLines.ProductId IS NULL
GROUP BY Products.ProductId;
GO


/* Calculate the total number of products acquired by each household and the number of orders/household. Include all the households and all the orders. */

SELECT Customers.HouseholdId,
	   SUM(Orders.NumUnits) AS [Number of products ordered],
	   COUNT(Orders.OrderID) AS [Number of orders]	   
FROM Customers
FULL JOIN Orders ON Customers.CustomerId = Orders.CustomerId
GROUP BY Customers.HouseholdId
ORDER BY [Number of orders] DESC;
GO

/* Saw from the query above that the top 3 households have a number of products ordered up to 80k. 
Double check in the OrderLines table if there are orders that include a large number of products (which would justify the numbers above) */

SELECT OrderID, COUNT(OrderLineId) AS [Number of lines per order],SUM(NumUnits) AS [Number of products per order]
FROM OrderLines
GROUP BY OrderId
HAVING SUM(NumUnits)>500;
GO

/* Calculate the total number of units ordered per product category (GroupName) per year, between 2014-2016 */

SELECT IIF(GROUPING(Products.GroupName)=1, 'All product categories',Products.GroupName) AS [Product Group Name],
       SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits,NULL)) AS [Total units sold 2014],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)) AS [Total units sold 2015],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)) AS [Total units sold 2016]
FROM Products
JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
WHERE YEAR(OrderLines.BillDate) IN (2014,2015,2016)
GROUP BY ROLLUP(Products.GroupName)
ORDER BY [Total units sold 2016] DESC;
GO


/* Calculate the total revenue generated by each product category (GroupName) per year, between 2014-2016 */

SELECT IIF(GROUPING(Products.GroupName)=1, 'All product categories',Products.GroupName) AS [Product Group Name],
       SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits*UnitPrice,NULL)) AS [Total revenue 2014],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits*UnitPrice,NULL)) AS [Total revenue 2015],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits*UnitPrice,NULL)) AS [Total revenue 2016]
FROM Products
JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
WHERE YEAR(OrderLines.BillDate) IN (2014,2015,2016)
GROUP BY ROLLUP(Products.GroupName)
ORDER BY [Total revenue 2016] DESC;
GO


/* Interestingly, looking at the variety of products available within each category (from the first query), it seems that categories with the lowest number of product options sold the most units in recent years.
Generate a list of the top selling products between 2012-2016 and their corresponding product category.
Order them by the total number of units sold between 2012-2016 and show only the products that sold at least 500 units in total between 2012-2016 */

SELECT MAX(Products.GroupName) AS [Product Category],
	   Products.ProductId,	   
	   SUM(IIF(YEAR(OrderLines.BillDate)=2012,NumUnits,NULL)) AS [Total units sold 2012],
       SUM(IIF(YEAR(OrderLines.BillDate)=2013,NumUnits,NULL)) AS [Total units sold 2013],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits,NULL)) AS [Total units sold 2014],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)) AS [Total units sold 2015],
	   SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)) AS [Total units sold 2016],
	   -- COALESCE accepts a list of expressions and returns the first one that is not null
	   -- we use it here to replace the NULLS with zero, in order to calculate the Total
	   COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2012,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2013,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits,NULL)),0)  + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)),0) AS Total
FROM Products
JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
WHERE YEAR(OrderLines.BillDate) IN (2012,2013,2014,2015,2016)
GROUP BY Products.ProductId
HAVING COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2012,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2013,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2014,NumUnits,NULL)),0)  + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2015,NumUnits,NULL)),0) + COALESCE(SUM(IIF(YEAR(OrderLines.BillDate)=2016,NumUnits,NULL)),0) >=500
ORDER BY Total DESC;
GO
		
			



		
	   


















