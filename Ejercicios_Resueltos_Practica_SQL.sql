--1) Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea
--mayor o igual a $ 1000 ordenado por código de cliente. 

SELECT clie_codigo,clie_razon_social from Cliente where clie_limite_credito >= 1000 order by clie_codigo

--2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados
--por cantidad vendida.

select prod_codigo,prod_detalle
from Producto join Item_Factura on prod_codigo = item_producto 
join Factura on (item_tipo+item_sucursal+item_numero) = (fact_tipo+fact_sucursal+fact_numero)
where year(fact_fecha) = 2012
group by prod_codigo,prod_detalle 
order by sum(item_cantidad) 


 --3. Realizar una consulta que muestre código de producto, nombre de producto y el
--stock total, sin importar en que deposito se encuentre, los datos deben ser ordenados
--por nombre del artículo de menor a mayor. 

select prod_codigo, prod_detalle, sum(stoc_cantidad) cant_stock
from Producto
join stock on prod_codigo = stoc_producto
group by  prod_codigo, prod_detalle
order by prod_detalle


--4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad
--de artículos que lo componen. Mostrar solo aquellos artículos para los cuales el
--stock promedio por depósito sea mayor a 100. 

select  prod_codigo, prod_detalle,count(comp_componente)cant_articulos
from Producto
left join Composicion on prod_codigo = comp_producto
group by prod_codigo, prod_detalle
having prod_codigo in 
(select stoc_producto from STOCK group by stoc_producto  having sum(stoc_cantidad)/count(stoc_deposito) > 100)
order by 3 desc
 
--5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos
--de stock que se realizaron para ese artículo en el año 2012 (egresan los productos
--que fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011. 

select item_producto, prod_detalle, sum(item_cantidad) cant_egresos
from Item_Factura
join Producto on prod_codigo = item_producto
join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
where year(fact_fecha) = 2012
group by item_producto,prod_detalle, prod_codigo 
having sum(item_cantidad) > 
(select sum(item_cantidad) 
from Item_Factura
join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
where item_producto = prod_codigo and  year(fact_fecha) = 2011)

--6. Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese rubro y stock total de ese rubro de artículos. 
--Solo tener en cuenta aquellos artículos que tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’. 

select rubr_id,rubr_detalle,count(distinct prod_codigo) cant_prod_rubro, SUM(stoc_cantidad) cant_prod_rubro
from Rubro
join Producto on rubr_id = prod_rubro
join STOCK on prod_codigo = stoc_producto
group by rubr_id,rubr_detalle 
having SUM(stoc_cantidad) > 
(select stoc_cantidad
from STOCK
where stoc_producto like '00000000' and stoc_deposito like '00')
ORDER BY 1


/*SELECT R.rubr_id, R.rubr_detalle, COUNT(DISTINCT P.prod_codigo) as [Cantidad de Articulos], SUM(S.stoc_cantidad) AS [Stock Total]
FROM Producto P
	INNER JOIN RUBRO R
		ON R.rubr_id = P.prod_rubro
	INNER JOIN STOCK S
		ON S.stoc_producto = P.prod_codigo
	INNER JOIN DEPOSITO D
		ON D.depo_codigo = S.stoc_deposito
WHERE S.stoc_cantidad > (
		SELECT stoc_cantidad
		FROM STOCK
		WHERE stoc_producto = '00000000'
			AND stoc_deposito = '00'
		)
GROUP BY R.rubr_id,R.rubr_detalle
ORDER BY 1*/

--7. Generar una consulta que muestre para cada articulo código, detalle, mayor precio
--menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio
--= 10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que
--posean stock. 

select prod_codigo, prod_detalle, max(item_precio) precio_max , min(item_precio) precio_min, ((max(item_precio) - min(item_precio))*100 /min(item_precio))  porc_dif_precio 
from Producto
join Item_Factura on prod_codigo = item_producto
join STOCK on prod_codigo = stoc_producto
WHERE stoc_cantidad > 0
group by  prod_codigo, prod_detalle 
order by 1
--having sum(stoc_cantidad) > 0      --> ¿xq es con el where y no con el sum?

--8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del
--artículo, stock del depósito que más stock tiene.

select prod_detalle, max(stoc_cantidad) mayor_stock
from Producto
join STOCK on prod_codigo = stoc_producto
group by prod_detalle
having (count(distinct stoc_deposito)) = (SELECT COUNT(depo_codigo)FROM DEPOSITO)
order by prod_detalle


--9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del
--mismo y la cantidad de depósitos que ambos tienen asignados. 

select empl_jefe,empl_codigo,empl_nombre,empl_apellido, count(depo_encargado)  depositos_emp,  (select count(depo_encargado) from deposito where depo_encargado = empl_jefe)
from Empleado
left join DEPOSITO on depo_encargado = empl_codigo
group by empl_codigo,empl_jefe,empl_nombre,empl_apellido

select empl_jefe,empl_codigo,empl_nombre,empl_apellido, count(depo_encargado) + (select count(depo_encargado) from deposito where depo_encargado = empl_jefe) depositos_asignados
from Empleado
left join DEPOSITO on depo_encargado = empl_codigo
group by empl_codigo,empl_jefe,empl_nombre,empl_apellido

--10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos
--menos vendidos en la historia. Además mostrar de esos productos, quien fue el
--cliente que mayor compra realizo.

select prod_detalle from producto where prod_codigo in
(select top 10 item_producto
from Item_Factura
group by item_producto
order by sum(item_cantidad) desc) or prod_codigo in
(select top 10 item_producto
from Item_Factura
group by item_producto 
order by sum(item_cantidad) asc)

--11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
--productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán
--ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga,
--solo se deberán n mostrar las familias que tengan una venta superior a 20000 pesos para el año 2012.
 
 SELECT 
    fami_detalle AS 'Familia', 
    COUNT(DISTINCT prod_codigo) AS 'Productos vendidos',
    SUM(item_precio * item_cantidad) AS 'Monto ventas'
FROM Familia
JOIN Producto ON fami_id = prod_familia
JOIN Item_Factura ON prod_codigo = item_producto
GROUP BY fami_id, fami_detalle
HAVING (SELECT SUM(item_cantidad * item_precio)
FROM Producto
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura ON item_numero + item_tipo + item_sucursal = 
fact_numero + fact_tipo + fact_sucursal
WHERE YEAR(fact_fecha) = 2012 
AND prod_familia = fami_id) > 20000
ORDER BY 2 DESC

--12 Mostrar nombre de producto, cantidad de clientes distintos que lo compraron importe
--promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del
--producto y stock actual del producto en todos los depósitos. Se deberán mostrar
--aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán
--ordenarse de mayor a menor por monto vendido del producto.

SELECT prod_detalle, 
COUNT(DISTINCT fact_cliente) CANT_CLIEs, 
AVG(item_precio) IMPORTE_PROM,
ISNULL((SELECT COUNT(DISTINCT stoc_deposito) FROM STOCK WHERE stoc_producto = prod_codigo AND stoc_cantidad > 0 GROUP BY stoc_producto), 0) AS DEPO_C_STOCK,
ISNULL((SELECT SUM(stoc_cantidad) FROM STOCK WHERE stoc_producto = prod_codigo GROUP BY stoc_producto), 0) AS STOCK_X_DEPO
FROM Producto
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura ON item_numero + item_tipo + item_sucursal = 
fact_numero + fact_tipo + fact_sucursal
WHERE YEAR(fact_fecha) = 2012
GROUP BY prod_detalle, prod_codigo
ORDER BY SUM(item_cantidad) DESC



--13 Realizar una consulta que retorne para cada producto que posea composición nombre
--del producto, precio del producto, precio de la sumatoria de los precios por la cantidad 
--de los productos que lo componen. Solo se deberán mostrar los productos que estén
--compuestos por más de 2 productos y deben ser ordenados de mayor a menor por
--cantidad de productos que lo compone

SELECT 
    P1.prod_detalle AS 'Producto',
    P1.prod_precio AS 'Precio',
    SUM(comp_cantidad * P2.prod_precio) AS 'Precio compuesto'
FROM Producto P1
JOIN Composicion ON P1.prod_codigo = comp_producto
JOIN Producto P2 ON comp_componente = P2.prod_codigo
GROUP BY P1.prod_codigo, P1.prod_detalle, P1.prod_precio
HAVING COUNT(DISTINCT comp_componente) > 2
ORDER BY COUNT(DISTINCT comp_componente) DESC


--14 Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que
--debe retornar son:
--		Código del cliente
--		Cantidad de veces que compro en el último año
--		Promedio por compra en el último año
--		Cantidad de productos diferentes que compro en el último año
--Monto de la mayor compra que realizo en el último año
--Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en
--el último año.
--No se deberán visualizar NULLs en ninguna columna

SELECT clie_codigo,
ISNULL(COUNT(fact_cliente),0) CANT_COMPRAS,
ISNULL(AVG(fact_total),0) PROM_X_COMPRA,
(SELECT COUNT(DISTINCT item_producto) FROM Item_Factura JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura) AND clie_codigo = fact_cliente GROUP BY fact_cliente) CANT_PROD_DIF,
MAX(fact_total) MAYOR_COMPRA
FROM Cliente 
JOIN Factura ON clie_codigo = fact_cliente 
WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura) 
GROUP BY clie_codigo
UNION
(SELECT clie_codigo, 0, 0, 0, 0 FROM Cliente
WHERE NOT EXISTS 
(SELECT fact_cliente FROM Factura 
WHERE fact_cliente = clie_codigo
AND YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)))
ORDER BY 2 DESC


--15) Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos
--(en la misma factura) más de 500 veces. El resultado debe mostrar el código y
--descripción de cada uno de los productos y la cantidad de veces que fueron vendidos
--juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron
--juntos dichos productos. Los distintos pares no deben retornarse más de una vez.

--Ejemplo de lo que retornaría la consulta:
--PROD1 DETALLE1 PROD2 DETALLE2 VECES
--1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7
--1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2

SELECT P1.prod_codigo,P1.prod_detalle,P2.prod_codigo,P2.prod_detalle, COUNT(*) CANT_VENTAS_JUNTOS
FROM Item_Factura I1 JOIN Producto P1 ON I1.item_producto = P1.prod_codigo,
Item_Factura I2 JOIN Producto P2 ON I2.item_producto = P2.prod_codigo
WHERE I1.item_tipo+I1.item_sucursal+I1.item_numero = I2.item_tipo+I2.item_sucursal+I2.item_numero
AND P1.prod_codigo > P2.prod_codigo  --> es para que no devuelva repetidos es decir X con Y e Y con X
GROUP BY P1.prod_codigo,P1.prod_detalle,P2.prod_codigo,P2.prod_detalle
HAVING COUNT(*) > 500


/* 16. Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran
en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas ventas son
inferiores a 1/3 del promedio de ventas del producto que más se vendió en el 2012.
Además mostrar
1. Nombre del Cliente
2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
mostrar solamente el de menor código) para ese cliente.
Aclaraciones:
La composición es de 2 niveles, es decir, un producto compuesto solo se compone de
productos no compuestos.
Los clientes deben ser ordenados por código de provincia ascendente.*/

SELECT clie_razon_social, ISNULL(SUM(item_cantidad), 0) CANT_UNID_COMPRADAS
,(SELECT TOP 1 I1.item_producto FROM Item_Factura I1 JOIN Factura F1
	ON F1.fact_tipo+F1.fact_sucursal+F1.fact_numero = I1.item_tipo+I1.item_sucursal+I1.item_numero 
	WHERE YEAR(F1.fact_fecha) = 2012 AND clie_codigo = F1.fact_cliente GROUP BY I1.item_producto
	ORDER BY SUM(I1.item_cantidad), 1 ASC) PROD_MAS_COMPRADO
FROM Cliente
JOIN Factura ON clie_codigo = fact_cliente
JOIN Item_Factura ON fact_numero + fact_sucursal + fact_tipo = 
item_numero + item_sucursal + item_tipo
WHERE YEAR(fact_fecha) = 2012
GROUP BY clie_codigo,clie_razon_social
HAVING SUM(item_cantidad) < 
	((SELECT TOP 1 SUM(i2.item_cantidad) 
		FROM Item_Factura i2 JOIN Factura F2
	ON F2.fact_tipo+F2.fact_sucursal+F2.fact_numero = I2.item_tipo+I2.item_sucursal+I2.item_numero 
	WHERE YEAR(F2.fact_fecha) = 2012 
	GROUP BY i2.item_producto
	ORDER BY SUM(i2.item_cantidad) DESC)/3)


/*
17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
producto.
La consulta debe retornar:
PERIODO: Año y mes de la estadística con el formato YYYYMM
PROD: Código de producto
DETALLE: Detalle del producto
CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo
pero del año anterior
CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
periodo
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
por periodo y código de producto.
*/
SELECT 
	CONCAT(YEAR(F1.fact_fecha), RIGHT('0' + RTRIM(MONTH(F1.fact_fecha)), 2)),
	prod_codigo PROD, 
	ISNULL(prod_detalle,'Sin detalle') DETALLE,
	ISNULL(SUM(item_cantidad),0) CANTIDAD_VENDIDA,
	ISNULL((SELECT SUM(item_cantidad)
	FROM Item_Factura I2 JOIN Factura F2 ON F2.fact_numero + F2.fact_sucursal + F2.fact_tipo = I2.item_numero + I2.item_sucursal + I2.item_tipo
	WHERE I2.item_numero = prod_codigo AND YEAR(F2.fact_fecha) = (YEAR(F1.fact_fecha)-1) AND MONTH(F2.fact_fecha) = MONTH(F1.fact_fecha)),0) VENTAS_AÑO_ANT,
	ISNULL(COUNT(*) , 0) CANT_FACTURAS
FROM Producto
JOIN Item_Factura ON  prod_codigo = item_producto 
JOIN Factura F1 ON item_numero + item_sucursal + item_tipo = F1.fact_numero + F1.fact_sucursal + F1.fact_tipo 
GROUP BY prod_codigo,prod_detalle,YEAR(F1.fact_fecha),MONTH(F1.fact_fecha)
ORDER BY 2


/*
18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
La consulta debe retornar:
DETALLE_RUBRO: Detalle del rubro
VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
PROD1: Código del producto más vendido de dicho rubro
PROD2: Código del segundo producto más vendido de dicho rubro
CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30
días
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
por cantidad de productos diferentes vendidos del rubro.
*/

SELECT 
	ISNULL(rubr_detalle,'Sin detalle') DETALLE_RUBRO,
	ISNULL(SUM(item_cantidad * item_precio),0) VENTAS,
	ISNULL((SELECT TOP 1 I1.item_producto FROM Item_Factura I1 
		JOIN Producto P1 ON I1.item_producto = P1.prod_codigo
		WHERE P1.prod_rubro = rubr_id
		GROUP BY I1.item_producto
		ORDER BY SUM(I1.item_cantidad) DESC),0) PROD1,
	ISNULL((SELECT TOP 1 I2.item_producto FROM Item_Factura I2
		JOIN Producto P2 ON I2.item_producto = P2.prod_codigo
		WHERE P2.prod_rubro = rubr_id AND I2.item_producto
		NOT IN 
			(SELECT TOP 1 I3.item_producto FROM Producto P3
			JOIN Item_Factura I3 ON P3.prod_codigo = I3.item_producto
			WHERE P3.prod_rubro = rubr_id
			GROUP BY I3.item_producto
			ORDER BY SUM(I3.item_cantidad) DESC) 
		GROUP BY I2.item_producto
		ORDER BY SUM(I2.item_cantidad) DESC), 0) PROD2,
	ISNULL((SELECT TOP 1 fact_cliente
			FROM Factura 
			JOIN Item_Factura I4
			ON I4.item_numero + I4.item_sucursal + I4.item_tipo = fact_numero + fact_sucursal + fact_tipo 
			JOIN Producto P4 ON P4.prod_codigo = I4.item_producto
			WHERE fact_fecha >(SELECT DATEADD(DAY, -30, MAX(fact_fecha)) FROM Factura) AND P4.prod_rubro = rubr_id
			GROUP BY fact_cliente
			ORDER BY SUM(I4.item_cantidad) DESC),'---') CLIENTE
FROM Rubro LEFT JOIN Producto ON rubr_id = prod_rubro
LEFT JOIN Item_Factura ON prod_codigo = item_producto
GROUP BY rubr_detalle,rubr_id  
ORDER BY COUNT(DISTINCT prod_codigo)

 /*
 19. En virtud de una recategorizacion de productos referida a la familia de los mismos se
solicita que desarrolle una consulta sql que retorne para todos los productos:
 Codigo de producto
 Detalle del producto
 Codigo de la familia del producto
 Detalle de la familia actual del producto
 Codigo de la familia sugerido para el producto
 Detalla de la familia sugerido para el producto
La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo
detalle coinciden en los primeros 5 caracteres.
En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor
codigo. Solo se deben mostrar los productos para los cuales la familia actual sea
diferente a la sugerida
Los resultados deben ser ordenados por detalle de producto de manera ascendente
 */
 --Corregir porq no da como el del drive, algo esta mal
 SELECT P.prod_codigo,
		P.prod_detalle,
		F.fami_id, 
		F.fami_detalle,
		(SELECT TOP 1 fami_id FROM Familia
			WHERE LEFT(fami_detalle,5)=LEFT(prod_detalle,5)  
			GROUP BY fami_id
			ORDER BY COUNT(fami_id) DESC,fami_id ASC) FAM_ID_REC,
		(SELECT TOP 1 fami_detalle FROM Familia
			WHERE LEFT(fami_detalle,5)=LEFT(prod_detalle,5)  
			GROUP BY fami_id,fami_detalle
			ORDER BY COUNT(fami_id) DESC,fami_id ASC)FAM_DET_REC
FROM Producto P JOIN Familia F ON P.prod_familia = F.fami_id
WHERE fami_detalle <> (SELECT TOP 1 fami_detalle FROM Familia
			WHERE LEFT(fami_detalle,5)=LEFT(prod_detalle,5)  
			GROUP BY fami_id,fami_detalle
			ORDER BY COUNT(fami_id) DESC,fami_id ASC)
ORDER BY 2 
/*
20. Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012
Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje
2012. El puntaje de cada empleado se calculara de la siguiente manera: para los que
hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas
que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50
facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas
por sus subordinados directos en dicho año
*/
 
SELECT TOP 3 E.empl_codigo legajo, E.empl_nombre, E.empl_apellido, E.empl_ingreso,
	CASE 
		WHEN(
				SELECT COUNT(fact_vendedor) 
				FROM Factura
				WHERE YEAR(fact_fecha) = 2012 AND fact_vendedor = E.empl_codigo	
			) >50
		THEN(
				SELECT COUNT(fact_vendedor) 
				FROM Factura
				WHERE YEAR(fact_fecha) = 2011 AND fact_vendedor = E.empl_codigo AND fact_total > 100
			)
		ELSE(
				SELECT COUNT(fact_vendedor) * 0.5
				FROM Factura
				WHERE YEAR(fact_fecha) = 2011 AND fact_vendedor IN (SELECT empl_codigo FROM Empleado WHERE empl_jefe = E.empl_jefe)
			)
	END punt_2011,
	CASE 
		WHEN(
				SELECT COUNT(fact_vendedor) 
				FROM Factura
				WHERE YEAR(fact_fecha) = 2012 AND fact_vendedor = E.empl_codigo	
			) >50
		THEN(
				SELECT COUNT(fact_vendedor) 
				FROM Factura
				WHERE YEAR(fact_fecha) = 2012 AND fact_vendedor = E.empl_codigo AND fact_total > 100
			)
		ELSE(
				SELECT COUNT(fact_vendedor) * 0.5
				FROM Factura
				WHERE YEAR(fact_fecha) = 2012 AND fact_vendedor IN (SELECT empl_codigo FROM Empleado WHERE empl_jefe = E.empl_jefe)
			)
	END punt_2012
FROM Empleado E
ORDER BY 6 desc

/*
21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al
menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta 
al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se
considera que una factura es incorrecta cuando la diferencia entre el total de la factura
menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de
los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar
son:
 Año
 Clientes a los que se les facturo mal en ese año
 Facturas mal realizadas en ese año
*/

SELECT YEAR(fact_fecha) ANIO, COUNT(DISTINCT fact_cliente) CANT_CLIENTES_MAL_FACT , COUNT(*) CANT_FAC_ERROR
FROM Factura 
WHERE (fact_total - fact_total_impuestos - 
		(SELECT SUM(item_cantidad * item_precio) FROM Item_Factura 
		WHERE fact_numero + fact_sucursal + fact_tipo = item_numero + item_sucursal + item_tipo))
		> 1	
GROUP BY YEAR(fact_fecha)

/*
22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por
trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1
por cada trimestre).
Se deben mostrar 4 columnas:
 Detalle del rubro
 Numero de trimestre del año (1 a 4)
 Cantidad de facturas emitidas en el trimestre en las que se haya vendido al
menos un producto del rubro
 Cantidad de productos diferentes del rubro vendidos en el trimestre
El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada
rubro primero el trimestre en el que mas facturas se emitieron.
No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas
no superen las 100.
En ningun momento se tendran en cuenta los productos compuestos para esta
estadistica.
*/

SELECT  rubr_detalle, YEAR(fact_fecha),
		DATEPART(QUARTER, fact_fecha) TRIMESTRE ,
		COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) CANT_FACT,
		COUNT(DISTINCT prod_codigo) CANT_PROD_DIF
FROM Rubro JOIN Producto ON rubr_id = prod_rubro
		   JOIN Item_Factura ON item_producto = prod_codigo
		   JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE prod_codigo NOT IN (SELECT comp_producto FROM Composicion)
GROUP BY rubr_detalle, DATEPART(QUARTER, fact_fecha),YEAR(fact_fecha)
HAVING COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) > 100
ORDER BY 1, COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) DESC

/*
23. Realizar una consulta SQL que para cada año muestre :
 Año
 El producto con composición más vendido para ese año.
 Cantidad de productos que componen directamente al producto más vendido
 La cantidad de facturas en las cuales aparece ese producto.
 El código de cliente que más compro ese producto.
 El porcentaje que representa la venta de ese producto respecto al total de venta
del año.
El resultado deberá ser ordenado por el total vendido por año en forma descendente.
*/

 SELECT YEAR(fact_fecha), 
		item_producto ITEM_MAS_VENDIDO, 
		(SELECT COUNT(*) FROM Composicion WHERE comp_producto = item_producto) CANT_COMPONENTES,
		COUNT(DISTINCT  fact_tipo + fact_sucursal + fact_numero) CANT_FACTURAS,
		(SELECT TOP 1 F2.fact_cliente FROM Factura F2 JOIN Item_Factura I2
			 ON  F2.fact_tipo + F2.fact_sucursal + F2.fact_numero =   I2.item_tipo + I2.item_sucursal + I2.item_numero
			 WHERE I2.item_producto = item_producto AND YEAR(F2.fact_fecha) = YEAR(fact_fecha)
			 GROUP BY fact_cliente
			 ORDER BY SUM(item_cantidad) DESC) CLIENTE_Q_MAS_COMPRO,
			 SUM(item_cantidad * item_precio) / 
			 (SELECT SUM(I3.item_cantidad * I3.item_precio) FROM Item_Factura I3 JOIN Factura F3 
			  ON F3.fact_tipo + F3.fact_sucursal + F3.fact_numero =   I3.item_tipo + I3.item_sucursal + I3.item_numero
			  WHERE  YEAR(fact_fecha) =  YEAR(F3.fact_fecha))*100 PORCENTAJE
 FROM Factura JOIN Item_Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
 WHERE item_producto = (SELECT TOP 1 item_producto FROM Item_Factura I4
							   JOIN Factura F4
							     ON F4.fact_tipo + F4.fact_sucursal + F4.fact_numero = I4.item_tipo + I4.item_sucursal + I4.item_numero
							 WHERE YEAR(fact_fecha) = YEAR(F4.fact_fecha)
							 GROUP BY item_producto
							 ORDER BY SUM(item_cantidad) DESC) 
 AND item_producto IN (SELECT comp_producto FROM Composicion)
 GROUP BY YEAR(fact_fecha),item_producto
 ORDER BY SUM(item_cantidad * item_precio) DESC


  SELECT YEAR(fact_fecha),
item_producto ITEM_MAS_VENDIDO,
(SELECT COUNT(*) FROM Composicion WHERE comp_producto = item_producto) CANT_COMPONENTES,
COUNT(DISTINCT  fact_tipo + fact_sucursal + fact_numero) CANT_FACTURAS,
(SELECT TOP 1 F2.fact_cliente FROM Factura F2 JOIN Item_Factura I2
ON  F2.fact_tipo + F2.fact_sucursal + F2.fact_numero =   I2.item_tipo + I2.item_sucursal + I2.item_numero
WHERE I2.item_producto = item_producto AND YEAR(F2.fact_fecha) = YEAR(fact_fecha)
GROUP BY fact_cliente
ORDER BY SUM(item_cantidad) DESC) CLIENTE_Q_MAS_COMPRO,
SUM(item_cantidad * item_precio) /
(SELECT SUM(I3.item_cantidad * I3.item_precio) FROM Item_Factura I3 JOIN Factura F3
 ON F3.fact_tipo + F3.fact_sucursal + F3.fact_numero =   I3.item_tipo + I3.item_sucursal + I3.item_numero
 WHERE  YEAR(fact_fecha) =  YEAR(F3.fact_fecha))*100 PORCENTAJE
 FROM Factura JOIN Item_Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
 WHERE item_producto = (SELECT TOP 1 item_producto FROM Item_Factura I4
  JOIN Composicion
    ON I4.item_producto = comp_producto
  JOIN Factura F4
    ON F4.fact_tipo + F4.fact_sucursal + F4.fact_numero = I4.item_tipo + I4.item_sucursal + I4.item_numero
WHERE YEAR(fact_fecha) = YEAR(F4.fact_fecha)
GROUP BY item_producto
ORDER BY SUM(item_cantidad) DESC)
 GROUP BY YEAR(fact_fecha),item_producto
 ORDER BY SUM(item_cantidad * item_precio) DESC
 /*
 24. Escriba una consulta que considerando solamente las facturas correspondientes a los
dos vendedores con mayores comisiones, retorne los productos con composición
facturados al menos en cinco facturas,
La consulta debe retornar las siguientes columnas:
 Código de Producto
 Nombre del Producto
 Unidades facturadas
El resultado deberá ser ordenado por las unidades facturadas descendente.
 */

SELECT prod_codigo, prod_detalle, SUM(item_cantidad)UNID_FACT FROM Producto 
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE fact_vendedor IN (SELECT TOP 2 empl_codigo FROM Empleado ORDER BY empl_comision DESC)
AND prod_codigo IN (SELECT comp_producto FROM Composicion)
GROUP BY prod_codigo,prod_detalle
HAVING COUNT(DISTINCT item_tipo + item_sucursal + item_numero) > 5
ORDER BY  SUM(item_cantidad) DESC

/*
25. Realizar una consulta SQL que para cada año y familia muestre :
a. Año
b. El código de la familia más vendida en ese año.
c. Cantidad de Rubros que componen esa familia.
d. Cantidad de productos que componen directamente al producto más vendido de
esa familia.
e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa
familia.
f. El código de cliente que más compro productos de esa familia.
g. El porcentaje que representa la venta de esa familia respecto al total de venta
del año.
El resultado deberá ser ordenado por el total vendido por año y familia en forma
descendente.
*/

--preguntar

/*
26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las
siguientes columnas:
 Empleado
 Depósitos que tiene a cargo
 Monto total facturado en el año corriente
 Codigo de Cliente al que mas le vendió
 Producto más vendido
 Porcentaje de la venta de ese empleado sobre el total vendido ese año.
Los datos deberan ser ordenados por venta del empleado de mayor a menor
*/
SELECT empl_codigo, (SELECT COUNT(depo_codigo) FROM Deposito WHERE depo_encargado = empl_codigo ) CANT_DEPOS, 
	sum(fact_total) TOTAL_FACTURADO,-- (SELECT SUM(fact_total) FROM Factura WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = YEAR(F.fact_fecha)) TOTAL_FACTURADO,
	(SELECT TOP 1 fact_cliente FROM Factura WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = YEAR(F.fact_fecha) 
		GROUP BY fact_cliente ORDER BY SUM(fact_total) DESC) MEJOR_CLIENTE,
	(SELECT TOP 1 item_producto FROM Item_Factura JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
		WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = YEAR(F.fact_fecha) GROUP BY item_producto ORDER BY SUM(item_cantidad) DESC) BEST_SELLER,
	SUM(fact_total) *100  / (select sum(fact_total) from Factura where year(fact_fecha) = YEAR(F.fact_fecha)) PORC_VENTA_EMP
 FROM Empleado LEFT JOIN Factura F ON F.fact_vendedor = empl_codigo
 WHERE YEAR(F.fact_fecha) = 2012
 GROUP BY empl_nombre, empl_apellido,empl_codigo , YEAR(F.fact_fecha)
 ORDER BY 3 DESC

 /*
 27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y
envase devolviendo las siguientes columnas:
 Año
 Codigo de envase
 Detalle del envase
 Cantidad de productos que tienen ese envase
 Cantidad de productos facturados de ese envase
 Producto mas vendido de ese envase
 Monto total de venta de ese envase en ese año
 Porcentaje de la venta de ese envase respecto al total vendido de ese año
Los datos deberan ser ordenados por año y dentro del año por el envase con más
facturación de mayor a menor
 */

 SELECT YEAR(fact_fecha) AÑO ,enva_codigo, enva_detalle,
  COUNT(DISTINCT prod_codigo) CANT_PROD_ENV, SUM(item_cantidad) CANT_PROD_FACT_ENV,
  (SELECT TOP 1 I1.item_producto FROM Item_Factura I1 JOIN Producto P1 ON
		P1.prod_codigo = I1.item_producto JOIN Factura F1   
		ON F1.fact_tipo + F1.fact_sucursal + F1.fact_numero = I1.item_tipo + I1.item_sucursal + I1.item_numero
		WHERE P1.prod_envase = enva_codigo AND YEAR(F1.fact_fecha) = YEAR(fact_fecha) GROUP BY I1.item_producto ORDER BY SUM(I1.item_cantidad) DESC) PROD_MAS_VEND_ENV,
  SUM(item_cantidad * item_precio) TOTAL_VENT_ENV,
  (SUM(item_cantidad * item_precio) * 100 / (select sum(fact_total) from Factura where year(fact_fecha) = YEAR(F.fact_fecha))) PORC_VENT_ENV
FROM Producto P
JOIN Envases E
ON E.enva_codigo = P.prod_envase
JOIN Item_Factura I1
ON I1.item_producto = P.prod_codigo
JOIN Factura F
ON F.fact_numero = I1.item_numero AND F.fact_sucursal = I1.item_sucursal AND F.fact_tipo = I1.item_tipo
GROUP BY YEAR(fact_fecha),enva_codigo, enva_detalle
ORDER BY 1, 7 DESC

/*
28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
siguientes columnas:
 Año.
 Codigo de Vendedor
 Detalle del Vendedor
 Cantidad de facturas que realizó en ese año
 Cantidad de clientes a los cuales les vendió en ese año.
 Cantidad de productos facturados con composición en ese año
 Cantidad de productos facturados sin composicion en ese año.
 Monto total vendido por ese vendedor en ese año
Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
vendido mas productos diferentes de mayor a menor.
*/
--Mi version
SELECT YEAR(fact_fecha) AÑO, empl_codigo, empl_nombre, empl_apellido,
COUNT(*) CANT_FACT, COUNT(DISTINCT fact_cliente) CANT_CLIENTES,
(SELECT COUNT(DISTINCT I1.item_producto) FROM Item_Factura I1 JOIN Factura F1 ON
	F1.fact_tipo + F1.fact_sucursal + F1.fact_numero = I1.item_tipo + I1.item_sucursal + I1.item_numero
	WHERE YEAR(fact_fecha) = YEAR(F1.fact_fecha) AND  F1.fact_vendedor = empl_codigo
	AND item_producto IN (select comp_producto FROM Composicion)) CANT_PROD_COMP,
(SELECT COUNT(DISTINCT I2.item_producto) FROM Item_Factura I2 JOIN Factura F2 ON
	F2.fact_tipo + F2.fact_sucursal + F2.fact_numero = I2.item_tipo + I2.item_sucursal + I2.item_numero
	WHERE YEAR(fact_fecha) = YEAR(F2.fact_fecha) AND  F2.fact_vendedor = empl_codigo
	AND item_producto NOT IN (select comp_producto FROM Composicion)) CANT_PROD_NO_COMP,
SUM(fact_total) MONTO_TOTAL
FROM Empleado JOIN Factura ON empl_codigo = fact_vendedor
GROUP BY YEAR(fact_fecha), empl_codigo, empl_nombre, empl_apellido
ORDER BY 1

--Esta bien mi version, faltaria agregar un subselect para el 2do order by 



/*
29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para
los productos que pertenezcan a las familias que tengan más de 20 productos asignados
a ellas, la cual deberá devolver las siguientes columnas:
a. Código de producto
b. Descripción del producto
c. Cantidad vendida
d. Cantidad de facturas en la que esta ese producto
e. Monto total facturado de ese producto
Solo se deberá mostrar un producto por fila en función a los considerandos establecidos
antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.
*/

SELECT prod_codigo PROD_COD,prod_detalle PROD_DETALLE, SUM(item_cantidad) CANT_VEND,
COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) CANT_FACT_DEL_PROD, SUM(item_cantidad * item_precio) TOTAL_FACT
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto JOIN Factura 
ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE YEAR(fact_fecha) = 2011 AND prod_familia IN (SELECT prod_familia FROM producto GROUP BY prod_familia HAVING COUNT(*) > 20)
GROUP BY prod_codigo ,prod_detalle
ORDER BY 3 DESC


/*
30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean
jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la
consulta que retorne las siguientes columnas:
 Nombre del Jefe
 Cantidad de empleados a cargo
 Monto total vendido de los empleados a cargo
 Cantidad de facturas realizadas por los empleados a cargo
 Nombre del empleado con mejor ventas de ese jefe
Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese
necesario.
Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se
deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.
*/

SELECT E2.empl_nombre, E2.empl_apellido, COUNT(DISTINCT E1.empl_codigo) CANT_SUBORDINADOS_A_CARGO,
SUM(fact_total) VENTAS_SUBORDINADOS_A_CARGO, COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) CANT_FACT_SUBORDINADOS,
(SELECT TOP 1 E3.empl_nombre FROM Empleado E3 JOIN Factura F3 ON E3.empl_codigo = F3.fact_vendedor 
	WHERE E3.empl_jefe = E2.empl_codigo
	GROUP BY E3.empl_nombre,E3.empl_codigo ORDER BY SUM(fact_total) DESC) SUBORDINADO_CON_MAS_VENTAS
FROM Empleado E1 LEFT JOIN Factura 
ON empl_codigo = fact_vendedor JOIN Empleado E2 ON E1.empl_jefe = E2.empl_codigo
WHERE YEAR(fact_fecha) = 2012   
GROUP BY E2.empl_nombre, E2.empl_apellido, E2.empl_codigo
HAVING COUNT(fact_tipo + fact_sucursal + fact_numero) > 10
ORDER BY 4 DESC

/*
31.  -- Es identico al 28
*/

/*
32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas
facturas para ello se solicita que escriba una consulta sql que retorne los pares de
familias que tienen productos que se facturaron juntos. Para ellos deberá devolver las
siguientes columnas:
 Código de familia
 Detalle de familia
 Código de familia
 Detalle de familia
 Cantidad de facturas
 Total vendido
Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias
que se vendieron juntas más de 10 veces.
*/

SELECT F1.fami_id, F1.fami_detalle, F2.fami_id, F2.fami_detalle, 
	COUNT(DISTINCT I2.item_tipo + I2.item_sucursal + I2.item_numero)CANT_FACTURAS,
	SUM(I1.item_cantidad * I1.item_precio + I2.item_cantidad * I2.item_precio) TOTAL_VENDIDO
FROM Familia F1 JOIN Producto P1 ON F1.fami_id = P1.prod_familia JOIN Item_Factura I1 ON I1.item_producto = P1.prod_codigo,
Familia F2 JOIN Producto P2 ON F2.fami_id = P2.prod_familia JOIN Item_Factura I2 ON I2.item_producto = P2.prod_codigo
WHERE F1.fami_id < F2.fami_id 
AND (I2.item_tipo + I2.item_sucursal + I2.item_numero) = (I1.item_tipo + I1.item_sucursal + I1.item_numero)
GROUP BY F1.fami_id, F1.fami_detalle , F2.fami_id, F2.fami_detalle
HAVING COUNT(DISTINCT I2.item_tipo + I2.item_sucursal + I2.item_numero) > 10
ORDER BY 6

/*
33. Se requiere obtener una estadística de venta de productos que sean componentes. Para
ello se solicita que realiza la siguiente consulta que retorne la venta de los
componentes del producto más vendido del año 2012. Se deberá mostrar:
a. Código de producto
b. Nombre del producto
c. Cantidad de unidades vendidas
d. Cantidad de facturas en la cual se facturo
e. Precio promedio facturado de ese producto.
f. Total facturado para ese producto
El resultado deberá ser ordenado por el total vendido por producto para el año 2012.
*/


SELECT prod_codigo,prod_detalle, SUM(item_cantidad) CANT_VENDIDA,
	   COUNT(DISTINCT item_tipo + item_sucursal + item_numero) CANT_FACTURAS,
	   AVG(item_precio) PRECIO_PROMEDIO,
	   SUM(item_precio * item_cantidad) TOTAL_FACTURADO  	 
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto JOIN Factura 
ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE prod_codigo IN (SELECT comp_componente FROM Composicion WHERE comp_producto = 
			(SELECT TOP 1 item_producto FROM Item_Factura
			JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
			WHERE YEAR(fact_fecha) = 2012 AND item_producto IN (SELECT comp_producto FROM Composicion)
			GROUP BY item_producto
			ORDER BY SUM(item_cantidad))) 
AND YEAR(fact_fecha) = 2012
GROUP BY prod_codigo,prod_detalle
ORDER BY 6


/*
34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal
facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando
en la misma factura se factutan productos de dos rubros diferentes. Si no hay facturas
mal hechas se debe retornar 0. Las columnas que se deben mostrar son:
1- Codigo de Rubro
2- Mes
3- Cantidad de facturas mal realizadas.
*/

 SELECT P1.prod_rubro RUBRO, MONTH(F1.fact_fecha) MES ,
 CASE WHEN  
	(SELECT COUNT(DISTINCT prod_rubro) FROM Producto JOIN Item_Factura  ON item_producto = prod_codigo
		 WHERE item_tipo + item_sucursal + item_numero	= F1.fact_tipo + F1.fact_sucursal + F1.fact_numero
		 GROUP BY  item_tipo + item_sucursal + item_numero	) > 1
	 THEN (SELECT COUNT(DISTINCT prod_rubro) FROM Producto JOIN Item_Factura  ON item_producto = prod_codigo
		 WHERE item_tipo + item_sucursal + item_numero	= F1.fact_tipo + F1.fact_sucursal + F1.fact_numero
		 GROUP BY  item_tipo + item_sucursal + item_numero	)
	 ELSE 0
	 END FAC_MAL_REALIZADAS
 FROM Producto P1 JOIN Item_Factura I1 ON I1.item_producto = P1.prod_codigo 
 JOIN Factura F1 ON F1.fact_tipo + F1.fact_sucursal + F1.fact_numero = I1.item_tipo + I1.item_sucursal + I1.item_numero
 WHERE YEAR(F1.fact_fecha) = 2011
 GROUP BY P1.prod_rubro, MONTH(F1.fact_fecha),F1.fact_tipo + F1.fact_sucursal + F1.fact_numero
 ORDER BY 3 

  
/*
35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita
que escriba una consulta sql que retorne las siguientes columnas:
 Año
 Codigo de producto
 Detalle del producto
 Cantidad de facturas emitidas a ese producto ese año
 Cantidad de vendedores diferentes que compraron ese producto ese año.
 Cantidad de productos a los cuales compone ese producto, si no compone a ninguno
se debera retornar 0.
 Porcentaje de la venta de ese producto respecto a la venta total de ese año.
Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida.
*/

SELECT YEAR(f1.fact_fecha), prod_codigo, prod_detalle,
	   COUNT(DISTINCT fact_tipo+fact_sucursal+fact_numero) CANT_FACTURAS,
	   COUNT(DISTINCT fact_vendedor) CANT_VENDEDORES,
	   ISNULL((SELECT COUNT(comp_componente) FROM Composicion WHERE comp_producto = prod_codigo) ,0) CANT_COMPONENTES,
	   SUM(item_cantidad * item_precio) * 100 / 
	   (SELECT SUM(item_precio * item_cantidad) FROM Item_Factura JOIN Factura 
	    ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero 
		WHERE YEAR(f1.fact_fecha) =  YEAR(fact_fecha)) PORCENTAJE_VENTA
FROM Producto JOIN Item_Factura ON item_producto = prod_codigo 
JOIN Factura f1 ON f1.fact_tipo + f1.fact_sucursal + f1.fact_numero = item_tipo + item_sucursal + item_numero
GROUP BY YEAR(f1.fact_fecha), prod_codigo, prod_detalle
ORDER BY 1, SUM(item_cantidad)  DESC
 

/*
(SELECT COUNT(DISTINCT fact_cliente) FROM Factura join Item_Factura  
			ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
			where YEAR(f1.fact_fecha) = YEAR(fact_fecha) and item_producto = prod_codigo
			GROUP BY fact_tipo + fact_sucursal + fact_numero,fact_cliente,item_producto )	
*/


