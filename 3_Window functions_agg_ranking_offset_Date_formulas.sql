USE SQLBook
GO

/*Find the top 3 customers per each state, based on the highest amount of purchases/customer per state in 2016*/

-- used a subquery (also known as derived table) to be able to filter the result of the window function

SELECT *
FROM
(
	SELECT
		Orders.State,
		-- ROW_NUMBER function computes unique incrementing integers starting with 1 within the window partition based on the window ordering. 
		ROW_NUMBER() OVER(PARTITION BY Orders.State ORDER BY SUM(Orders.TotalPrice) DESC) AS RowNumber,		
		Customers.CustomerId,
		SUM(Orders.TotalPrice) AS [Total Amount Spent],
		SUM(Orders.NumUnits) AS [Total No of Products]
	FROM Orders
	JOIN Customers ON Orders.CustomerId = Customers.CustomerId
	-- excluded the states with empty values and the CustomerId 0
	WHERE Orders.State <>'' AND YEAR(Orders.OrderDate)=2016 AND Customers.CustomerId<>0
	GROUP BY Customers.CustomerId, Orders.State
) AS subquery

WHERE RowNumber IN (1,2,3) -- to return the top 3 customers
ORDER BY State,[Total Amount Spent] DESC;
GO

/* Identifying high value orders.
What is the average amount/order spent by customers in each State, per year? 
Show a list of all orders with the amount per order and the corresponding average amount spent per state and per year.
Calculate the difference between the average order/state/year and each order value.
Flag high value orders (at least $500 above the average order/state/year */

SELECT State,
		YEAR(OrderDate) AS Year,
		Orders.OrderDate,
		Orders.OrderId,
		TotalPrice,
		AVG(TotalPrice) OVER (PARTITION BY State,YEAR(OrderDate)) AS state_year_avg,
		(TotalPrice - AVG(TotalPrice) OVER (PARTITION BY State,YEAR(OrderDate))) AS [Difference btw avg order/state/year and order value],
		IIF ((TotalPrice - AVG(TotalPrice) OVER (PARTITION BY State,YEAR(OrderDate)))>=500,'High value order','Regular order') AS [Flag high value]
FROM Orders
ORDER BY [Flag high value], Year DESC, [Difference btw avg order/state/year and order value] DESC;
GO

/* Find the top selling product categories (in terms of no units sold) per year by assigning a rank */

SELECT  YEAR(OrderLines.BillDate) AS Year,
		Products.GroupName AS [Product Category],
		FORMAT(SUM(OrderLines.NumUnits),'N0') AS [Total no units sold],	   
		RANK() OVER(PARTITION BY YEAR(OrderLines.BillDate) ORDER BY SUM(NumUnits) DESC) AS Rank_by_no_units,
		FORMAT(SUM(OrderLines.TotalPrice),'N0') AS [Total revenue generated]
FROM Products
LEFT JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
WHERE YEAR(OrderLines.BillDate) IS NOT NULL
GROUP BY GroupName,YEAR(OrderLines.BillDate)
ORDER BY Year,Rank_by_no_units;
GO

/* Check how the price of each product evolved over time. Within each product category show:
- the number of products per category/each year,
- how many times each product was sold for a specific price/year, 
- minimum price per product/year, 
- maximum price per product/year, 
- average price per product category/year 
- standard deviation of the price per category/year.*/

SELECT Products.GroupName AS [Product Category],
	   YEAR(OrderLines.BillDate) AS Year,	
	   COUNT(Products.ProductId) OVER(PARTITION BY YEAR(OrderLines.BillDate),Products.GroupName) AS [Total number of products per category],	
       Products.ProductId,
	   OrderLines.UnitPrice,
	   MAX(Orders.OrderDate) AS [Last Order Date],
	   COUNT(OrderLines.OrderLineId) AS [Number of times it was purchased],      
	   MIN(OrderLines.UnitPrice) OVER(PARTITION BY YEAR(OrderLines.BillDate),Products.ProductId) AS [Minimum price per ProductId],
	   MAX(OrderLines.UnitPrice) OVER(PARTITION BY YEAR(OrderLines.BillDate),Products.ProductId) AS [Maximum price per ProductId],
	   AVG(OrderLines.UnitPrice) OVER(PARTITION BY YEAR(OrderLines.BillDate),Products.GroupName) AS [Average price per product category],
	   STDEV(OrderLines.UnitPrice) OVER(PARTITION BY YEAR(OrderLines.BillDate),Products.GroupName) AS [St dev of price per product category]

FROM Products
LEFT JOIN OrderLines ON Products.ProductId=OrderLines.ProductId
JOIN Orders ON Orders.OrderId=OrderLines.OrderId
GROUP BY OrderLines.UnitPrice,Products.ProductId,GroupName,YEAR(OrderLines.BillDate)
ORDER BY [Product Category],Year DESC,[Number of times it was purchased] DESC;
GO

/* Generate a list of the campaign channels with the highest number of orders, by year */

SELECT 
	ROW_NUMBER() OVER(PARTITION BY YEAR(Orders.OrderDate) ORDER BY COUNT(Orders.OrderId) DESC) AS [Row Number],
	YEAR(Orders.OrderDate) AS Year,
	Campaigns.Channel,
	COUNT(Orders.OrderId) AS [Number of Orders]
FROM Campaigns
LEFT JOIN Orders ON Campaigns.CampaignId=Orders.CampaignId
WHERE YEAR(Orders.OrderDate) IS NOT NULL
GROUP BY YEAR(Orders.OrderDate),Campaigns.Channel
ORDER BY YEAR(Orders.OrderDate), [Row Number];
GO

/* Create 5 groups of customers (by assigning each customer to a group), based on the total amount spent on orders */

-- the NTILE function, you can arrange the rows within the partition in a requested number of equally sized tiles, based on the specified ordering
SELECT Customers.CustomerId,
		NTILE(5) OVER(ORDER BY SUM(Orders.TotalPrice) DESC) AS CustGroups,
		CONVERT(NVARCHAR(20),SUM(Orders.TotalPrice),1) AS [Total amount spent]
FROM Customers
JOIN Orders ON Customers.CustomerId=Orders.CustomerId
WHERE Customers.CustomerId<>0
GROUP BY Customers.CustomerId;
GO

/* Pivot the table above to see each customer group as a separate column (to help create a box plot in Excel)*/

SELECT CustomerId,
	   pvt.[1],
	   pvt.[2],
	   pvt.[3],
	   pvt.[4],
	   pvt.[5]
FROM
(
	SELECT Customers.CustomerId,
			NTILE(5) OVER(ORDER BY SUM(Orders.TotalPrice) DESC) AS CustGroups,
			CONVERT(NVARCHAR(20),SUM(Orders.TotalPrice),1) AS [Total amount spent]
	FROM Customers
	JOIN Orders ON Customers.CustomerId=Orders.CustomerId
	WHERE Customers.CustomerId<>0
	GROUP BY Customers.CustomerId
) AS cgroup

PIVOT
(
 MAX([Total amount spent])
 FOR CustGroups
 IN ([1],[2],[3],[4],[5])
) AS pvt;
GO


/* Using the results from the previous query, show the number of customers per each group, the total amount spent by each of the 
5 customer groups and the average, minimum and maximum amounts spent by the customers within each group. */

WITH cg
AS
(
	SELECT Customers.CustomerId,
		NTILE(5) OVER(ORDER BY SUM(Orders.TotalPrice) DESC) AS CustGroups,
		SUM(Orders.TotalPrice) AS [Total amount spent]
	FROM Customers
	JOIN Orders ON Customers.CustomerId=Orders.CustomerId
	WHERE Customers.CustomerId<>0
	GROUP BY Customers.CustomerId
)
SELECT CustGroups,
	   COUNT(CustomerId) AS [Number of Customers per Group],
	   FORMAT(SUM([Total amount spent]),'N0') AS [Total Spent by Group],
	   FORMAT(AVG([Total amount spent]),'N0') AS [Avg spent by customer/Group],
	   FORMAT(MIN([Total amount spent]),'N0') AS [Min spent by customer/Group],
	   FORMAT(MAX([Total amount spent]),'N0') AS [Max spent by customer/Group]
FROM cg
GROUP BY CustGroups
ORDER BY SUM([Total amount spent]) DESC;
GO

/* Create 5 groups of customers, based on the total amount spent on orders, by year */

SELECT 
	   Customers.CustomerId,
	   NTILE(5) OVER(PARTITION BY YEAR(Orders.OrderDate) ORDER BY SUM(Orders.TotalPrice) DESC) AS CustGroup,
	   CONVERT(NVARCHAR(20),SUM(Orders.TotalPrice),1) AS [Total amount spent],
	   YEAR(Orders.OrderDate) AS Year
FROM Customers
JOIN Orders ON Customers.CustomerId=Orders.CustomerId
WHERE Customers.CustomerId<>0
GROUP BY Customers.CustomerId,YEAR(Orders.OrderDate)
ORDER BY Year DESC, CustGroup;

/* Using the results from the query above, show the number of customers per each year and per each group, 
the total amount spent by each of the 5 customer groups
and the average, minimum and maximum amounts spent by the customers within each group. */

WITH cg
AS
(
	SELECT 
		Customers.CustomerId,
		NTILE(5) OVER(PARTITION BY YEAR(Orders.OrderDate) ORDER BY SUM(Orders.TotalPrice) DESC) AS CustGroup,
		SUM(Orders.TotalPrice) AS [Total amount spent],
		YEAR(Orders.OrderDate) AS Year
		FROM Customers
		JOIN Orders ON Customers.CustomerId=Orders.CustomerId
		WHERE Customers.CustomerId<>0
		GROUP BY Customers.CustomerId,YEAR(Orders.OrderDate)
)
SELECT CustGroup,
	   Year,
	   COUNT(CustomerId) AS [Number of Customers per Group],
	   FORMAT(SUM([Total amount spent]),'N0') AS [Total Spent by Group],
	   FORMAT(AVG([Total amount spent]),'N0') AS [Avg spent by customer/Group],
	   FORMAT(MIN([Total amount spent]),'N0') AS [Min spent by customer/Group],
	   FORMAT(MAX([Total amount spent]),'N0') AS [Max spent by customer/Group]
FROM cg
GROUP BY CustGroup,Year
ORDER BY Year, CustGroup;
GO	

/* Calculate the date of first purchase, the date of last purchase and the 
Recency (number of days since last purchase)
Frequency (total number of puchases)
Monetary value (total amount spent) 
Assume that the current date is 2016-12-31.*/

SELECT Customers.HouseholdId,
	   Orders.OrderDate AS [Current Order Date],
	   FIRST_VALUE(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate ) AS [Date of first purchase],
	   FIRST_VALUE(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate DESC) AS [Date of last purchase],
	   DATEDIFF(day,CONVERT(DATE,FIRST_VALUE(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate DESC)),'2016-12-31') AS [Number of days since last purchase],
	   COUNT(Orders.OrderId) OVER (PARTITION BY Customers.HouseholdId) AS [Number of purchases],
	   SUM(Orders.TotalPrice) OVER (PARTITION BY Customers.HouseholdId) AS [Total Amount Spent]
FROM Customers
JOIN Orders ON Orders.CustomerId = Customers.CustomerId
WHERE Customers.HouseholdId<>0
ORDER BY Customers.HouseholdId,Orders.OrderDate;
GO

/* Starting from the query above, calculate a RFM score (Recency, Frequency, Monetary value) for all the households in the database.
Give a score from 1 to 5 for each of the Recency, Frequency and Monetary value indicators (5 corresponds to the best/highest value)
Add the scores for R, F, M to get the final RFM SCore. 
Order all the households by RFM score and then by Monetary Value and calculate a percent rank for each.*/

WITH rfm
AS
(
	SELECT Customers.HouseholdId,
		   FIRST_VALUE(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate DESC) AS [Date of last purchase],
		   DATEDIFF(day,CONVERT(DATE,FIRST_VALUE(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate DESC)),'2016-12-31') AS [Recency],
		   COUNT(Orders.OrderId) OVER (PARTITION BY Customers.HouseholdId) AS [Frequency],
		   SUM(Orders.TotalPrice) OVER (PARTITION BY Customers.HouseholdId) AS [Monetary Value]
	FROM Customers
	JOIN Orders ON Orders.CustomerId = Customers.CustomerId
	WHERE Customers.HouseholdId<>0	
)
,RFMCalc AS
(
	SELECT HouseholdId,
			MAX(Recency) AS Recency,
			MAX(Frequency) AS Frequency,
			MAX([Monetary Value]) AS [Monetary Value],
			NTILE(5) OVER(ORDER BY MAX(Recency) DESC) AS RecencyScore,
			NTILE(5) OVER(ORDER BY MAX(Frequency)) AS FrequencyScore,
			NTILE(5) OVER(ORDER BY MAX([Monetary Value])) AS MonetaryScore,
			NTILE(5) OVER(ORDER BY MAX(Recency) DESC) + NTILE(5) OVER(ORDER BY MAX(Frequency)) + NTILE(5) OVER(ORDER BY MAX([Monetary Value])) AS RFMScore
	FROM rfm
	GROUP BY HouseholdId
)
SELECT
	   RFMCalc.*,
	   FORMAT(PERCENT_RANK() OVER(ORDER BY RFMScore DESC,[Monetary Value] DESC),'N5') AS [Percent Rank]
FROM RFMCalc
ORDER BY RFMScore DESC,[Monetary Value] DESC;
GO



/* Show the number of days since last order per HouseholdId & per order
(number of days between current order and previous order) */

SELECT Customers.HouseholdId,
	   COUNT(OrderId) OVER (PARTITION BY Customers.HouseholdId) AS [No orders per household],
	   Orders.OrderDate AS [Order Date],
	   LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate) AS [Previous Order Date],
	   DATEDIFF(day,LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate),Orders.OrderDate) AS [Days since Last order]
FROM Customers
JOIN Orders ON Customers.CustomerId=Orders.CustomerId
WHERE Customers.HouseholdId<>0
ORDER BY Customers.HouseholdId,Orders.OrderDate;
GO

/* Use the query above to calculate the median number of days between orders for each Householdid*/

WITH btworders
AS
(
	SELECT Customers.HouseholdId AS Household,
		   COUNT(OrderId) OVER (PARTITION BY Customers.HouseholdId) AS [No orders per household],
		   Orders.OrderDate AS [Order Date],
		   LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate) AS [Previous Order Date],
		   DATEDIFF(day,LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate),Orders.OrderDate) AS [Days since Last order]
	FROM Customers
	JOIN Orders ON Customers.CustomerId=Orders.CustomerId
	WHERE Customers.HouseholdId<>0
)
SELECT btworders.*,
	   -- PERCENTILE_CONT is deterministic - Calculates a percentile based on a continuous distribution of the column
	   -- The result is interpolated and might not be equal to any of the specific values in the column.
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Days since Last order]) OVER(PARTITION BY Household) AS [Median no of days btw orders - CONT],
	   -- PERCENTILE_DISC PERCENTILE_DISC calculates the percentile based on a discrete distribution of the column values. 
	   -- The result is equal to a specific column value.
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY [Days since Last order]) OVER(PARTITION BY Household) AS [Median no of days btw orders - DISC]
FROM btworders
ORDER BY Household;
GO

/*Buid on the query above to rank all the households with 2+ orders based on the median no of days btw orders (use the CONT Version)*/

WITH btworders
AS
(
	SELECT Customers.HouseholdId AS Household,
		   COUNT(OrderId) OVER (PARTITION BY Customers.HouseholdId) AS [No orders per household],
		   Orders.OrderDate AS [Order Date],
		   LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate) AS [Previous Order Date],
		   DATEDIFF(day,LAG(Orders.OrderDate) OVER (PARTITION BY Customers.HouseholdId ORDER BY Orders.OrderDate),Orders.OrderDate) AS [Days since Last order]
	FROM Customers
	JOIN Orders ON Customers.CustomerId=Orders.CustomerId
	WHERE Customers.HouseholdId<>0
)
,med AS
(
	SELECT btworders.*,
		   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Days since Last order]) OVER(PARTITION BY Household) AS [Median no of days btw orders - CONT],
		   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY [Days since Last order]) OVER(PARTITION BY Household) AS [Median no of days btw orders - DISC]
	FROM btworders
)
,ranking AS
(
	SELECT Household,
		   [No orders per household],
		   [Median no of days btw orders - CONT],
		   DENSE_RANK() OVER(ORDER BY [Median no of days btw orders - CONT]) AS Rank
	FROM med
	WHERE [No orders per household]>=2
)
SELECT ranking.*
FROM ranking
GROUP BY [No orders per household],[Median no of days btw orders - CONT],Rank,Household
ORDER BY Rank;
GO

/*Find the difference in total amount spent/household over subsequent years for Household=19885296*/

WITH amount 
AS
( 
	SELECT Customers.HouseholdId AS Household,
			YEAR(OrderDate) AS [Order Year],
			SUM(Orders.TotalPrice) AS [Total Amount Spent Current Year]
	FROM Customers
	INNER JOIN Orders ON Customers.CustomerId = Orders.CustomerId
	WHERE Customers.HouseholdId<>0
	GROUP BY YEAR(OrderDate),Customers.HouseholdId
)
,diff AS
(
	SELECT Household,
	       [Order Year], 
		   [Total Amount Spent Current Year],
		   LEAD([Total Amount Spent Current Year],1,0) OVER (PARTITION BY Household ORDER BY [Order Year]) AS [Total Amount Spent Next Year]
	FROM amount
	WHERE Household=19885296
)
SELECT *,
	   IIF([Total Amount Spent Next Year]=0,NULL,[Total Amount Spent Next Year]-[Total Amount Spent Current Year]) AS Difference	    
FROM diff
ORDER BY Household, [Order Year];
GO







	   