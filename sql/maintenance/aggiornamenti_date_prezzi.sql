


/*

aggiorno  project.ProductCategory_prj con modified date

alter table project.ProductCategory_prj
add modified_date date;

update project.ProductCategory_prj
set modified_date = '2026-08-28'

-------------------------------------------------------------

aggiorno  project.ProductSubCategory_prj con modified date

alter table project.ProductSubCategory_prj
add modified_date date;
go

update project.ProductSubCategory_prj
set modified_date = '2026-08-28'
go


--------------------------------------------------------------

aggiorno  project.Territory_prj con modified date


update project.Territory_prj
set modified_date = '2026-08-28'
go

--------------------------------------------------------------

aggiorno  project.SalesPerson_prj con modified date

alter table project.SalesPerson_prj
add modified_date date;
go

update project.SalesPerson_prj
set modified_date = '2026-08-28'
go

--------------------------------------------------------------


aggiorno  project.Store_prj con modified date

alter table project.Store_prj
add modified_date date;
go

update project.Store_prj
set modified_date = '2026-08-28'
go

--------------------------------------------------------------


aggiorno  project.customer_prj con modified date

alter table project.customer_prj
add modified_date date;
go

update project.customer_prj
set modified_date = '2026-08-28'
go

--------------------------------------------------------------


/*

UPDATE DI project.Product_prj CON ALTRE COLONNE DI Production.Product
PERO' LE HO GIA' MESSE NELL'INSERT FORSE QUESTO E' RIDONDANTE

update c 
set 
c.SafetyStockLevel  = p.SafetyStockLevel,
c.[ReorderPoint] = p.ReorderPoint,
c.[StandardCost] = p.StandardCost
from project.Product_prj as c inner join Production.Product as p
on c.ProductID = p.ProductID;

alter table project.Product_prj
add ListPrice money not null default 0.00;

update c 
set 
c.ListPrice  = p.ListPrice

from project.Product_prj as c inner join Production.Product as p
on c.ProductID = p.ProductID;

aggiorno  project.Product_prj con modified date

alter table project.Product_prj
add modified_date date;
go

update project.Product_prj
set modified_date = '2026-08-28'
go
*/

/*

CAMBIO DATE Startdate E endDate  DI project.productcosthistory_prj 
E LE ATTUALIZZO TRASPORTANDO DATA MASSIMA DI SALESORDERHEADER A TODAY() 


drop table pippo2;


declare @max_orderdate2 DATE;


select @max_orderdate2 = max(orderdate) from sales.salesorderheader;

select productID, startdate, 
		cast(dateadd("DAY",datediff("DAY", @max_orderdate2,Startdate),GETDATE()) as date) as Startdate2,
		case when 
		endDate is null then endDate
		else 
		cast(dateadd("DAY",datediff("DAY", @max_orderdate2,endDate),GETDATE()) as date) 
		end as endDate2
into pippo2
from project.productcosthistory_prj;


update c
set 
c.startdate = cast(cc.Startdate2 as date),
c.endDate = cast(cc.endDate2 as date)

from project.productcosthistory_prj as c inner join pippo2 as cc
on c.productid = cc.productid and c.startdate = cc.startdate;

alter table project.productcosthistory_prj
alter column startdate date;

alter table project.productcosthistory_prj
alter column endDate date;


aggiorno  project.productcosthistory_prj con modified date

alter table project.productcosthistory_prj
add modified_date date;
go

update project.productcosthistory_prj
set modified_date = '2026-08-28'
go

WITH UltimoCosto AS (
    SELECT
        ProductID,
        MAX(StartDate) AS MaxStartDate
    FROM project.productcosthistory_prj
    GROUP BY ProductID
)

UPDATE c
SET EndDate = NULL
FROM project.productcosthistory_prj AS c
INNER JOIN UltimoCosto AS u
    ON c.ProductID = u.ProductID
   AND c.StartDate = u.MaxStartDate
WHERE c.EndDate IS NOT NULL;

ALTER TABLE project.productcosthistory_prj
DROP COLUMN modifieddate;

*/

/*  UPDATE DI project.Salesorderdetail_prj CON I PREZZI AGGIORNATI (MOLTO PROBABILMENTE NON SERVE E' DA CANCELLARE PERCHE' 
IN project.Salesorderdetail_prj NON CI SONO LE DATE 

update c 
set 
c.UnitPrice = h.ListPrice
from project.Salesorderdetail_prj as c 
inner join project.Salesorderheader_prj as j
on c.SalesOrderID = j.Salesorderid inner join 
production.ProductListPriceHistory as h
on c.productID = h.ProductID AND j.OrderDate >= h.StartDate
AND (
    j.OrderDate < h.EndDate
    OR h.EndDate IS NULL
);


CREO LINE TOTAL COMPRENSIVO DELLO SCONTO

update c 
set 

c.LineTotal = (c.UnitPrice * c.OrderQty) * (1- c.UnitPriceDiscount)
from project.Salesorderdetail_prj as c ;

aggiorno  project.Salesorderdetail_prj con modified date

ALTER TABLE project.Salesorderdetail_prj
DROP COLUMN modified_date;
*/


/*
UPDATE DI project.Salesorderheader_prj CON SUBTOTAL MODIFICATO CON AGGREGAZIONE LINETOTAL project.Salesorderdetail_prj COMPRENSIVO DI SCONTO

update c 
set c.subtotal = f.totale_ord
from project.Salesorderheader_prj as c inner join 
(select salesorderid, cast(sum(linetotal) as money) as totale_ord from project.Salesorderdetail_prj group by salesorderid) as f
on c.salesorderid = f.SalesOrderID;



CAMBIO DATE  DI project.salesorderheader_prj
E LE ATTUALIZZO TRASPORTANDO DATA MASSIMA DI SALESORDERHEADER A TODAY()


SERVE SOPRATTUTTO PER LA CREAZIONE DELLA VISTA project.VIEW_orders_detailPB PER POWER BI DOVE INSERISCO I COSTI PER OGNI
PRODOTTO DA project.productcosthistory_prj PER POTER COSTRUIRE IL MARGINE


drop table pippo;



declare @max_orderdate DATE;


select @max_orderdate = max(orderdate) from sales.salesorderheader;

print(@max_orderdate)




select salesorderid,
		@max_orderdate as max, orderdate,  duedate,shipdate, 
		datediff("DAY", @max_orderdate,orderdate) as delta_giorni,  
		cast(dateadd("DAY",datediff("DAY", @max_orderdate,orderdate),GETDATE()) as date) as orderdate2,
		cast(dateadd("DAY",datediff("DAY", @max_orderdate,duedate),GETDATE()) as date) as duedate2,
		cast(dateadd("DAY",datediff("DAY", @max_orderdate,shipdate),GETDATE()) as date) as shipdate2
into pippo
from Sales.salesorderheader;

select * from pippo;


update c
set
c.orderdate = cc.orderdate2,
c.shipdate = cc.shipdate2,
c.duedate = cc.duedate2

from project.salesorderheader_prj as c inner join pippo as cc
on c.salesorderid = cc.salesorderid;


aggiorno  project.salesorderheader_prj con modified date

alter table project.salesorderheader_prj
add modified_date date;
go

update project.salesorderheader_prj
set modified_date = '2026-08-28'
go

*/

