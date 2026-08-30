use AdventureWorks2022;


--CREO VISTE PER POWERBI PRENDENDO SOLO TABELLA ORDERDETAILS PER AVERE LA MASSIMA GRANULARITA' E INSERENDO LE INFORMAZIONI DELLA TABELLA
--ORDINI E QUELLE DELLA STORIA DEI COSTI DEI PRODOTTI PER COSTRUIRE COLONNA DEI MARGINI

create or alter view project.VIEW_orders_detailPB as
with aggiungoDate_costoprod as (
select a.*,b.orderdate, b.duedate, b.shipdate,  b.onlineorderflag,  b.CustomerID, c.StandardCost,b.SalesPersonID, b.TerritoryID, b.modified_date
from project.Salesorderdetail_prj as a inner join project.Salesorderheader_prj as b 
on a.SalesOrderID = b.Salesorderid inner join project.productcosthistory_prj as c
on a.productID = c.productID and b.orderdate >= c.StartDate and (b.orderdate <= c.EndDate or c.EndDate is null)
)



select *, (linetotal - (StandardCost*OrderQty)) as margine_prodotto_ordine, (cast((linetotal - (StandardCost*OrderQty))*100 as decimal(10,2))/linetotal) 
as pct_margine_prodotto_ordine
from aggiungoDate_costoprod


;


--CREO VISTA ULTIMO TRIMESTRE DALLA VISTA DI DETTAGLIO ORDINI PRECEDENTE

create or alter view project.VIEW_orders_detailPB_120G as
with aggiungoDate_costoprod as (
select a.*,b.orderdate, b.duedate, b.shipdate,  b.onlineorderflag,  b.CustomerID, c.StandardCost,b.SalesPersonID, b.TerritoryID
from project.Salesorderdetail_prj as a inner join project.Salesorderheader_prj as b 
on a.SalesOrderID = b.Salesorderid inner join project.productcosthistory_prj as c
on a.productID = c.productID and b.orderdate >= c.StartDate and (b.orderdate < c.EndDate or c.EndDate is null)
)


select *, (linetotal - (StandardCost*OrderQty)) as margine_prodotto_ordine, (cast((linetotal - (StandardCost*OrderQty))*100 as decimal(10,2))/linetotal) as pct_margine_prodotto_ordine
from aggiungoDate_costoprod
WHERE OrderDate >= DATEADD(DAY, -120, CAST(GETDATE() AS date))

;



create or alter view project.KPI_ClientiSegmentati as 

-- per ogni cliente calcolo profitto fatturato e numero ordini su tutto il dataset VIEW_orders_detailPB

with kpi_storico as (

select customerID,
	   sum(margine_prodotto_ordine) as profitto_storico,
	   sum(LineTotal) as fatturato_storico,
	   count(distinct salesorderid)  as numOrdiniStorico
from project.VIEW_orders_detailPB
group by customerID
),

--calcolo percentili per la distribuzione del fatturato storico

percentili as (
select distinct
PERCENTILE_CONT(0.70) within group (order by fatturato_storico) over() as fatt_storicoperc70,
PERCENTILE_CONT(0.30) within group (order by fatturato_storico) over() as fatt_storicoperc30
from kpi_storico 
),

--creo la segmentazione dei clienti in base ai percentili calcolati sul fatturato storico

segmenti_storici as (
select customerid,
profitto_storico,
fatturato_storico,
numOrdiniStorico,
cast((profitto_storico/nullif(fatturato_storico,0)) as decimal(10,2)) as margPercStorico,

case 
		when fatturato_storico > fatt_storicoperc70 then 'Storico TOP'
		when fatturato_storico > fatt_storicoperc30 and fatturato_storico < fatt_storicoperc70 then 'Storico standard'
		else 'Storico base'
		end as livelloStoricoCustomer

from kpi_storico cross join percentili
)
,


--creo kpi su dati della tabella delle vendite dell'ultimo trimestre

kpi_120gg AS (
    SELECT
        CustomerID,

        COUNT(DISTINCT SalesOrderID) AS NumeroOrdini_120G,
        SUM(linetotal) AS Fatturato_120G,
        SUM(margine_prodotto_ordine) AS Profitto_120G,
		
        MAX(OrderDate) AS UltimoAcquisto_120G

    FROM project.VIEW_orders_detailPB_120G
    
    GROUP BY
        CustomerID
),


kpi_finale_120gg AS (
    SELECT
        CustomerID,
        NumeroOrdini_120G,
        Fatturato_120G,
        Profitto_120G,
		

        CAST(
            Profitto_120G / NULLIF(Fatturato_120G, 0)
            AS decimal(10,4)
        ) AS MarginePct_120G,


        UltimoAcquisto_120G,

        DATEDIFF(
            DAY,
            UltimoAcquisto_120G,
            CAST(GETDATE() AS date)
        ) AS GiorniDaUltimoAcquisto_120G
    FROM kpi_120gg
),




segmenti_120gg as (

SELECT
		CustomerID,
		NumeroOrdini_120G,
        Fatturato_120G,
        Profitto_120G,
		GiorniDaUltimoAcquisto_120G,
		MarginePct_120G, 

    CASE
        WHEN GiorniDaUltimoAcquisto_120G BETWEEN 0 AND 30 THEN 'Recente'
        WHEN GiorniDaUltimoAcquisto_120G BETWEEN 31 AND 90 THEN 'Intermedio'
        WHEN GiorniDaUltimoAcquisto_120G BETWEEN 91 AND 120 THEN 'A rischio'
    END AS SegmentoRecency120gg
		
FROM kpi_finale_120gg 

)

--faccio la segmentazione dei clienti creando il loro profilo commerciale in base alla clusterizzazione per il fatturato storico
-- e al loro acquisto più recente in termini temporali

select ks.customerid,
	-- clusterizzazione rispetto al fatturato storico di ogni cliente
	livelloStoricoCustomer,
	
	coalesce(SegmentoRecency120gg , 'Non attivo') as SegmentoRecency120gg	,

	CASE
    WHEN livelloStoricoCustomer = 'Storico TOP'
         AND COALESCE(SegmentoRecency120gg, 'Non attivo') IN ('A rischio', 'Non attivo')
        THEN 'Priorità alta'

    WHEN livelloStoricoCustomer IN ('Storico TOP', 'Storico standard')
         AND COALESCE(Fatturato_120G, 0) > 0
        THEN 'Priorità media'

    ELSE 'Monitoraggio'
END AS AlertCommerciale, 

   CASE
    WHEN livelloStoricoCustomer = 'Storico TOP'
         AND COALESCE(SegmentoRecency120gg, 'Non attivo') IN ('A rischio', 'Non attivo')
        THEN 'Recupero clienti'

    WHEN livelloStoricoCustomer = 'Storico TOP'
         AND COALESCE(SegmentoRecency120gg, 'Non attivo') IN ('Recente', 'Intermedio')
        THEN 'Fidelizzazione premium'

    WHEN livelloStoricoCustomer = 'Storico standard'
         AND COALESCE(Fatturato_120G, 0) > 0
        THEN 'Upsell / cross-sell'

    WHEN livelloStoricoCustomer = 'Storico base'
         AND COALESCE(Fatturato_120G, 0) > 0
        THEN 'Sviluppo clienti emergenti'

    ELSE 'Nessuna iniziativa'
END AS IniziativaSuggerita --(profilo commerciale)


from segmenti_storici as ks left join 
segmenti_120gg as kf 
on ks.customerid  = kf.customerid 
;