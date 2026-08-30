
use AdventureWorks2022;


create table project.ProductCategory_prj (
productcategoryID int primary key  not null,
Name nvarchar(50) not null
		);


create table project.ProductSubCategory_prj (
productsubcategoryID int primary key  not null,
productcategoryID int  not null,
Name nvarchar(50) not null,
	constraint fk_SubCategory_category_prj
		foreign key (productcategoryID)
		references project.ProductCategory_prj (productcategoryID)
		);


		alter table project.Product_prj 
		add  SafetyStockLevel int not null default 0,
ReorderPoint int not null default 0,
StandardCost money not null default 0;


create table project.Product_prj (
ProductID int primary key  not null,
Name nvarchar(50) not null,
Daystomanufacture int not null,
productsubcategoryID int null,

	constraint fk_product_subcat_prj
		foreign key (productsubcategoryID)
		references project.ProductSubCategory_prj (productsubcategoryID)
);


create table project.Territory_prj (
TerritoryID int primary key not null,
Name nvarchar(50) not null,
[Group] nvarchar(50) not null
);

drop table project.SalesPerson_prj;

create table project.SalesPerson_prj (
BusinessEntityID int primary key not null,
TerritoryID int null,
commissionPCT smallmoney not null,

	constraint fk_salesperson_territory_prj
		foreign key (TerritoryID)
		references project.Territory_prj (TerritoryID)
		);
			   

create table project.Store_prj (
BusinessEntityID int primary key not null,
Name nvarchar(50) not null,
SalesPersonID  int not null,

	constraint fk_store_salesperson_prj
		foreign key (SalesPersonID)
		references project.SalesPerson_prj (BusinessEntityID)
		);



create table project.customer_prj (
CustomerID int primary key not null,
StoreID int  null,
TerritoryID int  null,
	
	constraint fk_customer_store_prj
		foreign key (StoreID)
		references project.Store_prj(BusinessEntityID),

	constraint fk_customer_territory_prj
		foreign key (TerritoryID)
		references project.Territory_prj (TerritoryID)		
)
;

drop table project.Salesorderheader_prj;
 
create table project.Salesorderheader_prj (
Salesorderid  int primary key not null,
orderdate date not null,
duedate date not null,
shipdate date not null,
onlineorderflag bit not null,
CustomerID int  null,
SalesPersonID int  null,
TerritoryID int  null,
subtotal money not null

		
		constraint fk_header_customerID_prj
			foreign key (CustomerID)
			references project.customer_prj(CustomerID),

		constraint fk_header_SalesPersonID_prj
			foreign key (SalesPersonID)
			references project.SalesPerson_prj(BusinessEntityID),

		constraint fk_header_TerritoryID_prj
			foreign key (TerritoryID)
			references project.Territory_prj (TerritoryID)
		
		);


drop table project.Salesorderdetail_prj ;
create table project.Salesorderdetail_prj (
SalesorderdetailID int primary key  not null,
SalesOrderID int not null,
OrderQty smallint not null,
ProductID  int not null,
UnitPrice money not null,
LineTotal money not null,
UnitPriceDiscount money not null,
SpecialOfferID int not null

	constraint fk_orderdetail_orderID_prj
		foreign key (SalesOrderID)
		references project.Salesorderheader_prj (SalesOrderID),
	constraint fk_orderdetail_productID_prj
		foreign key (ProductID)
		references project.Product_prj(ProductID)
);


create table anomalie (
ID INT IDENTITY(1,1) PRIMARY KEY,
Salesorderid  int not null,
OrderDateOriginale date  null,
TipoAnomalia varchar(30) not null,
DataControllo date not null
);



drop table project.detail_anomalie_prj ;
create table project.detail_anomalie_prj (
SalesorderdetailID int primary key  not null,
SalesOrderID int not null,
orderdate date not null,
duedate date not null,
shipdate date not null,
OrderQty smallint not null,
ProductID  int not null,
UnitPrice money not null,
LineTotal numeric (38,6) not null,
TipoAnomalia varchar(30) not null,
DataControllo date not null
);

drop table project.productcosthistory_prj;

select *
into project.productcosthistory_prj
from Production.ProductCostHistory;

