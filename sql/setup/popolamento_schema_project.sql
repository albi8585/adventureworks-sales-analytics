
use AdventureWorks2022;


insert into project.ProductCategory_prj (productcategoryID , Name)
select productcategoryID , Name
from Production.ProductCategory
;

--------------------------------------------------------

insert into project.ProductsubCategory_prj (productsubcategoryID , productcategoryID, Name)
select productsubcategoryID , productcategoryID, Name
from Production.ProductsubCategory;


--------------------------------------------------------

insert into project.Product_prj (ProductID,Name, Daystomanufacture,
productsubcategoryID, SafetyStockLevel, ReorderPoint, StandardCost) 
select  ProductID,Name, Daystomanufacture,
productsubcategoryID, SafetyStockLevel, ReorderPoint, StandardCost
from production.Product;


-------------------------------------------------------------------------


insert into project.Territory_prj 
(TerritoryID,
Name,
[Group])
select TerritoryID,
Name,
[Group]
from Sales.SalesTerritory;


----------------------------------------------------------

insert into project.SalesPerson_prj 
(BusinessEntityID,
TerritoryID ,
commissionPCT )
select BusinessEntityID,
TerritoryID ,
commissionPCT 
from Sales.SalesPerson;

-----------------------------------------------------------

insert into project.Store_prj
(
BusinessEntityID,
Name,
SalesPersonID)
select BusinessEntityID,
Name,
SalesPersonID
from Sales.Store;

-------------------------------------------------------------

insert into project.customer_prj
(CustomerID,
StoreID,
TerritoryID)
select CustomerID,
StoreID,
TerritoryID
from Sales.Customer;

---------------------------------------------------------------

select *
into project.productcosthistory_prj
from Production.ProductCostHistory;


---------------------------------------------------------------

insert into project.Salesorderdetail_prj (
SalesorderdetailID ,
SalesOrderID ,
OrderQty ,
ProductID ,
UnitPrice ,
LineTotal, 
UnitPriceDiscount,
SpecialOfferID
)
select 
SalesorderdetailID ,
SalesOrderID ,
OrderQty ,
ProductID ,
UnitPrice ,
LineTotal,
UnitPriceDiscount,
SpecialOfferID
from Sales.SalesOrderDetail;


----------------------------------------------------------------------


insert into project.Salesorderheader_prj 
(Salesorderid  ,
orderdate,
duedate ,
shipdate ,
onlineorderflag ,
CustomerID ,
SalesPersonID ,
TerritoryID ,
subtotal )
select Salesorderid  ,
orderdate,
duedate ,
shipdate ,
onlineorderflag ,
CustomerID ,
SalesPersonID ,
TerritoryID ,
subtotal



from sales.SalesOrderHeader
;


-------------------------------------------------------------------


alter table project.customer_prj
add PersonID int null;

update cc
set cc.personID = bb.personID
from 
project.customer_prj as cc inner join sales.Customer as bb
on cc.customerID = bb.CustomerID
;




------------------------------------------------------------------





