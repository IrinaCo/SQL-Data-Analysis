USE SQLBook
GO

/* What is be probability for a client to use a specific PaymentType?  
Calculate the probability for each Payment Type. */

SELECT PaymentType,
	   [Number of Payments with corresponding PaymentType],
	   [Total orders with valid Payment Type],
	   [Number of Payments with corresponding PaymentType]*1.0/[Total orders with valid Payment Type] AS [Probability to use corresponding Payment Type]
FROM
	(
	SELECT PaymentType,
		   COUNT(*) AS [Number of Payments with corresponding PaymentType],
		   -- we need a subquery to calculate the total number of orders per column (without grouping by type of payment)
		   -- also we ignore the orders with unknown payment type for this query, by taking out the ones with ??
		   (SELECT COUNT(Orders.OrderId) FROM Orders WHERE PaymentType<>'??') AS [Total orders with valid Payment Type]

	FROM Orders
	GROUP BY PaymentType
	)p
WHERE PaymentType<>'??';
GO

-- a slightly shorter way of solving the same problem, but with a more complex execution plan:

SELECT PaymentType,
	   COUNT(*) AS [Number of Payments with corresponding PaymentType],
	   -- we ignore the orders with unknown payment type for this query, by taking out the ones with ??
		(SELECT COUNT(Orders.OrderId) FROM Orders WHERE PaymentType<>'??') AS [Total orders with valid Payment Type],
		COUNT(*)*1.0/(SELECT COUNT(Orders.OrderId) FROM Orders WHERE PaymentType<>'??') AS [Probability to use corresponding Payment Type]
FROM Orders
WHERE PaymentType<>'??'
GROUP BY PaymentType


/* What is the probability of a client using a Visa OR a MasterCard?*/
SELECT 
	   SUM([Number of Payments with corresponding PaymentType]*1.0/[Total orders with valid Payment Type]) AS [Probability of a client using VISA OR MasterCard]
FROM
	(
	SELECT PaymentType,
		   COUNT(*) AS [Number of Payments with corresponding PaymentType],
		   (SELECT COUNT(Orders.OrderId) FROM Orders WHERE PaymentType<>'??') AS [Total orders with valid Payment Type]
	FROM Orders
	GROUP BY PaymentType
	)p
WHERE PaymentType IN ('VI','MC');
GO

/*  What is the probability of a customer using a Visa as a Payment Method 
AND placing the order from the state of NY? */

SELECT 
		SUM([Number of Payments with corresponding PaymentType]*1.0/[Total orders with valid Payment Type]) AS [Probability of a client using VISA from NY]
FROM
	(
	SELECT PaymentType,
			State,
			COUNT(*) AS [Number of Payments with corresponding PaymentType],
			COUNT(State) AS [Number of Orders from corresponding State],
			(SELECT COUNT(Orders.OrderId) FROM Orders WHERE PaymentType<>'??') AS [Total orders with valid Payment Type]
	FROM Orders
	GROUP BY State,PaymentType
	)p
WHERE PaymentType = 'VI' AND State='NY';
GO



/* What is the probability that a randomly selected order will be placed from a county provided by the user?*/

-- we'll create a function that takes the county as a parameter

IF object_id(N'OrderByCountyProbability', N'IF') IS NOT NULL
    DROP FUNCTION OrderByCountyProbability
GO

CREATE FUNCTION OrderByCountyProbability
(
	@county varchar(255)
)
RETURNS TABLE 
AS
RETURN 
(
 SELECT [County Name],
		[Number of Orders],
		(SELECT COUNT(Orders.OrderId) FROM Orders) AS [Total Number of Orders for all counties],
	    [Number of Orders]*1.0/(SELECT COUNT(Orders.OrderId)*1.0 FROM Orders) AS [Probability of randomly selecting an order from the County]
 FROM
	(
	 SELECT ZC.CountyName AS [County Name],
		    COUNT(O.OrderId) AS [Number of Orders]
	 FROM ZipCounty AS ZC
	 JOIN Orders AS O ON ZC.ZipCode = O.ZipCode
	 GROUP BY ZC.CountyName	 
	) o
  WHERE [County Name] = @county
);
GO

-- execute the function
SELECT * FROM OrderByCountyProbability('Washington County');
GO
SELECT * FROM OrderByCountyProbability('BlackFord County');
GO

/* What is the probability of selecting a customer (with at least one order) from a state provided by the user?*/

IF object_id(N'CustomerByStateProbability', N'IF') IS NOT NULL
    DROP FUNCTION CustomerByStateProbability
GO

CREATE FUNCTION CustomerByStateProbability
(
	@state varchar(50)
)
RETURNS TABLE 
AS
RETURN 
(
SELECT [State Name],
	   [Number of Customers per State],
	   [Total number of customers] = (SELECT COUNT(DISTINCT CustomerId) FROM Orders WHERE Orders.State<>''),
	   [Probability of randomly selecting a customer from the selected State] = [Number of Customers per State]*1.0/(SELECT COUNT(CustomerId)*1.0 FROM Customers)
FROM (
		SELECT O.State AS [State Name],
			COUNT(DISTINCT C.CustomerId) AS [Number of Customers per State]
		FROM Orders AS O
		LEFT JOIN Customers AS C ON C.CustomerId=O.CustomerID
		WHERE O.State<> ''
		GROUP BY ROLLUP(O.State)
	  ) s
WHERE [State Name] = @state
);
GO

SELECT * FROM CustomerByStateProbability('CA')
SELECT * FROM CustomerByStateProbability('ND');
GO

/* Show the probability of randomnly selecting a customer (with at least one order) from each state */

SELECT [State Name],
	   [Number of Customers per State],
	   [Total number of customers] = (SELECT COUNT(DISTINCT CustomerId) FROM Orders WHERE Orders.State<>''),
	   [Probability of randomly selecting a customer from the selected State] = [Number of Customers per State]*1.0/(SELECT COUNT(CustomerId)*1.0 FROM Customers)
FROM (
		SELECT Orders.State AS [State Name],
			COUNT(DISTINCT Customers.CustomerId) AS [Number of Customers per State]
		FROM Orders
		LEFT JOIN Customers ON Customers.CustomerId=Orders.CustomerID
		WHERE Orders.State<> ''
		GROUP BY (Orders.State)		
	  ) s;
GO

/* What is the probability of selecting an order that belongs to a particular Campaign Id? 
Calculate it for all Campaign IDs and chart the probabilities. */


SELECT CampaignId,
	   [Number of Orders],
	   [Total Number of Orders] = (SELECT COUNT(Orders.OrderId) FROM Orders),
	   [Probability of randomly selecting an order from the Campaign] = [Number of Orders]*1.0 / (SELECT COUNT(Orders.OrderId) FROM Orders)
FROM
	(
		SELECT Campaigns.CampaignId AS CampaignId, 
			  COUNT(Orders.OrderId) AS [Number of Orders]
		FROM Campaigns
		JOIN Orders ON Orders.CampaignId = Campaigns.CampaignId
		GROUP BY ROLLUP(Campaigns.CampaignId)
	)c;
GO

/* What is the probability that if we randomly select an order it will be placed 
by a male customer vs a female customer vs unknown gender? */

SELECT Gender,
	   [Number of Orders],
	   [Probability] = [Number of Orders]*1.0/(SELECT COUNT(Orders.OrderID) FROM Orders)
FROM
	(
		SELECT Customers.Gender,
			   COUNT(Orders.OrderId) AS [Number of Orders]
		FROM Customers
		JOIN Orders ON Customers.CustomerId = Orders.CustomerId
		GROUP BY Customers.Gender
	) g;
GO


/* What is the probability that if we randomly select "n" orders, "k" of them will be placed from a particular state?
The numbers 'n' and 'k' will be provided by the user */

/* First I created the factorial function - it will be included in the next few queries/functions */

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Factorial]')
AND type in (N'FN', N'IF',N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[Factorial]

GO

CREATE FUNCTION dbo.Factorial (@number float)
RETURNS FLOAT
AS
BEGIN
DECLARE @i  float

    IF @number <= 1
        SET @i = 1
    ELSE
        SET @i = @number * dbo.Factorial( @number - 1 )
RETURN (@i)
END;

GO

IF object_id(N'OrdersByStateProbability', N'IF') IS NOT NULL
    DROP FUNCTION OrdersByStateProbability
GO

CREATE FUNCTION OrdersByStateProbability
(
	@n float,
	@k float
)
RETURNS TABLE 
AS
RETURN 
(
SELECT [State Name],
	   [Number of Orders],
	   [Total number of orders - all states],
	   --probability,
	   [n - Number of orders to be randomnly selected],
	   @k AS [k - Number of orders that correspond to the state],
	   nfact/(nminuskfact * kfact) * power(probability, @k) * power((1-probability),(@n-@k)) AS [Probability of having k out of n orders from the corresponding state]
FROM(
	SELECT [State Name],
		   @n AS [n - Number of orders to be randomnly selected],
		   [Number of Orders],
		   (SELECT COUNT(Orders.OrderId) FROM Orders) AS [Total number of orders - all states],
		   dbo.Factorial(@n) AS nfact,
		   dbo.Factorial(@n - @k) AS nminuskfact,
		   dbo.Factorial(@k) AS kfact,
		   [Number of Orders]*1.0/(SELECT COUNT(Orders.OrderId)*1.0 FROM Orders) AS probability
	FROM
		(SELECT Orders.State AS [State Name],
				COUNT(Orders.OrderId) AS [Number of Orders]
		 FROM Orders
		 GROUP BY Orders.State
		 --ORDER BY COUNT(Orders.OrderId) DESC
		)p
		)pr
WHERE [State Name]<>''
);
GO

SELECT * FROM OrdersByStateProbability(20,5);
GO


/* What is the probability that if we randomly select 'n' products from the company's offer 
(as in selecting them from a catalogue of unique entries), 
'k' of them would belong to a particular group code?
Calculate the probability for all group codes. */

IF object_id(N'ProductCategoryProbability', N'IF') IS NOT NULL
    DROP FUNCTION ProductCategoryProbability
GO

CREATE FUNCTION ProductCategoryProbability
(
	@n float,
	@k float
)
RETURNS TABLE 
AS
RETURN 
(
SELECT GroupCode,
	   @n AS [n - number of products to be randmonly selected],
	   @k AS [k - number of products belonging to group code],
	   [Number of Products] AS [Number of Products in Category],
	   --[All Products],
	   -- probability,
	   nfact/(nminuskfact * kfact) * power(probability, @k) * power((1-probability),(@n-@k)) AS [Probability that k out of n products are from the category]
FROM 
	(SELECT GroupCode,
		   [Number of Products],
		   dbo.Factorial(@n) AS nfact,
		   dbo.Factorial(@n - @k) AS nminuskfact,
		   dbo.Factorial(@k) AS kfact,
		   [All Products],
		   [Number of Products]*1.0/[All Products] *1.0 AS probability
	   FROM 
			(SELECT GroupCode,CAST(COUNT(*) AS FLOAT) AS [Number of Products],
					CAST((SELECT COUNT(Products.ProductId) FROM Products) AS FLOAT) AS [All Products]
			FROM Products
			GROUP BY GroupCode
	)p
	)pr
--WHERE GroupCode=@category
);
GO

SELECT * FROM ProductCategoryProbability(15,3)
SELECT * FROM ProductCategoryProbability(20,1);
GO


/* What is the probability that at most 3 products out of 15 randomly selected from the company's offer will belong to each group code? 
What about the probability that more than 3 out of 15 products will belong to each group? 
Note: I know I should have done this in a loop but I didn't have time to refresh my memory on loops in SQL. I'll try to do that later.*/


SELECT GroupCode,
	   [Number of Products in Category],
	   [All Products],
	   [Probability of selecting at most 3 products from the category] = [Probability of selecting 1 product from the category] + [Probability of selecting 2 products from the category] + [Probability of selecting 3 products from the category],
	   [Probability of selecting more than 3 out of 15 products from the category] = 1 - ([Probability of selecting 1 product from the category] + [Probability of selecting 2 products from the category] + [Probability of selecting 3 products from the category]),
	   [Probability of selecting 1 product from the category],
	   [Probability of selecting 2 products from the category],
	   [Probability of selecting 3 products from the category]
FROM
	(SELECT GroupCode,
			[Number of Products] AS [Number of Products in Category],
			[All Products],
			nfact/(nminuskfact * kfact) * power(probability, 1) * power((1-probability),(14)) AS [Probability of selecting 1 product from the category],
			nfact/(nminuskfact2 * kfact2) * power(probability, 2) * power((1-probability),(13)) AS [Probability of selecting 2 products from the category],
			nfact/(nminuskfact3 * kfact3) * power(probability, 3) * power((1-probability),(12)) AS [Probability of selecting 3 products from the category]

	FROM 
		(SELECT GroupCode,
				[Number of Products],
				dbo.Factorial(15) AS nfact,
				dbo.Factorial(15 - 1) AS nminuskfact,
				dbo.Factorial(1) AS kfact,
				dbo.Factorial(15 - 2) AS nminuskfact2,
				dbo.Factorial(2) AS kfact2,
				dbo.Factorial(15 - 3) AS nminuskfact3,
				dbo.Factorial(3) AS kfact3,
				[All Products],
				[Number of Products]*1.0/[All Products] *1.0 AS probability
			FROM 
				(SELECT GroupCode,CAST(COUNT(*) AS FLOAT) AS [Number of Products],
						CAST((SELECT COUNT(Products.ProductId) FROM Products) AS FLOAT) AS [All Products]
				FROM Products
				GROUP BY GroupCode
		)p
		)pr
		)allp;
GO


/* What is the probability for one Order Line to have 'n' units per order? Calculate it for all the possible options */

SELECT  [Number of Order Lines],
	    [Number of orders with 'n' order lines],
		[Number of orders with 'n' order lines]*1.0/[Total Number of Orders] AS [Probability of an order having 'n' lines]
FROM
	(
	SELECT [Number of Order Lines],
		   COUNT(*) AS [Number of orders with 'n' order lines],
		   (SELECT COUNT(DISTINCT OrderId) FROM OrderLines) AS [Total Number of Orders]
	   
	FROM 
		(
		SELECT OrderId,
				COUNT(OrderLineId) AS [Number of Order Lines]
		FROM OrderLines
		GROUP BY OrderId
		--ORDER BY COUNT(OrderLineId) DESC
		)ol		
	GROUP BY [Number of Order Lines] 
	)pol;
GO

/* What is the probability of an order having at least 5 lines? */

SELECT  
		SUM([Number of orders with 'n' order lines]*1.0/[Total Number of Orders]) AS [Probability of an order having at least 5 lines]
FROM
	(
	SELECT [Number of Order Lines],
		   COUNT(*) AS [Number of orders with 'n' order lines],
		   (SELECT COUNT(DISTINCT OrderId) FROM OrderLines) AS [Total Number of Orders]
	   
	FROM 
		(
		SELECT OrderId,
				COUNT(OrderLineId) AS [Number of Order Lines]
		FROM OrderLines
		GROUP BY OrderId
		--ORDER BY COUNT(OrderLineId) DESC
		)ol		
	GROUP BY [Number of Order Lines] 
	)pol
WHERE [Number of Order Lines] >=5;
GO

/* What is the probability of an order having at most 3 lines? */

SELECT  
		SUM([Number of orders with 'n' order lines]*1.0/[Total Number of Orders]) AS [Probability of an order having at most 3 lines]
FROM
	(
	SELECT [Number of Order Lines],
		   COUNT(*) AS [Number of orders with 'n' order lines],
		   (SELECT COUNT(DISTINCT OrderId) FROM OrderLines) AS [Total Number of Orders]
	   
	FROM 
		(
		SELECT OrderId,
				COUNT(OrderLineId) AS [Number of Order Lines]
		FROM OrderLines
		GROUP BY OrderId
		--ORDER BY COUNT(OrderLineId) DESC
		)ol		
	GROUP BY [Number of Order Lines] 
	)pol
WHERE [Number of Order Lines] <=3;
GO

/* What is the probability for one Order Line to have at least 'n' units per order or at most 'n' units per order? */

SELECT NumUnits,
	   [Number of Order Lines with 'n' number of units],	
	   [Probability for One Order Line to have 'n' units],
	   SUM( [Probability for One Order Line to have 'n' units]) OVER (ORDER BY NumUnits ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Cumulative Probability ASC - at most],
	   SUM( [Probability for One Order Line to have 'n' units]) OVER (ORDER BY NumUnits DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Cumulative Probability DESC - at least]
FROM 
	(  

	SELECT NumUnits,
		   [Number of Order Lines with 'n' number of units],
		   [Number of Order Lines with 'n' number of units]*1.0/[Total Number of Order Lines] AS [Probability for One Order Line to have 'n' units]
	FROM
		(
		SELECT NumUnits,
			   COUNT(DISTINCT OrderLineId) AS [Number of Order Lines with 'n' number of units],
			   (SELECT COUNT(OrderLineId) FROM OrderLines) AS [Total Number of Order Lines]
		FROM OrderLines
		GROUP BY NumUnits
		--ORDER BY NumUnits DESC
		)nu
		)cump
ORDER BY NumUnits;
GO

/* What is the probability for one Order Line to have at least 10 units, 100 units or 1000 units? */

SELECT NumUnits,
	   SUM( [Probability for One Order Line to have 'n' units]) OVER (ORDER BY NumUnits DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Probability of having at least 'n' NumUnits/Order Line]
FROM 
	(  

	SELECT NumUnits,
		   [Number of Order Lines with 'n' number of units],
		   [Number of Order Lines with 'n' number of units]*1.0/[Total Number of Order Lines] AS [Probability for One Order Line to have 'n' units]
	FROM
		(
		SELECT NumUnits,
			   COUNT(DISTINCT OrderLineId) AS [Number of Order Lines with 'n' number of units],
			   (SELECT COUNT(OrderLineId) FROM OrderLines) AS [Total Number of Order Lines]
		FROM OrderLines
		GROUP BY NumUnits
		--ORDER BY NumUnits DESC
		)nu
		)cump
WHERE NumUnits IN (10,100,1000)
ORDER BY NumUnits;
GO
