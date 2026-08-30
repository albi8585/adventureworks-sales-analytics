-- VISTA RETENTION E COHORT CLIENTI

/*
create or alter view project.VIEW_customer_cohort_analysis as

with creoPrimodelmese as (
select customerID, salesorderid, DATEFROMPARTS(year(orderdate), MONTH(orderdate), 01) as primoDelmeseordini
from project.Salesorderheader_prj
),

prendo_tutti_mesi as (

select customerID, salesorderid, ca.data_inizio_mese
from project.calendario_prj as ca left join creoprimodelmese as cr
on ca.data_inizio_mese = cr.primoDelmeseordini
where ca.data_inizio_mese > '2024-01-01'
),

prendo_massimo_minimo as (

select min(primoDelmeseordini) as minimo, max(primoDelmeseordini) as massimo
from creoPrimodelmese 
),

taglio_dataset as (
select pt.*
from prendo_tutti_mesi as pt inner join prendo_massimo_minimo as pm
on  data_inizio_mese <= massimo 
),

prendo_minima_data_ordine_perCliente as (
select customerID, min(data_inizio_mese) as data_inizio_cohort
from taglio_dataset
group by customerid 
)
,

faccio_cohort as (

select customerID, data_inizio_cohort, dense_rank() over (order by data_inizio_cohort asc) as cohort
from prendo_minima_data_ordine_perCliente
),

metto_insieme_totale_cohort as (
select td.*,  data_inizio_cohort,cohort
from taglio_dataset as td inner join faccio_cohort as fc 
on td.customerid = fc.customerid
)
,

aggrego_cohort_mese1 as (
select data_inizio_cohort,cohort , coalesce(count(distinct customerID),0) as mese1
from metto_insieme_totale_cohort
where data_inizio_mese = data_inizio_cohort
group by data_inizio_cohort,cohort 

)
,
aggrego_cohort_mese3 as (
select data_inizio_cohort,cohort , coalesce(count(distinct customerID),0)  as mese3
from metto_insieme_totale_cohort
where data_inizio_mese = dateadd("MONTH", 3, data_inizio_cohort)
group by data_inizio_cohort,cohort 
)
,
aggrego_cohort_mese6 as (
select data_inizio_cohort,cohort , coalesce(count(distinct customerID),0)  as mese6
from metto_insieme_totale_cohort
where data_inizio_mese = dateadd("MONTH", 6, data_inizio_cohort)
group by data_inizio_cohort,cohort 
)
,
aggrego_cohort_mese12 as (
select data_inizio_cohort,cohort , coalesce(count(distinct customerID),0)  as mese12
from metto_insieme_totale_cohort
where data_inizio_mese = dateadd("MONTH", 12, data_inizio_cohort)
group by data_inizio_cohort,cohort 
),

aggrego_cohort_mese24 as (
select data_inizio_cohort,cohort , coalesce(count(distinct customerID),0) as mese24
from metto_insieme_totale_cohort
where data_inizio_mese = dateadd("MONTH", 24, data_inizio_cohort)
group by data_inizio_cohort,cohort 
)
,

metto_insieme as (
select ma.cohort , ma.data_inizio_cohort, coalesce(mese1,0) as mese1, coalesce(mese3,0) as mese3, coalesce(mese6,0) as mese6,coalesce(mese12,0) as mese12, coalesce(mese24,0) as mese24
from aggrego_cohort_mese1 as ma left join aggrego_cohort_mese3 as mb 
on ma.cohort = mb.cohort
left join aggrego_cohort_mese6 as mc
on ma.cohort = mc.cohort
left join aggrego_cohort_mese12 as md
on ma.cohort = md.cohort
left join aggrego_cohort_mese24 as me
on ma.cohort = me.cohort
)

select		*,   
			cast(cast(mese3 as decimal (10,2))/nullif(mese1,0) as decimal (10,4)) as retention_month3, 
			cast(cast(mese6 as decimal (10,2))/nullif(mese1,0)as decimal (10,4) ) as retention_month6,
			cast(cast(mese12 as decimal (10,2))/nullif(mese1,0) as decimal (10,4)) as retention_month12,
			cast(cast(mese24 as decimal (10,2))/nullif(mese1,0) as decimal (10,4)) as retention_month24
from metto_insieme
;
*/

/*

CREATE OR ALTER VIEW project.VIEW_customer_cohort_analysis AS

WITH ordini AS (
    SELECT
        CustomerID,
        SalesOrderID,
        CAST(OrderDate AS date) AS OrderDate
    FROM project.Salesorderheader_prj
),

-- Primo acquisto assoluto del cliente
primo_acquisto AS (
    SELECT
        CustomerID,
        MIN(OrderDate) AS FirstOrderDate
    FROM ordini
    GROUP BY CustomerID
),

-- Assegno il cliente alla cohort del mese del primo acquisto
cohort_clienti AS (
    SELECT
        CustomerID,
        FirstOrderDate,
        DATEFROMPARTS(
            YEAR(FirstOrderDate),
            MONTH(FirstOrderDate),
            1
        ) AS data_inizio_cohort
    FROM primo_acquisto
),

-- Per ogni cliente verifico se ha effettuato almeno
-- un ALTRO ordine entro 3 / 6 / 12 mesi
flag_retention AS (
    SELECT
        c.CustomerID,
        c.data_inizio_cohort,
        c.FirstOrderDate,

        MAX(
            CASE
                WHEN o.OrderDate > c.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 3, c.FirstOrderDate)
                THEN 1
                ELSE 0
            END
        ) AS repeat_3m,

        MAX(
            CASE
                WHEN o.OrderDate > c.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 6, c.FirstOrderDate)
                THEN 1
                ELSE 0
            END
        ) AS repeat_6m,

        MAX(
            CASE
                WHEN o.OrderDate > c.FirstOrderDate
                 AND o.OrderDate <= DATEADD(MONTH, 12, c.FirstOrderDate)
                THEN 1
                ELSE 0
            END
        ) AS repeat_12m

    FROM cohort_clienti AS c

    LEFT JOIN ordini AS o
        ON c.CustomerID = o.CustomerID

    WHERE c.data_inizio_cohort > '2024-01-01'

    GROUP BY
        c.CustomerID,
        c.data_inizio_cohort,
        c.FirstOrderDate
),

-- Aggregazione per cohort
aggrego_cohort AS (
    SELECT
        data_inizio_cohort,

        COUNT(*) AS clienti_cohort,

        SUM(repeat_3m) AS clienti_repeat_3m,
        SUM(repeat_6m) AS clienti_repeat_6m,
        SUM(repeat_12m) AS clienti_repeat_12m

    FROM flag_retention

    GROUP BY data_inizio_cohort
),

numero_cohort AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY data_inizio_cohort
        ) AS cohort
    FROM aggrego_cohort
)

SELECT
    cohort,
    data_inizio_cohort,

    clienti_cohort,

    clienti_repeat_3m,
    clienti_repeat_6m,
    clienti_repeat_12m,

    CAST(
        CAST(clienti_repeat_3m AS decimal(10,2))
        / NULLIF(clienti_cohort,0)
        AS decimal(10,4)
    ) AS retention_month3,

    CAST(
        CAST(clienti_repeat_6m AS decimal(10,2))
        / NULLIF(clienti_cohort,0)
        AS decimal(10,4)
    ) AS retention_month6,

    CAST(
        CAST(clienti_repeat_12m AS decimal(10,2))
        / NULLIF(clienti_cohort,0)
        AS decimal(10,4)
    ) AS retention_month12

FROM numero_cohort;

*/

CREATE OR ALTER VIEW project.VIEW_customer_repeat_purchase_rate AS

WITH primo_acquisto AS (
    SELECT
        CustomerID,
        MIN(CAST(OrderDate AS date)) AS FirstOrderDate
    FROM project.Salesorderheader_prj
    GROUP BY CustomerID
),

repeat_cliente AS (
    SELECT
        p.CustomerID,
        p.FirstOrderDate,

        MAX(CASE
            WHEN o.OrderDate > p.FirstOrderDate
             AND o.OrderDate <= DATEADD(MONTH, 3, p.FirstOrderDate)
            THEN 1 ELSE 0
        END) AS repeat_3m,

        MAX(CASE
            WHEN o.OrderDate > p.FirstOrderDate
             AND o.OrderDate <= DATEADD(MONTH, 6, p.FirstOrderDate)
            THEN 1 ELSE 0
        END) AS repeat_6m,

        MAX(CASE
            WHEN o.OrderDate > p.FirstOrderDate
             AND o.OrderDate <= DATEADD(MONTH, 12, p.FirstOrderDate)
            THEN 1 ELSE 0
        END) AS repeat_12m

    FROM primo_acquisto AS p

    LEFT JOIN project.Salesorderheader_prj AS o
        ON p.CustomerID = o.CustomerID

    GROUP BY
        p.CustomerID,
        p.FirstOrderDate
)

SELECT

    CAST(
        AVG(
            CASE 
                WHEN FirstOrderDate <= DATEADD(MONTH, -3, CAST(GETDATE() AS date))
                THEN CAST(repeat_3m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_3m,

    CAST(
        AVG(
            CASE 
                WHEN FirstOrderDate <= DATEADD(MONTH, -6, CAST(GETDATE() AS date))
                THEN CAST(repeat_6m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_6m,

    CAST(
        AVG(
            CASE 
                WHEN FirstOrderDate <= DATEADD(MONTH, -12, CAST(GETDATE() AS date))
                THEN CAST(repeat_12m AS decimal(10,4))
            END
        )
        AS decimal(10,4)
    ) AS avg_repeat_rate_12m

FROM repeat_cliente;




--VISTA Purchase Sequence / Next Best Product



create or alter view project.VIEW_customer_purchase_sequence as

with confronto_ordini as (
select customerid,
	   salesorderid,
	   orderdate,
	   lead(salesorderid) over (partition by customerid order by orderdate asc) as nextsalesorderid,
	   lead(orderdate) over (partition by customerid order by orderdate asc) as nextorderdate
from project.Salesorderheader_prj
)
,


subcategory_order as (
select distinct so.Salesorderid, subcategory 
from project.Salesorderheader_prj as so inner join project.Salesorderdetail_prj as st
on so.Salesorderid = st.SalesOrderID 
inner join project.dimensioni_prod_cat_prj as pc 
on st.ProductID = pc.productid
)
,



transitions as (
select customerID,
	  o.salesorderid,
	  o.nextsalesorderid,
	  a.subcategory as prev_subcategory,
	  b.subcategory as next_subcategory,
	  DATEDIFF(day, orderdate, nextorderdate) as DaysBetweenPurchases
from confronto_ordini as o inner join subcategory_order as a 
on o.Salesorderid = a.Salesorderid

inner join subcategory_order as b
on o.nextsalesorderid = b.Salesorderid
where o.nextsalesorderid is not null
)
,


stat as (
select prev_subcategory,next_subcategory, count(distinct nextsalesorderid) as num_next_orders,
	   count(distinct customerID) as num_customers,
	   AVG(DaysBetweenPurchases) as avgdays_cons_orders
from transitions 
	   GROUP BY prev_subcategory, next_subcategory
)
,

tot_next_ord as (
select prev_subcategory, count(distinct nextsalesorderid) as TotalNextOrders
from transitions
group by prev_subcategory
),

metto_insieme as (
select s.*, TotalNextOrders, cast(cast(num_next_orders as decimal(10,4))/nullif(TotalNextOrders,0) as decimal(10,4))   as transition_rate
from stat as s inner join tot_next_ord as t
on s.prev_subcategory = t.prev_subcategory
) 

select * from metto_insieme;





create or alter view project.VIEW_purchase_frequency as

with ordine_prec as (
select 
		CustomerID,
		SalesOrderID,
		OrderDate,
		lag(orderdate) over (partition by customerID order by OrderDate) as  PreviousOrderDate
from project.Salesorderheader_prj
)
,

confronto_temporale as (
select a.*, c.Name,
	   DATEDIFF(DAY, PreviousOrderDate,a.OrderDate) as DaysBetweenOrders
from ordine_prec as a inner join project.Salesorderheader_prj as b
on a.Salesorderid = b.Salesorderid
inner join project.Territory_prj as c
on b.TerritoryID = c.TerritoryID
where PreviousOrderDate is not null
)
,
num_ord_clienti as (
select customerid , count(*) as NumberOfOrders
from project.Salesorderheader_prj
group by customerid
),

metto_insieme as (

select name, 
	   count(distinct ct.customerID) as TotalCustomers, 
	   avg(NumberOfOrders) as AverageOrdersPerCustomer,
	   avg(DaysBetweenOrders) as AverageDaysBetweenOrders

from  confronto_temporale as ct inner join num_ord_clienti as nc
on ct.CustomerID = nc.CustomerID
group by name
)
,

mediana as (
select distinct a.*,
	   MedianDays_betweenOrders,
       P75,
	   P90
from metto_insieme as a inner join (
									select name,
										   PERCENTILE_CONT(0.5) within group (order by DaysBetweenOrders) over (partition by name) as MedianDays_betweenOrders,
										   PERCENTILE_CONT(0.75) within group (order by DaysBetweenOrders) over (partition by name) as P75,
										   PERCENTILE_CONT(0.90) within group (order by DaysBetweenOrders) over (partition by name) as P90
										   from confronto_temporale
									
														) as b
on a.name = b.name)


select * from  mediana;









