/*
1. Hacer una función que dado un artículo y un deposito devuelva un string que
indique el estado del depósito según el artículo. Si la cantidad almacenada es menor
al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el % de
ocupación. Si la cantidad almacenada es mayor o igual al límite retornar
“DEPOSITO COMPLETO”. 
*/

CREATE FUNCTION ej1 (@id_articulo  char(8) , @id_deposito char(2))
RETURNS char(60)
AS
BEGIN
	RETURN  
		(SELECT CASE 
			WHEN (stoc_cantidad > stoc_stock_maximo)
				THEN 'DEPOSITO COMPLETO'
			ELSE  'OCUPACION DEL DEPOSITO '+ stoc_deposito+ ' '+ STR( stoc_cantidad / stoc_stock_maximo * 100 , 12,2) +'%'
				END
		FROM Stock
		WHERE stoc_producto = @id_articulo AND stoc_deposito = @id_deposito)
END
GO

SELECT dbo.ej1(stoc_producto,stoc_stock_maximo) from stock
SELECT dbo.ej1('00000102','00')
SELECT dbo.ej1('00000030','00')

DROP FUNCTION ej1;

/*
2. Realizar una función que dado un artículo y una fecha, retorne el stock que existía a
esa fecha 
*/

CREATE FUNCTION ej2 (@producto  char(8) , @fecha smalldatetime)
RETURNS numeric(12,2)
AS
BEGIN
	return (SELECT SUM(stoc_cantidad) FROM Stock WHERE stoc_producto = @producto) + 
			(SELECT SUM(item_cantidad) FROM Item_Factura JOIN Factura 
				ON item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
				WHERE item_producto = @producto AND fact_fecha >= @fecha)
END
GO

DROP FUNCTION ej2;
-- PRUEBA

-- Por ejemplo veo para el producto 00000102 veo cuanto se vendio desde el 17/06/2012

SELECT sum(item_cantidad) 
FROM Item_Factura
JOIN Factura 
ON item_numero + item_sucursal + item_tipo =
fact_numero + fact_sucursal + fact_tipo
WHERE item_producto = '00000102'
AND fact_fecha >= 2012-06-17   --  --> 44
--stock disponible
SELECT SUM(stoc_cantidad) FROM Stock WHERE stoc_producto = '00000102' --  --> 548

--Funcion
SELECT  dbo.ej2('00000102', 2012-06-17) --  --> 592

/*
3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado en
caso que sea necesario. Se sabe que debería existir un único gerente general (debería
ser el único empleado sin jefe). Si detecta que hay más de un empleado sin jefe
deberá elegir entre ellos el gerente general, el cual será seleccionado por mayor
salario. Si hay más de uno se seleccionara el de mayor antigüedad en la empresa.
Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla de un único
empleado sin jefe (el gerente general) y deberá retornar la cantidad de empleados
que había sin jefe antes de la ejecución. 
*/

IF OBJECT_ID('PR_BUSCAR_GERENTE') IS NOT NULL
	DROP PROCEDURE PR_BUSCAR_GERENTE
GO

CREATE PROCEDURE ej3(@CANTIDAD_EMPLEADOS_SIN_JEFE INT OUTPUT)
AS
BEGIN
	SET @CANTIDAD_EMPLEADOS_SIN_JEFE = 
	(SELECT COUNT(*)
	FROM Empleado
	WHERE empl_jefe IS NULL)

	IF @CANTIDAD_EMPLEADOS_SIN_JEFE = 0
	BEGIN
		RAISERROR('NO HAY EMPLEADOS SIN JEFE', 16, 1)
		RETURN
	END

	IF @CANTIDAD_EMPLEADOS_SIN_JEFE > 1
	BEGIN
		DECLARE @GERENTE NUMERIC(6,0) 
		
		SET @GERENTE =
		(SELECT TOP 1 
		empl_codigo
		FROM Empleado
		WHERE empl_jefe IS NULL 
		ORDER BY empl_salario DESC, empl_ingreso ASC)
	
	UPDATE Empleado 
	SET empl_jefe = @GERENTE
	WHERE empl_jefe IS NULL
	AND empl_codigo != @GERENTE

	UPDATE Empleado 
	SET empl_tareas = 'Gerente General'
	WHERE empl_codigo = @GERENTE
	END
END
GO

/*
4. Cree el/los objetos de base de datos necesarios para actualizar la columna de
empleado empl_comision con la sumatoria del total de lo vendido por ese empleado
a lo largo del último año. Se deberá retornar el código del vendedor que más vendió
(en monto) a lo largo del último año. 
*/

CREATE PROCEDURE ej4(@EMP_QUE_MAS_VENDIO INT OUTPUT)
AS
BEGIN
	SET @EMP_QUE_MAS_VENDIO = 
	(SELECT TOP 1 fact_cliente
	FROM Factura
	WHERE YEAR(fact_fecha) = (SELECT YEAR((SELECT MAX(fact_fecha) FROM Factura)))
	GROUP BY fact_cliente
	ORDER BY SUM(fact_total) DESC)

	UPDATE Empleado 
	SET empl_comision = 
	ISNULL((SELECT SUM(fact_total) FROM Factura
			WHERE YEAR(fact_fecha) = (SELECT YEAR((SELECT MAX(fact_fecha) FROM Factura)))
			AND fact_cliente = empl_codigo
			GROUP BY fact_cliente),0)
	
END

/*
5. Realizar un procedimiento que complete con los datos existentes en el modelo
provisto la tabla de hechos denominada Fact_table tiene las siguiente definición:
Create table Fact_table
( anio char(4),
mes char(2),
familia char(3),
rubro char(4),
zona char(3),
cliente char(6),
producto char(8),
cantidad decimal(12,2),
monto decimal(12,2)
)
Alter table Fact_table
Add constraint primary key(anio,mes,familia,rubro,zona,cliente,producto)
*/

-- El 5 esta relacionado con business intelligence --> verlo mas adelante

/*
6. Realizar un procedimiento que si en alguna factura se facturaron componentes que
conforman un combo determinado (o sea que juntos componen otro producto de
mayor nivel), en cuyo caso deberá reemplazar las filas correspondientes a dichos
productos por una sola fila con el producto que componen con la cantidad de dicho
producto que corresponda. 
*/

ALTER PROCEDURE ej6
AS
BEGIN
    DECLARE @combo CHAR(8);
    DECLARE @combocantidad INTEGER;
    
    DECLARE @fact_tipo CHAR(1);
    DECLARE @fact_suc CHAR(4);
    DECLARE @fact_nro CHAR(8);
    

    
    DECLARE  cFacturas CURSOR FOR --CURSOR PARA RECORRER LAS FACTURAS
        SELECT fact_tipo, fact_sucursal, fact_numero
        FROM Factura ;
		       
        OPEN cFacturas
        
        FETCH next FROM cFacturas
        INTO @fact_tipo, @fact_suc, @fact_nro
        
        WHILE @@FETCH_STATUS = 0
        BEGIN   
            DECLARE  cProducto CURSOR FOR
            SELECT comp_producto --ACA NECESITAMOS UN CURSOR PORQUE PUEDE HABER MAS DE UN COMBO EN UNA FACTURA
            FROM Item_Factura join Composicion C1 ON item_producto = C1.comp_componente
            WHERE item_cantidad >= C1.comp_cantidad AND
                  item_sucursal = @fact_suc AND
                  item_numero = @fact_nro AND
                  item_tipo = @fact_tipo
            GROUP BY C1.comp_producto
            HAVING COUNT(*) = (SELECT COUNT(*) FROM Composicion C2 WHERE C2.comp_producto= C1.comp_producto)
            
            OPEN cProducto
            FETCH next FROM cProducto INTO @combo
            WHILE @@FETCH_STATUS = 0 
            BEGIN
                        
                SELECT @combocantidad= MIN(FLOOR((item_cantidad/c1.comp_cantidad))) --Con la cant minima de cualquier componente, determinas cuantos
				--combos podes generar ==> Ej: 10 cocas, 5 big-macs y 4 papas ==> Podes generar 4 combos big mac
                FROM Item_Factura join Composicion C1 ON (item_producto = C1.comp_componente)
                WHERE item_cantidad >= C1.comp_cantidad AND
                      item_sucursal = @fact_suc AND
                      item_numero = @fact_nro AND
                      item_tipo = @fact_tipo AND
                      c1.comp_producto = @combo --SACAMOS CUANTOS COMBOS PUEDO ARMAR COMO MÁXIMO (POR ESO EL MIN)
                
                --INSERTAMOS LA FILA DEL COMBO CON EL PRECIO QUE CORRESPONDE
                INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
                SELECT @fact_tipo, @fact_suc, @fact_nro, @combo, @combocantidad, (@combocantidad * (SELECT prod_precio FROM Producto WHERE prod_codigo = @combo));              
 
                UPDATE Item_Factura  
                SET 
                item_cantidad = i1.item_cantidad - (@combocantidad * (SELECT comp_cantidad FROM Composicion
                                                                        WHERE i1.item_producto = comp_componente 
                                                                              AND comp_producto=@combo)),
                ITEM_PRECIO = (i1.item_cantidad - (@combocantidad * (SELECT comp_cantidad FROM Composicion
                                                            WHERE i1.item_producto = comp_componente 
                                                                  AND comp_producto=@combo))) *     
                                                    (SELECT prod_precio FROM Producto WHERE prod_codigo = I1.item_producto)                                                                                                       
                FROM Item_Factura I1, Composicion C1 
                WHERE I1.item_sucursal = @fact_suc AND
                      I1.item_numero = @fact_nro AND
                      I1.item_tipo = @fact_tipo AND
                      I1.item_producto = C1.comp_componente AND
                      C1.comp_producto = @combo
                      
                DELETE FROM Item_Factura
                WHERE item_sucursal = @fact_suc AND
                      item_numero = @fact_nro AND
                      item_tipo = @fact_tipo AND
                      item_cantidad = 0
                
                FETCH next FROM cproducto INTO @combo
			    END
			    CLOSE cProducto;
			    deallocate cProducto;
            
            FETCH next FROM cFacturas INTO @fact_tipo, @fact_suc, @fact_nro
            END
            CLOSE cFacturas;
            deallocate cFacturas;
    END

/*
7. Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe
insertar una línea por cada artículo con los movimientos de stock realizados entre
esas fechas. La tabla se encuentra creada y vacía.

tabla VENTAS
Código --> Código del articulo
Detalle --> Detalle del articulo 
Cant.Mov. --> Cantidad de movimientos de ventas (Item factura) 
Precio de Venta --> Precio promedio de venta 
Renglón --> Nro. de línea de la tabla 
Ganancia --> Precio de Venta – Cantidad * Costo Actual  */

IF OBJECT_ID('Ventas','U') IS NOT NULL 
DROP TABLE Ventas
GO
Create table Ventas (
vent_codigo char(8) NULL, 
vent_detalle char(50) NULL, 
vent_movimientos int NULL, 
vent_precio_prom decimal(12,2) NULL, 
vent_renglon int, 
vent_ganancia char(6) NOT NULL)
/*
Alter table Ventas
Add constraint pk_ventas_ID primary key(vent_renglon)
GO*/

if OBJECT_ID('Ejercicio7','P') is not null
DROP PROCEDURE Ejercicio7
GO


CREATE PROCEDURE ej7(@EFECHA_INICIO smalldatetime , @FECHA_FIN smalldatetime)
AS
BEGIN

 DECLARE @Codigo char(8), @Detalle char(50), @Cant_Mov int, @Precio_de_venta decimal(12,2), @Renglon int, @Ganancia decimal(12,2)
 DECLARE cursor_articulos CURSOR
	FOR SELECT prod_codigo
			  ,prod_detalle
			  ,SUM(item_cantidad)
		  	  ,AVG(item_precio)
			  ,SUM(item_cantidad*item_precio)
		FROM Producto
		JOIN Item_Factura
		ON item_producto = prod_codigo
		JOIN Factura
		ON fact_tipo = item_tipo AND fact_sucursal = fact_sucursal AND fact_numero = item_numero
		WHERE fact_fecha BETWEEN @EFECHA_INICIO AND @FECHA_FIN
		GROUP BY prod_codigo,prod_detalle

	OPEN cursor_articulos
	SET @renglon = 0

	FETCH NEXT FROM cursor_articulos
	INTO @Codigo,@Detalle,@Cant_Mov,@Precio_de_venta,@Ganancia

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Renglon = @Renglon + 1
		INSERT INTO Ventas
		VALUES (@Codigo,@Detalle,@Cant_Mov,@Precio_de_venta,@Renglon,@Ganancia)
		FETCH NEXT FROM cursor_articulos
		INTO @Codigo,@Detalle,@Cant_Mov,@Precio_de_venta,@Renglon,@Ganancia
	END

	CLOSE cursor_articulos
	DEALLOCATE cursor_articulos
END

--Se hace con cursor para ir arreglando renglon x renglon. Sino no haria falta.

/*
8. Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por cantidad
de sus componentes, se aclara que un producto que compone a otro, también puede
estar compuesto por otros y así sucesivamente, la tabla se debe crear y está formada
por las siguientes columnas: DIFERENCIAS
Código --> Código del articuloDetalle --> Detalle del articulo Cantidad --> Cantidad de productos que conforman el comboPrecio_generado --> Precio que se compone a través de sus componentes Precio_facturado --> Precio del producto 
*/

IF OBJECT_ID('Diferencias','U') IS NOT NULL 
DROP TABLE Ventas
GO
Create table Diferencias (
dif_cod int IDENTITY(1,1) PRIMARY KEY, 
dif_codigo_producto char(8) NULL, 
dif_detalle char(50) NULL, 
dif_cantidad int NULL, 
dif_precio_generado decimal(12,2) NULL,
dif_precio_facturado decimal(12,2) NULL )

IF OBJECT_ID('preciocombo') IS NOT NULL
	DROP FUNCTION preciocombo
GO
CREATE FUNCTION preciocombo(@PRODUCTO CHAR(8))
	RETURNS DECIMAL(12,2)
AS
BEGIN
	declare @precio decimal(12,2)
	declare @cantidad numeric(4)
	declare @componente char(8)

	set @precio = 0

	declare c1 cursor for
	select comp_componente,comp_cantidad from Composicion where comp_producto = @PRODUCTO

	open c1
	fetch next from c1 into @componente,@cantidad

	if @@FETCH_STATUS <> 0
	begin
	close c1
	deallocate c1
	return (select prod_precio from Producto where prod_codigo = @PRODUCTO)
	end

	while @@FETCH_STATUS = 0
	begin
		set @precio = @precio + @cantidad * dbo.preciocombo(@componente)
		fetch next into @componente
	end

	return @precio
END
GO


if OBJECT_ID('ej8','P') is not null
DROP PROCEDURE ej8
GO

CREATE PROCEDURE ej8
AS
BEGIN
	INSERT Diferencias
	SELECT prod_codigo,prod_detalle, (SELECT COUNT(*) FROM Composicion WHERE comp_producto = prod_codigo),
	dbo.preciocombo(prod_codigo), item_precio
	FROM Item_Factura JOIN Producto
	ON item_producto = prod_codigo
	WHERE prod_codigo IN (SELECT comp_producto FROM Composicion) 
	AND dbo.preciocombo(prod_codigo) != item_precio
	GROUP BY prod_codigo,prod_detalle, (SELECT COUNT(*) FROM Composicion WHERE comp_producto = prod_codigo),
	dbo.preciocombo(prod_codigo), item_precio
END

/*
9. Crear el/los objetos de base de datos que ante alguna modificación de un ítem de
factura de un artículo con composición realice el movimiento de sus
correspondientes componentes. 
*/
create trigger ej9 on item_factura for insert, update
as
begin
	
	if (select count(*) from inserted where item_producto in (select comp_producto from Composicion))> 0
		begin
			declare @codigo char(8), @cantidad int, @deposito char(2)
			declare c1 cursor 
			for select stoc_producto,
					   item_cantidad,
					   stoc_deposito
				from stock 
					join Composicion on comp_producto = stoc_producto
					join inserted on item_producto = stoc_producto
				where stoc_producto in (select comp_componente from Composicion join inserted on item_producto = comp_producto)
				and stoc_deposito = (select right(item_sucursal,2) from inserted where comp_producto = item_producto)
				group by stoc_producto, item_cantidad, stoc_deposito

			open c1
			fetch next from c1
			into @codigo, @cantidad,@deposito
			while @@FETCH_STATUS = 0
			begin
				update stock
				set stoc_cantidad = stoc_cantidad - @cantidad
				where stoc_producto = @codigo and stoc_deposito = @deposito
				fetch next from c1
				into @codigo, @cantidad,@deposito
			end
			close c1
			deallocate c1
		end
end
go

/*
10. Crear el/los objetos de base de datos que ante el intento de borrar un artículo
verifique que no exista stock y si es así lo borre en caso contrario que emita un
mensaje de error. 
*/
CREATE TRIGGER ej10 ON Producto INSTEAD OF DELETE
AS 
BEGIN
	declare @producto char(8)
	declare c1 cursor  for 
	select prod_codigo from deleted 

	open c1
	fetch next from c1 into @producto

	while @@FETCH_STATUS = 0

	if (select ISNULL(SUM(stoc_cantidad),0) from deleted join Stock ON @producto = stoc_producto) > 0
		BEGIN
			--ROLLBACK TRANSACTION --> no hace falta porque es INSTEAD OF, no se ejecuta   
			PRINT 'No se puede borrar '+ @producto+' porque tiene stock'
		END
	ELSE
		BEGIN
			DELETE FROM Producto WHERE prod_codigo = @producto  --> hace falta justamente porque es INSTEAD OF, no me tengo que preocupar por las FK
		END
	close c1
	deallocate c1
END
 
--11. Cree el/los objetos de base de datos necesarios para que dado un código de
--empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
--indirectamente). Solo contar aquellos empleados (directos o indirectos) que
--tengan un código mayor que su jefe directo.

alter function ej11(@empleado numeric(6))
returns int
as
begin
	declare @cuantosEmpleados int
		
	select @cuantosEmpleados = isnull(count(distinct empl_codigo),0) from Empleado where empl_jefe = @empleado  and  empl_codigo > @empleado
	return @cuantosEmpleados + (select isnull(sum(dbo.ej11(empl_codigo)),0) from Empleado where @empleado = empl_jefe)  --> armo la recurisva tomando como jefe al empleado que tiene por jefe al que paso por parametro				
end

select dbo.ej11(3)
 
/*
12. Cree el/los objetos de base de datos necesarios para que nunca un producto pueda
ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se cumple y
que la base de datos es accedida por n aplicaciones de diferentes tipos y tecnologías.
No se conoce la cantidad de niveles de composición existentes. 
*/

create trigger ej12 on Composicion for insert,update
as
begin
	if(select count(*) from inserted where dbo.componecombo(comp_producto,comp_componente) = 1)  > 0 
		rollback
end

CREATE FUNCTION componecombo(@PRODUCTO CHAR(8), @COMPONENTE CHAR(8))
	RETURNS INT
AS
BEGIN

	declare @compo char(8)

	if @PRODUCTO = @COMPONENTE
		return 1

	declare c1 cursor for
	select comp_componente from Composicion where comp_producto = @PRODUCTO

	open c1
	fetch next from c1 into @compo

	while @@FETCH_STATUS = 0
	begin
		if dbo.componecombo(@PRODUCTO, @compo) = 1
			return 1
		
		fetch next into @compo
	end
	close c1
	deallocate c1
	return 0
END
GO

/*
13. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla
“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de sus
empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha regla
se cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos y
tecnologías 
*/

create trigger ej13 on Empleado for insert, update
as
begin
		if (select count(*) from inserted where empl_salario > dbo.sueldossubordinados(empl_codigo)*0.2) > 0
		rollback
end

CREATE FUNCTION sueldossubordinados(@jefe char(8))
returns decimal(12,2)
as
begin
	
	declare @salarios decimal(12,2)
		
	select @salarios = isnull(sum(empl_salario),0) from Empleado where @jefe = empl_jefe 		
	return @salarios + (select isnull(sum(dbo.sueldossubordinados(empl_codigo)),0) from Empleado where @jefe = empl_jefe)				
end

/*
14. Agregar el/los objetos necesarios para que si un cliente compra un producto
compuesto a un precio menor que la suma de los precios de sus componentes que
imprima la fecha, que cliente, que productos y a qué precio se realizó la compra.
No se deberá permitir que dicho precio sea menor a la mitad de la suma de los
componentes. 
*/

CREATE FUNCTION precioprodcompuesto(@producto char(8))
returns decimal(12,2)
as
begin
	
	declare @precio decimal(12,2)
		
	select @precio = isnull(sum(prod_precio * comp_cantidad),0) from Composicion join Producto on prod_codigo = comp_componente where @producto = comp_producto 		
	return @precio + (select isnull(sum(dbo.precioprodcompuesto(comp_componente)),0) from Composicion where @producto = comp_producto)				
end

--select * from Composicion join Producto on comp_componente = prod_codigo  
-- 00001104  --> 3.51 + 2 *1.70
--select dbo.precioprodcompuesto('00001104')

create trigger ej14 ON ITEM_FACTURA instead of insert 
as
begin
	
	declare @tipo char(1)
	declare @sucursal char(4)
	declare @numero char(8)
	declare @producto char(8)
	declare @cantidad decimal(12,2)
	declare @precio decimal(12,2)
	declare @fecha smalldatetime
	declare @cliente char(6)

	select @fecha = fact_fecha from Factura where fact_tipo = @tipo and fact_sucursal = @sucursal and fact_numero = @numero
	select @cliente = fact_cliente from Factura where fact_tipo = @tipo and fact_sucursal = @sucursal and fact_numero = @numero


	declare c1 cursor for
	select item_tipo,item_sucursal,item_numero,item_producto, item_cantidad, item_precio from inserted where item_producto in (select comp_producto from Composicion)

	open c1
	fetch next from c1 into @tipo,@sucursal,@numero,@producto,@cantidad,@precio

	while @@FETCH_STATUS = 0
	begin
		if dbo.precioprodcompuesto(@producto) <= (select prod_precio from Producto where prod_codigo = @producto)
			insert Item_Factura values (@tipo,@sucursal,@numero,@producto,@cantidad,@precio)
			break
		if dbo.precioprodcompuesto(@producto) * 0.5 > (select prod_precio from Producto where prod_codigo = @producto)
			begin
			--Como hay un producto mal hay que borrar todos los otros productos de la factura y la factura en si porque es invalida
				delete from item_factura where item_numero+item_sucursal+item_tipo = @numero+@SUCURSAL+@tipo
				delete from factura where fact_numero+fact_sucursal+fact_tipo = @numero+@SUCURSAL+@tipo
				print 'El precio de un producto compuesto no puede ser menor al 50% del precio de sus componentes'
				break
			end
		else if dbo.precioprodcompuesto(@producto) > (select prod_precio from Producto where prod_codigo = @producto)
			begin
				insert Item_Factura values (@tipo,@sucursal,@numero,@producto,@cantidad,@precio)
				print @fecha +' '+@cliente +' '+@producto+' '+@precio  
			end
	end
	close c1
	deallocate c1
end

/*
15. Cree el/los objetos de base de datos necesarios para que el objeto principal reciba un
producto como parametro y retorne el precio del mismo.
Se debe prever que el precio de los productos compuestos sera la sumatoria de los
componentes del mismo multiplicado por sus respectivas cantidades. No se conocen
los nivles de anidamiento posibles de los productos. Se asegura que nunca un
producto esta compuesto por si mismo a ningun nivel. El objeto principal debe
poder ser utilizado como filtro en el where de una sentencia select. 
*/
alter FUNCTION ej15(@producto char(8))
returns decimal(12,2)
as
begin
	declare @precio decimal(12,2) = 0

	if @producto not in (select comp_producto from Composicion)
		set @precio = (select prod_precio from Producto where prod_codigo = @producto) + @precio
	else
	begin	
		select  @precio =  (select isnull(sum(dbo.ej15(comp_componente)*comp_cantidad),0) from Composicion where @producto = comp_producto)	
	end		
	return @precio	
end

--select dbo.ej15('00001104')
--select * from producto
--select * from Composicion

/*
16. Desarrolle el/los elementos de base de datos necesarios para que ante una venta
automaticamante se descuenten del stock los articulos vendidos. Se descontaran del
deposito que mas producto poseea y se supone que el stock se almacena tanto de
productos simples como compuestos (si se acaba el stock de los compuestos no se
arman combos)
En caso que no alcance el stock de un deposito se descontara del siguiente y asi
hasta agotar los depositos posibles. En ultima instancia se dejara stock negativo en
el ultimo deposito que se desconto. 
*/

create trigger ej16 ON Item_factura for insert 
as
begin
	declare @producto char(8)
	declare @cantidad decimal(12,2)
	declare @deposito char(2)
	declare @cantidad_stock decimal(12,2)
	declare @anterior char(2)

	declare c1 cursor for
	select item_producto,item_cantidad from inserted 

	open c1
	fetch next from c1 into @producto,@cantidad
	while @@FETCH_STATUS = 0
	begin
		--Arranco a recorrer los stocks para ir descontando la cantidad
	   declare cVentas cursor for
	   select stoc_deposito, stoc_cantidad from STOCK where stoc_producto = @producto and stoc_cantidad > 0 order by stoc_cantidad desc

	   open cVentas
	   fetch next from cVentas into @deposito,@cantidad_stock
	   while @@FETCH_STATUS = 0
			begin
				if @cantidad_stock >= @cantidad
					begin
					UPDATE STOCK SET stoc_cantidad = stoc_cantidad - @cantidad WHERE stoc_deposito = @deposito and stoc_producto = @producto
					set @cantidad = 0
					break
					end
				else
					begin
						UPDATE STOCK SET stoc_cantidad = 0 WHERE stoc_deposito = @deposito and stoc_producto = @producto
						set @cantidad = @cantidad - @cantidad_stock
					end
			set @anterior = @deposito
			fetch next from cVentas into @producto, @cantidad
			end
			if @cantidad > 0
				UPDATE STOCK SET stoc_cantidad = stoc_cantidad - @cantidad WHERE stoc_deposito = @anterior and stoc_producto = @producto
	   close cVentas
	   deallocate cVentas
	   fetch next from c1 into @producto, @cantidad
	end
	close c1
	deallocate c1
end

/*
17. Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto
que se debe almacenar en el deposito y que el stock maximo es la maxima cantidad
de ese producto en ese deposito, cree el/los objetos de base de datos necesarios para
que dicha regla de negocio se cumpla automaticamente. No se conoce la forma de
acceso a los datos ni el procedimiento por el cual se incrementa o descuenta stock 
*/

create trigger ej17 on Stock for update,insert
as
begin
	declare @producto char(8)
	declare @punto_reposicion decimal(12,2)
	declare @stock_max decimal(12,2) 
	declare @stock_cantidad decimal(12,2)
	declare @deposito char(2)

	declare c_producto cursor for select stoc_producto, stoc_punto_reposicion, stoc_stock_maximo, stoc_cantidad, stoc_deposito from inserted

	open c_producto
	fetch next from c_producto into @producto, @punto_rep, @stoc_max, @stoc_cantidad, @deposito

	while @@FETCH_STATUS = 0
	begin
		if @stock_cantidad < @punto_reposicion 
			print('Hay que reponer stock del producto '+@producto+' en el deposito '+@deposito)
		else if @stock_cantidad > @stock_max
			print('No se puede superar el stock maximo de'+@stock_max+' del producto '+@producto+' en el deposito '+@deposito)
			rollback
		fetch next from c_producto into @producto, @punto_reposicion, @stock_max, @stock_cantidad, @deposito		
	end
	close c_producto
	deallocate c_producto
end

/*
18. Sabiendo que el limite de credito de un cliente es el monto maximo que se le
puede facturar mensualmente, cree el/los objetos de base de datos necesarios
para que dicha regla de negocio se cumpla automaticamente. No se conoce la
forma de acceso a los datos ni el procedimiento por el cual se emiten las facturas
*/
create function calcularVentasClientesMes(@cliente char(6),@fecha smalldatetime)
returns smalldatetime
as
begin
	declare @total_vendido decimal(12,2)

	select  @total_vendido =  (select isnull(sum(fact_total),0) from Factura 
								where @cliente = fact_cliente and YEAR(fact_fecha) = year(@fecha) and MONTH(fact_fecha) = month(@fecha))

	return @total_vendido

end


create trigger ej18 on Factura for insert 
as
begin	
	
	declare @fecha smalldatetime
	declare @total_facturado decimal(12,2)
	declare @cliente char(6)

	declare c1 cursor for
	select fact_fecha,sum(fact_total), fact_cliente  from inserted
	open c1
	fetch next from c1 into @fecha,@total_facturado,@cliente
	while @@FETCH_STATUS = 0
	begin
		if  dbo.calcularVentasClientesMes(@cliente,@fecha) + @total_facturado > (select clie_limite_credito from cliente where clie_codigo = @cliente)
				rollback
			
		fetch next from c1 into @fecha,@total_facturado,@cliente
	end
	close c1
	deallocate c1
end
-- Estaria mal el @total_facturado porque como es FOR la factura ya fue agregada y por lo tanto considera estos ultimos insert. Asi estaria sumando 2 veces lo mismos
/*
19. Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente
regla de negocio automáticamente “Ningún jefe puede tener menos de 5 años de
antigüedad y tampoco puede tener más del 50% del personal a su cargo
(contando directos e indirectos) a excepción del gerente general”. Se sabe que en
la actualidad la regla se cumple y existe un único gerente general.
*/
create function calcularAntiguedad(@empleado numeric(6,0))
returns smalldatetime
as
begin
	declare @antiguedad smalldatetime
	select @antiguedad = datediff(year,empl_ingreso,GETDATE()) from Empleado where @empleado = empl_codigo

	return @antiguedad

end

create function calcularCantidadSubordinados(@empleado numeric(6,0))
returns int
as
begin
	declare @cantidad int

	select @cantidad = count(distinct empl_codigo) from Empleado where @empleado = empl_jefe

	return @cantidad + (select isnull(sum(dbo.calcularCantidadSubordinados(empl_codigo)),0) from Empleado where empl_jefe = @empleado)

end

create trigger ej19 on Empleado for update,insert,delete
as
begin
	declare @empleado numeric(6)
	declare @jefe numeric(6)

	if (select count(*) from inserted) > 0
		begin
			declare cEmpleado cursor for select empl_codigo, empl_jefe from inserted

			open cEmpleado
			fetch next from c_producto into  @empleado,@jefe

			while @@FETCH_STATUS = 0
			begin
				if dbo.calcularAntiguedad(@empleado) < 5 and dbo.calcularCantidadSubordinados(@empleado) > 0
					rollback
				else if dbo.calcularCantidadSubordinados(@empleado) > 0.5 * (select count(*) from Empleado) and @jefe <> null
					rollback
			
			fetch next from c_inserted into @empleado, @jefe
			end
		close c_inserted
		deallocate c_inserted
		end
	else
		begin
			if exists(select empl_jefe from empleado group by empl_jefe having dbo.calcularCantidadSubordinados(empl_jefe)> (select count(*) from empleado)/2)	
			rollback
		end
end


/*
20. Crear el/los objeto/s necesarios para mantener actualizadas las comisiones del
vendedor.
El cálculo de la comisión está dado por el 5% de la venta total efectuada por ese
vendedor en ese mes, más un 3% adicional en caso de que ese vendedor haya
vendido por lo menos 50 productos distintos en el mes.
*/
create trigger ej20 on Factura for update,insert
as
begin
	declare @vendedor numeric(6)
	declare @mes int
	declare @anio int
	declare @valor_facturado decimal(12,2)
	declare @cantidad_productos_vendidos int


	declare c1 cursor for select fact_vendedor,month(fact_fecha), year(fact_fecha) from inserted 
		
	open c1
	fetch next from c1 into  @vendedor,@mes,@anio

	while @@FETCH_STATUS = 0
	begin
		set @valor_facturado = dbo.calcularTotalFacturado(@vendedor,@mes, @anio) +
		(select isnull(sum(fact_total) ,0) from inserted where fact_vendedor = @vendedor and MONTH(fact_fecha) = @mes and  year(fact_fecha) = @anio)
		
		set @cantidad_productos_vendidos = (select count(distinct item_producto) from Item_Factura 
											join factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
											where fact_vendedor = @vendedor and MONTH(fact_fecha) = @mes and  year(fact_fecha) = @anio)
											+ (select count (distinct item_producto) from inserted join Item_Factura
											on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
											where item_producto not in (select item_producto from Item_Factura 
											join factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
											where fact_vendedor = @vendedor and MONTH(fact_fecha) = @mes and  year(fact_fecha) = @anio))

											
		if @cantidad_productos_vendidos >= 50 
			update Empleado set empl_comision = 0.05 * @valor_facturado + 0.03 * @valor_facturado where empl_codigo = @vendedor
		else
			update Empleado set empl_comision = 0.05 * @valor_facturado where empl_codigo = @vendedor
		
		fetch next from c1 into @vendedor,@mes,@anio
	end
	close c1
	deallocate c1
end

create function calcularTotalFacturado(@empleado numeric(6),@mes int, @anio int)
returns  decimal(12,2)
as
begin
	return (select isnull(sum(fact_total) ,0) from Factura where fact_vendedor = @empleado and MONTH(fact_fecha) = @mes and  year(fact_fecha) = @anio ) 

end	


/*
21. Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que en una factura no puede contener productos de
diferentes familias. En caso de que esto ocurra no debe grabarse esa factura y
debe emitirse un error en pantalla.
*/
create function cantidadFamiliasFactura (@fact_tipo char(1),@fact_sucursal char(4),@fact_numero char(8))
returns  decimal(12,2)
as
begin
	return (select isnull(count(distinct prod_familia),0) from Item_Factura join Producto on prod_codigo = item_producto 
		where item_tipo = @fact_tipo and item_sucursal = @fact_sucursal and item_numero = @fact_numero )
end	
create trigger ej21 on Item_factura for update,insert
as
begin
	declare @item_tipo char(1) 
	declare @item_sucursal char(4) 
	declare @item_numero char(8)
	
	declare c1 cursor for select item_tipo,item_sucursal,item_numero from inserted
		
	open c1
	fetch next from c1 into @fact_tipo,@fact_sucursal,@fact_numero

	while @@FETCH_STATUS = 0
		begin	
			if dbo.cantidadFamiliasFactura(@item_tipo,@item_sucursal,@item_numero) > 1
				begin
					delete Item_Factura where item_tipo = @item_tipo and item_sucursal = @item_sucursal and item_numero = @item_numero
					delete Factura where fact_tipo = @item_tipo and fact_sucursal = @item_sucursal and fact_numero = @item_numero
					print 'Error: una factura no puede tener productos de mas de 1 una familia'
					rollback
				end
		
			fetch next from c1 into @fact_tipo,@item_sucursal,@item_numero
		end
	close c1
	deallocate c1
end

/*
22. Se requiere recategorizar los rubros de productos, de forma tal que nigun rubro
tenga más de 20 productos asignados, si un rubro tiene más de 20 productos
asignados se deberan distribuir en otros rubros que no tengan mas de 20
productos y si no entran se debra crear un nuevo rubro en la misma familia con
la descirpción “RUBRO REASIGNADO”, cree el/los objetos de base de datos
necesarios para que dicha regla de negocio quede implementada.
*/

CREATE PROCEDURE ejercicio22 
AS
BEGIN
DECLARE @rubro char(4)

DECLARE cRubro CURSOR FOR SELECT rubr_id FROM Rubro WHERE (SELECT COUNT(DISTINCT prod_codigo) FROM Producto WHERE prod_rubro = rubr_id) > 20
OPEN cRubro
FETCH NEXT FROM cRubro INTO @rubro 

WHILE @@FETCH_STATUS = 0 
BEGIN
            DECLARE @producto char(4)    
            DECLARE @prod_sobrantes int

            SET @prod_sobrantes = (SELECT COUNT(DISTINCT prod_codigo) FROM Producto WHERE prod_rubro = @rubro) - 20
                        
            DECLARE cProducto CURSOR FOR SELECT prod_codigo FROM Producto WHERE prod_rubro = @rubro
            OPEN cProducto
            FETCH NEXT FROM cProducto INTO @producto 

            WHILE @@FETCH_STATUS = 0 AND @prod_sobrantes > 0
            BEGIN
				DECLARE @rubroLibre char(4)
				IF EXISTS (SELECT TOP 1 prod_rubro FROM Producto GROUP BY prod_rubro HAVING COUNT(DISTINCT prod_codigo) < 20 ORDER BY COUNT(DISTINCT prod_codigo))
					BEGIN
						SET @rubroLibre = (SELECT TOP 1 prod_rubro FROM Producto GROUP BY prod_rubro HAVING COUNT(DISTINCT prod_codigo) < 20 ORDER BY COUNT(DISTINCT prod_codigo))
						UPDATE Producto SET prod_rubro = @rubroLibre WHERE prod_codigo = @producto
					END
				ELSE
					BEGIN
							IF NOT EXISTS(SELECT rubr_id FROM Rubro WHERE rubr_detalle = 'Rubro reasignado')  
							INSERT INTO Rubro (RUBR_ID,rubr_detalle) VALUES ('xx','Rubro reasignado')
                
							UPDATE Producto SET prod_rubro = (SELECT rubr_id FROM Rubro WHERE rubr_detalle = 'Rubro reasignado') WHERE prod_codigo = @producto
                END                        
            SET @prod_sobrantes = @prod_sobrantes - 1
            FETCH NEXT FROM cProducto INTO @producto
            END
            CLOSE cProducto
            DEALLOCATE cProducto

FETCH NEXT FROM cRubro INTO @rubro 
END
CLOSE cRubro
DEALLOCATE cRubro
END

/*
23. Desarrolle el/los elementos de base de datos necesarios para que ante una venta
automaticamante se controle que en una misma factura no puedan venderse más
de dos productos con composición. Si esto ocurre debera rechazarse la factura.
*/
alter trigger ej23 on Item_factura for insert
as
begin
	declare @tipo char(1)
	declare @sucursal char(4)
	declare @numero char(8)
	declare @cantidad_compuestos int
	declare @nro int
	 
	declare c1 cursor for
	select item_tipo,item_sucursal,item_numero,count(distinct item_producto) from inserted where item_producto in (select comp_producto from Composicion)
	group by item_tipo,item_sucursal,item_numero

	open c1
	fetch next from c1 into @tipo,@sucursal,@numero,@cantidad_compuestos

	while @@FETCH_STATUS = 0
	begin
		if @cantidad_compuestos > 2
			begin
				set @nro =  (select count(distinct item_producto) from Item_Factura where item_tipo+item_sucursal+item_numero = @tipo+@sucursal+@numero)
				print @nro
				delete Item_Factura where item_tipo+item_sucursal+item_numero =  @tipo+@sucursal+@numero 
				delete Factura where fact_tipo+fact_sucursal+fact_numero = @tipo+@sucursal+@numero 
				print 'Error: factura con demasiados items compuestos'
				--rollback
			end
		fetch next from c1 into @tipo,@sucursal,@numero,@cantidad_compuestos
	end
	close c1
	deallocate c1
end
--Pruebas
INSERT Factura(fact_tipo, fact_sucursal,fact_numero) VALUES ('A', '9999','98765432');

insert into Item_Factura (item_tipo, item_sucursal,item_numero, item_producto)
values ('A', '9999','98765432','00001104'),('A', '9999','98765432','00001718'), ('A', '9999','98765432','00001707');


select * from Item_Factura where  item_tipo+item_sucursal+item_numero = 'A999998765432'
select * from Factura where  fact_tipo+fact_sucursal+fact_numero = 'A999998765432'

drop trigger ej23

/*
24. Se requiere recategorizar los encargados asignados a los depositos. Para ello
cree el o los objetos de bases de datos necesarios que lo resueva, teniendo en
cuenta que un deposito no puede tener como encargado un empleado que
pertenezca a un departamento que no sea de la misma zona que el deposito, si
esto ocurre a dicho deposito debera asignársele el empleado con menos
depositos asignados que pertenezca a un departamento de esa zona.
*/

create procedure ej24
as
begin
	declare @deposito char(2), @encargado numeric(6,0), @zona char(3)
	declare c_depo cursor for select depo_codigo, depo_encargado, depo_zona from DEPOSITO

	open c_depo
	fetch next from c_depo into @deposito, @encargado, @zona
	while @@FETCH_STATUS = 0 
	begin
		
		if dbo.malEncargado(@encargado, @zona) = 1  
			begin
				update DEPOSITO set depo_encargado = (select top 1 empl_codigo from Empleado join Departamento on empl_departamento = depa_codigo 
															where depa_zona = @zona order by (select count(*) from deposito where depo_encargado = empl_codigo) asc )
			end
		 
		fetch next from c_depo into @deposito, @encargado, @zona
	end
	close c_depo
	deallocate c_depo
	
end

alter function malEncargado(@encargado numeric(6,0), @zona char(3))
returns int
as
begin
	if @zona = (select depa_zona from empleado join Departamento on depa_codigo = empl_departamento where empl_codigo = @encargado)
		return 1
	 
		return 0
end

/*
25. Desarrolle el/los elementos de base de datos necesarios para que no se permita
que la composición de los productos sea recursiva, o sea, que si el producto A 
compone al producto B, dicho producto B no pueda ser compuesto por el
producto A, hoy la regla se cumple.
*/

 alter trigger ej25 on composicion for insert, update 
as
begin
	
	if (select count(*) from inserted where dbo.componeHijo(comp_producto,comp_componente)= 1) > 0
		print 'Error: composicion recursiva'
		rollback
end

alter function componeHijo(@producto char(8), @componente char(8))
returns int
as
begin
	declare @prodAux char(8);
	declare cursor_componente cursor for
	select comp_componente from Composicion 
	where comp_producto = @componente

	open cursor_componente
	fetch next from cursor_componente into @prodAux
	while @@FETCH_STATUS = 0
	begin 
		if  @prodAux = @producto
			begin
				close cursor_componente
				deallocate cursor_componente 
				return 1
			end
		fetch next from cursor_componente into @prodAux
	end
	close cursor_componente
	deallocate cursor_componente
	return 0
end

select * from Composicion

--INSERT Composicion(comp_cantidad, comp_producto,comp_componente) VALUES (1, '00001109','00001104');

/*
26. Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que una factura no puede contener productos que
sean componentes de otros productos. En caso de que esto ocurra no debe
grabarse esa factura y debe emitirse un error en pantalla.
*/

create trigger ej26 on Item_factura for insert
as
begin
	
	DECLARE @tipo CHAR, @sucursal CHAR(4), @numero CHAR(8), @cantidad_componentes int

    declare c1 cursor for 
	select item_tipo, item_sucursal,item_numero, isnull(count(distinct item_producto),0) from inserted 
	where item_producto in (select comp_componente from Composicion) group by item_tipo, item_sucursal,item_numero

    fetch next from c1 into @tipo, @sucursal, @numero,@cantidad_componentes

    while @@FETCH_STATUS = 0
    begin

        if @cantidad_componentes > 0
        begin
            delete from item_factura where item_numero+item_sucursal+item_tipo = @numero+@sucursal+@tipo
            delete from factura where fact_numero+fact_sucursal+fact_tipo = @numero+@sucursal+@tipo
			print('Error: factura con productos componente')
        end

        fetch next from c1 into @tipo, @sucursal, @numero
    end
    close c1
    deallocate c1
end

/*
27. Se requiere reasignar los encargados de stock de los diferentes depósitos. Para
ello se solicita que realice el o los objetos de base de datos necesarios para
asignar a cada uno de los depósitos el encargado que le corresponda,
entendiendo que el encargado que le corresponde es cualquier empleado que no
es jefe y que no es vendedor, o sea, que no está asignado a ningun cliente, se
deberán ir asignando tratando de que un empleado solo tenga un deposito
asignado, en caso de no poder se irán aumentando la cantidad de depósitos
progresivamente para cada empleado.
*/

alter function obtenerJefe()
returns numeric(6) 
as
begin
	return  (select top 1 empl_codigo from Empleado where empl_codigo 
			not in (select empl_jefe from Empleado) and empl_codigo not in (select fact_vendedor from Factura) 
			order by (select isnull(count(*),0) from DEPOSITO where depo_encargado = empl_codigo) asc)
end

select empl_codigo from Empleado where empl_codigo not in (select empl_jefe from Empleado)

create procedure ej27 
as
begin
	declare @deposito char(2) 

	declare c1 cursor for select depo_codigo from Deposito

	open c1 
	fetch next from c1 into @deposito
	while @@FETCH_STATUS = 0
	begin
			update DEPOSITO set depo_encargado = dbo.obtenerJefe()

		fetch next from c1 into @deposito
	end
	close c1
	deallocate c1
end
 

/*
28. Se requiere reasignar los vendedores a los clientes. Para ello se solicita que
realice el o los objetos de base de datos necesarios para asignar a cada uno de los
clientes el vendedor que le corresponda, entendiendo que el vendedor que le
corresponde es aquel que le vendió más facturas a ese cliente, si en particular un
cliente no tiene facturas compradas se le deberá asignar el vendedor con más
venta de la empresa, o sea, el que en monto haya vendido más.
*/

alter function obtenerJefe(@cliente char(6))
returns numeric(6) 
as
begin
	declare @vendedor numeric(6)
	 set @vendedor = (select top 1 fact_vendedor from Factura where fact_cliente = @cliente group by fact_vendedor order by count(*) desc)

	 return isnull(@vendedor, (select top 1 fact_vendedor
                                        from factura
                                        group by fact_vendedor
                                        order by  sum(fact_total)))
end

create procedure ej28 
as
begin
	declare @cliente char(6)

	declare c1 cursor for select clie_codigo from Cliente

	open c1 
	fetch next from c1 into @cliente
	while @@FETCH_STATUS = 0
	begin
		update Cliente set clie_vendedor = dbo.obtenerJefe(@cliente) where clie_codigo = @cliente	 
	
		fetch next from c1 into @deposito
	end
	close c1
	deallocate c1
end
 

/*
29. Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que una factura no puede contener productos que
sean componentes de diferentes productos. En caso de que esto ocurra no debe
grabarse esa factura y debe emitirse un error en pantalla.
*/

alter trigger ej29 on Item_factura for insert
as
begin
	
	DECLARE @tipo CHAR, @sucursal CHAR(4), @numero CHAR(8) 

    declare c1 cursor for 
	select item_tipo, item_sucursal,item_numero from inserted
	
	 
	open c1
    fetch next from c1 into @tipo, @sucursal, @numero 

    while @@FETCH_STATUS = 0
    begin

        if dbo.tieneComponenteDeMuchosProductos(@tipo+@sucursal+@numero) = 1
        begin
            delete from item_factura where item_numero+item_sucursal+item_tipo = @numero+@sucursal+@tipo
            delete from factura where fact_numero+fact_sucursal+fact_tipo = @numero+@sucursal+@tipo
			print('Error: factura con componentes de productos diferentes')
        end

        fetch next from c1 into @tipo, @sucursal, @numero 
    end
    close c1
    deallocate c1
end

create function tieneComponenteDeMuchosProductos(@factura char(14))
returns int
as
begin
    declare @cantidad int
	select @cantidad = count(distinct item_producto)
	from Item_Factura 
	where @factura = item_tipo+item_sucursal+item_numero
	and (select count(distinct comp_producto) from Composicion where item_producto = comp_componente) > 1

	if @cantidad > 0
	return 1

	return 0
end

select comp_producto, comp_componente from Composicion order by comp_componente

/*
30. Agregar el/los objetos necesarios para crear una regla por la cual un cliente no
pueda comprar más de 100 unidades en el mes de ningún producto, si esto
ocurre no se deberá ingresar la operación y se deberá emitir un mensaje “Se ha
superado el límite máximo de compra de un producto”. Se sabe que esta regla se
cumple y que las facturas no pueden ser modificadas.
*/

create trigger ej30 on Item_factura for insert
as
begin
	
	DECLARE @tipo CHAR, @sucursal CHAR(4), @numero CHAR(8) , @producto char(8), @fecha smalldatetime, @cliente char(6)

    declare c1 cursor for 
	select item_tipo, item_sucursal,item_numero,item_producto, fact_fecha, fact_cliente 
		from inserted join Factura on fact_numero+fact_sucursal+fact_tipo = item_numero+item_sucursal+item_tipo

	open c1
    fetch next from c1 into @tipo, @sucursal, @numero,@producto,@fecha, @cliente
    while @@FETCH_STATUS = 0
    begin

        if dbo.cantidadProductosVendidos(@producto,@fecha,@cliente) > 100
        begin
            delete from item_factura where item_numero+item_sucursal+item_tipo = @numero+@sucursal+@tipo
            delete from factura where fact_numero+fact_sucursal+fact_tipo = @numero+@sucursal+@tipo
			print'Se ha superado el límite máximo de compra de un producto'
        end

       fetch next from c1 into @tipo, @sucursal, @numero,@producto,@fecha, @cliente
    end
    close c1
    deallocate c1
end

create function cantidadProductosVendidos(@producto char(8),@fecha smalldatetime, @cliente char(6))
returns int
as
begin
	return (select sum(item_cantidad) from Item_Factura join Factura on fact_numero+fact_sucursal+fact_tipo = item_numero+item_sucursal+item_tipo
	where fact_cliente = @cliente and item_producto = @producto and year(fact_fecha) = year(@fecha) and month(fact_fecha) = month(@fecha))
end

/*
31. Desarrolle el o los objetos de base de datos necesarios, para que un jefe no pueda
tener más de 20 empleados a cargo, directa o indirectamente, si esto ocurre
debera asignarsele un jefe que cumpla esa condición, si no existe un jefe para
asignarle se le deberá colocar como jefe al gerente general que es aquel que no
tiene jefe.
*/

create function cantidadSubordinados(@empleado numeric(6,0))
returns int
as
begin
	declare @cantidad int
	select @cantidad = count(distinct empl_codigo) from Empleado where @empleado = empl_jefe
	return @cantidad + (select isnull(sum(dbo.calcularCantidadSubordinados(empl_codigo)),0) from Empleado where empl_jefe = @empleado)
end


