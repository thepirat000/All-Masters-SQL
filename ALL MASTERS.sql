USE master
GO

/*
Drop Procedure SP_SELECT_ALL
Drop Procedure sp_ppinScriptLlavesForaneas
Drop Procedure sp_ppinScriptTabla
Drop Procedure SP_ppinAddDrop_ForeignKeys
Drop Procedure SP_ppinGenera_Insert
Drop Procedure sp_longitud
Drop Procedure sp_doc_comment
Drop Procedure sp_drop
Drop Procedure sp_ppinNombreTablaTemp
Drop Procedure sp_ppinSelectFromWhereForaneo
Drop Procedure sp_ppinInsertaObjetoError
Drop Procedure sp_ppinDependenciaSP
Drop Procedure sp_ppinGeneraScriptObjeto
Drop Procedure sp_GenerateConstantScript
*/

If exists ( Select * From sysobjects where name = 'SP_SELECT_ALL' )
	Drop Procedure SP_SELECT_ALL
GO

Create procedure SP_SELECT_ALL
(
@objname varchar(500),
@filtro varchar(50) = '',
@campo varchar(50) = ''
)
as
/* Federico Colombo */
Declare @sysobj_type char(2), @columna varchar(100)
Declare @vchCommand varchar(700)
Declare @vchNombreObjname varchar(256)
Declare @vchNombreBaseDatos varchar(256)
Declare @vchQuery varchar(512)
Declare @groupid int

Set @vchNombreBaseDatos = ''

Create table #tmpColumna
(
	vchColumna varchar(256) null
)

create table #helpIndex
(
	index_name			sysname collate database_default NOT NULL,
	index_description		varchar(210),
	index_keys			nvarchar(2126) collate database_default NOT NULL
)

If isnumeric(@objname) = 0 --No es un numero
Begin
	If @objname like '%..%'
	Begin		
		Select @vchNombreBaseDatos = substring(@objname, 1, CHARINDEX('.',@objname) - 1)
		Select @vchNombreObjname = substring(@objname, CHARINDEX('.',@objname) + 2, len(@objname))
	End
	Else
	Begin
		Set @vchNombreObjname = @objname
	End
End
Else
Begin
	Set @vchNombreObjname = @objname
End

Select @sysobj_type = xtype from sysobjects where id = object_id(@vchNombreObjname)
If @vchNombreBaseDatos is null or @vchNombreBaseDatos = ''
Begin
	Set @vchCommand = 'Select'
	Set @vchCommand = @vchCommand + ' * From ' + @vchNombreObjname + ' '
End
Else
Begin
	Set @vchCommand = 'Select'
	Set @vchCommand = @vchCommand + ' * From ' + @vchNombreBaseDatos + '..' + @vchNombreObjname + ' '
End
SET NOCOUNT ON

-- Si sólo pasan un número 
If (@filtro = '' And @campo = '' And IsNumeric(@vchNombreObjname) = 1)
Begin
	Set @vchCommand = 'Select * From Constant Where Id = ' + @objname + char(13) + char(10) + char(13) + char(10)
	Create Table #group ( groupid int )
	Insert into #group
	Exec ('Select Top 1 ConstantGroupId From ConstantGroupConstant Where ConstantId = ' + @objname)
	Select Top 1 @groupid = groupid from #group
	Set @vchCommand = @vchCommand + 'Select c.* From ConstantGroupConstant cgc, Constant c where cgc.ConstantId = c.Id And cgc.ConstantGroupId = ' + Cast(@groupid as nvarchar)
End

--Revisar si el nombre correspone a una base de datos
If exists ( Select * From master..sysdatabases Where name = @vchNombreObjname )
Begin
	Set @vchCommand = 'Use ' + @vchNombreObjname
End

If @filtro <> ''		--Se proporcionó un filtro
Begin
	if @campo = ''	--pero No se indicó número ni nombre de campo
	Begin
		--Adquiero el primer nombre de campo con llave primaria (Si y sólo si Si es tabla):
		If @sysobj_type in ('S ','U ')		-- Tabla
		Begin
			--Tomo el primer campo de la llave principal			
			If @vchNombreBaseDatos is null or @vchNombreBaseDatos = ''
			Begin
				Insert into #helpIndex
				Exec ('sp_helpindex ''' + @vchNombreObjname + '''')
			End
			Else
			Begin
				Insert into #helpIndex
				Exec ('sp_helpindex ''' + @vchNombreBaseDatos + '..' + @vchNombreObjname + '''')
			End
			-- Adquiero el primer campo de la llave primaria (si existe)
			Select @columna = Case CharIndex(',', index_keys) When 0 Then index_keys Else Left(index_keys, CharIndex(',', index_keys) - 1) End
			From #helpIndex
			Where index_name like 'PK_%'

			If @columna IS NULL	-- Si no existe, tomo el primer campo de la tabla
			Begin
				If @vchNombreBaseDatos is null or @vchNombreBaseDatos = ''
				Begin
					-- Tomo el nombre del campo número 1 de la tabla @objname
					Select @columna = c.name
					From SysObjects o, SysColumns c
					Where o.id = object_id(@objname)
					And o.id = c.id
					And c.colid = 1
				End
				Else--Si se esta enviando la base de datos
				Begin
					Set @vchQuery = 'Select c.name ' + char(13)
					Set @vchQuery = @vchQuery + 'From ' + @vchNombreBaseDatos + '..' + 'SysObjects o, ' + @vchNombreBaseDatos + '..' + 'SysColumns c ' + char(13)
					Set @vchQuery = @vchQuery + 'Where o.id = object_id(' + char(39) + @vchNombreBaseDatos + '..' + @vchNombreObjname + char(39) + ') ' + char(13)
					Set @vchQuery = @vchQuery + 'And o.id = c.id ' + char(13)
					Set @vchQuery = @vchQuery + 'And c.colid = 1 ' + char(13)
					
					Insert into #tmpColumna ( vchColumna )
					exec ( @vchQuery )
					If exists ( Select * From #tmpColumna )
					Begin
						Select @columna = vchColumna From #tmpColumna
					End
				End
			End
		End
		Else If @sysobj_type in ('V ')		-- Vista (no hay llave primaria)
		Begin
			If @vchNombreBaseDatos is null or @vchNombreBaseDatos = ''
			Begin
				-- Tomo el nombre del campo número 1 de la tabla @objname
				Select @columna = c.name
				From SysObjects o, SysColumns c
				Where o.id = object_id(@objname)
				And o.id = c.id
				And c.colid = 1
			End
			Else
			Begin
				Set @vchQuery = 'Select c.name ' + char(13)
				Set @vchQuery = @vchQuery + 'From ' + @vchNombreBaseDatos + '..' + 'SysObjects o, ' + @vchNombreBaseDatos + '..' + 'SysColumns c ' + char(13)
				Set @vchQuery = @vchQuery + 'Where o.id = object_id(' + char(39) + @vchNombreBaseDatos + '..' + @vchNombreObjname + char(39) + ') ' + char(13)
				Set @vchQuery = @vchQuery + 'And o.id = c.id ' + char(13)
				Set @vchQuery = @vchQuery + 'And c.colid = 1 ' + char(13)
				
				Insert into #tmpColumna ( vchColumna )
				exec ( @vchQuery )
				If exists ( Select * From #tmpColumna )
				Begin
					Select @columna = vchColumna From #tmpColumna
				End
			End
		End
	End	
	Else	-- Se indicó un campo para filtrar
	Begin
		-- FEDE: Comprobar si existe columna
		If IsNumeric(@campo) = 1			-- Se indicó NUMERO de campo
			-- Necesito el nombre del campo número @campo
			Select @columna = c.name
			From SysObjects o, SysColumns c
			Where o.id = object_id(@objname)
			And o.id = c.id
			And c.colid = Convert(SmallInt, @campo)
		Else							-- Se indicó Nombre de campo
			Set @columna = @campo
	End
	Set @vchCommand = @vchCommand + 'Where ' + @columna + ' '
	If IsNumeric(@filtro) = 0				-- No es un número, poner LIKE comillas
		Set @vchCommand = @vchCommand + 'LIKE ''%' + @filtro + '%'' '
	Else
		Set @vchCommand = @vchCommand + '= ''' + @filtro + ''' ' 
End
Print @vchCommand + char(13) + char(10) + char(13) + char(10)
SET NOCOUNT OFF
EXECUTE (@vchCommand)
GO

-- Función que partir de una tabla y un ID de indice de la misma
-- devuelve todos los campos involucrados en el índice entre paréntesis y separados por coma
If exists ( select * from sysobjects where name = 'sp_ppinCamposIndice' )
	Drop Function sp_ppinCamposIndice
GO
Create Function sp_ppinCamposIndice
(
	@vchDbName varchar(128),
	@vchTabla sysname,
	@indid int
)
Returns Varchar(512)
As 
/* Federico Colombo */
Begin
	-- Función que partir de una tabla y un ID de indice de la misma
	-- devuelve todos los campos involucrados entre paréntesis y separados por coma
	Declare @ret varchar(512), @nv nvarchar(128), @i int
	Select @ret = '(', @i = 1
	
	Set @nv = index_col(@vchDbName + '..' + @vchTabla, @indid, @i)	
	While not @nv is null
	Begin
		Set @ret = @ret + @nv + ', '

		Set @i = @i + 1
		Set @nv = index_col(@vchDbName + '..' + @vchTabla, @indid, @i)	
	End

	Set @ret = Left(@ret, len(@ret) - 1) + ')'
	return @ret
End 
GO


-- Función que dado un tipo (de datos) y su longitud devuelve el texto que lo describe
If exists ( select * from sysobjects where name = 'sp_ppinTipoLongitud' )
	Drop Function sp_ppinTipoLongitud
GO
create Function sp_ppinTipoLongitud
(
	@xtype int,
	@length int,
	@isnullable int
)
Returns Varchar(512)
As 

/* Federico Colombo */
Begin
	-- Función que a partir de un tipo de datos y una logitud, devuelve el texto del tipo.
	-- Por ejemplo: para xtype=varchar y length=10 devolverá "varchar(10)"
	Declare @ret varchar(512)
	Set @ret = ''

	Select @ret = Type_Name(@xtype) +
	Case When Type_Name(@xtype) in ('varchar', 'char') Then 
			Case When @length = -1 then '(max)' else '(' + Convert(varchar, @length) + ')' end 
		 When Type_Name(@xtype) in ('nvarchar', 'nchar') Then
			Case When @length = -1 then '(max)' else '(' + Convert(varchar, @length/2) + ')' end 
		 Else '' End + ' ' +
	Case @isnullable When 1 Then 'NULL' Else 'NOT NULL' End
	
	Return @ret
End

GO

-- Devuelve las llaves foráneas de una tabla especificada
If exists ( select * from sysobjects where name = 'sp_ppinScriptLlavesForaneas' )
	Drop Procedure sp_ppinScriptLlavesForaneas
GO
Create Procedure sp_ppinScriptLlavesForaneas
(
	@vchTabla sysname,
	@vchResultado varchar(8000) output
)
AS 
/* Federico Colombo */
Begin

	DECLARE @tmpFK table(
		TablaF sysname,
		TablaR sysname,
		ColF sysname,
		ColR sysname,
		FKName sysname)

	-- obtengo las llaves foraneas en @vchForeign
	Declare @vchForeign varchar(8000), @FKName sysname, @vchColumnasF varchar(4000), @vchColumnasR varchar(4000), @ColF sysname, @ColR sysname
	Declare @vchTemp varchar(1000), @TablaR sysname

	Insert into @tmpFK
	Select TablaF.name AS TablaF, TablaR.name AS TablaR, ColF.name AS ColF, ColR.name AS ColR, ofk.name AS FKName
	From sysforeignkeys fk, sysobjects ofk, sysobjects TablaF, sysobjects TablaR, 
	syscolumns ColF, syscolumns ColR
	Where TablaF.name = @vchTabla
	And ofk.id = fk.constid
	And TablaF.id = fk.fkeyid
	And TablaR.id = fk.rkeyid
	And ColF.id = TablaF.id And ColF.colid = fk.fkey
	And ColR.id = TablaR.id And ColR.colid = fk.rkey
	order by FKName

	Set @vchForeign = ''
	While Exists ( Select * From @tmpFK )
	Begin
		Select Top 1 @FKName = FKName From @tmpFK
		Set @vchColumnasF = ''
		Set @vchColumnasR = ''
		While Exists ( Select * From @tmpFK Where FKName = @FKName )
		Begin
			Select Top 1 @ColF = ColF, @ColR = ColR, @TablaR = TablaR From @tmpFK Where FKName = @FKName
			Delete From @tmpFK Where ColF = @ColF And ColR = @ColR And TablaR = @TablaR And FKName = @FKName
			Set @vchColumnasF = @vchColumnasF + @ColF + ', '
			Set @vchColumnasR = @vchColumnasR + @ColR + ', '
		End
		
		Set @vchColumnasF = LEFT(@vchColumnasF, LEN(@vchColumnasF) - 1)
		Set @vchColumnasR = LEFT(@vchColumnasR, LEN(@vchColumnasR) - 1)
		Set @vchTemp = 'Constraint ' + @FKName + ' Foreign Key (' + @vchColumnasF + ') '
		Set @vchTemp = @vchTemp + 'References ' + @TablaR + ' (' + @vchColumnasR + ')'
		Set @vchForeign = @vchForeign + char(9) + @vchTemp + ',' + char(13) 
	End

	Select @vchResultado = Case When Len(@vchForeign) >=2 Then Left(@vchForeign, Len(@vchForeign) - 2) Else @vchForeign End
End
GO


-- Genera el script del create table de una tabla dada
If exists ( select * from sysobjects where name = 'sp_ppinScriptTabla' )
	Drop Procedure sp_ppinScriptTabla
GO
create Procedure sp_ppinScriptTabla
(
	@vchTabla sysname
)
AS
/* Federico Colombo */
Set nocount on

Declare @table as table (Linea varchar(8000))

-- Obtengo las foreign keys
Declare @foreign varchar(8000)
Exec sp_ppinScriptLlavesForaneas @vchTabla, @foreign output

--Create table
Insert Into @table (Linea)
Select 'Create ' + 
Case o.xtype When 'U' Then 'Table' When 'P' Then 'Procedure' Else '??' End + ' ' +
@vchTabla + char(13) + '('
From sysobjects o
Where o.name = @vchTabla

-- Obtengo campos
Insert Into @table (Linea)
Select char(9) + c.name + ' ' +									-- Nombre
dbo.sp_ppinTipoLongitud(t.xtype, c.length, c.isnullable) +			-- Tipo(longitud)
Case When c.colstat & 1 = 1										-- Identity (si aplica)
	Then ' Identity(' + convert(varchar, ident_seed(@vchTabla)) + ',' + Convert(varchar, ident_incr(@vchTabla)) + ')' 
	Else '' 
End + 
Case When not od.name is null									-- Defaults (si aplica)
	Then ' Constraint ' + od.name + ' Default ' + case when Left(cd.text, 2) = '((' And RIGHT(cd.text, 2) = '))' then SUBSTRING(cd.text, 2, LEN(cd.text) - 2) else cd.text end
	Else ''
End + ', '
from sysobjects o, syscolumns c
LEFT OUTER JOIN sysobjects od On od.id = c.cdefault LEFT OUTER join syscomments cd On cd.id = od.id, 
systypes t
where o.id = object_id(@vchTabla)
and o.id = c.id
and c.xtype = t.xtype
and t.xtype = t.xusertype
order by c.colid


-- Obtengo PKs y UKs
Insert Into @table (Linea)
select char(9) + 'Constraint ' + o.name + ' ' +
Case o.xtype When 'PK' Then 'Primary Key' Else 'Unique' End + ' ' +
dbo.sp_ppinCamposIndice (db_name(), @vchTabla, i.indid) + ', '
from sysobjects o, sysindexes i
where o.parent_obj = object_id(@vchTabla)
and o.xtype in ('PK','UQ')
and i.id = o.parent_obj
and o.name = i.name

-- Obtengo Check constraints
Insert Into @table (Linea)
select char(9) + 'Constraint ' + o.name + ' Check ' + c.text + ', '
from sysobjects o, syscomments c
where o.parent_obj = object_id(@vchTabla)
and o.xtype in ('C')
and o.id = c.id

Insert Into @table (Linea)
Select @foreign

Insert Into @table (Linea)
Select ')'

Select Linea From @table
Set nocount off
GO





If exists ( Select * From sysobjects Where name = 'SP_ppinAddDrop_ForeignKeys' ) 
	Drop procedure SP_ppinAddDrop_ForeignKeys
GO

Create Procedure SP_ppinAddDrop_ForeignKeys (
	@vchTabla varchar(800),
	@tiTipo tinyint = 0
)
AS
/* Federico Colombo */
/*
** Nombre:					SP_CreateDrop_ForeignKeys
** Propósito:				Genera automáticamente un script con los alter table (drop o add) de los constraints
**						que hacen referencia (foránea) a la tabla especificada
** Parámetros:				@vchTabla		Tabla a la que HACEN referencia los constraints
**						@tiTipo		0: Hace el ADD
**									1: Hace el DROP
**
** Dependencias:				
**
** Fecha creación:			23/11/2005
** Autor creación:			FDCG
** csd creación: 			
** Fecha modificación:
** Autor modificacion:
** csd modificación:
** Compatibilidad:			1.75
** Revision:				1
*/
Set nocount on
Create Table #tempConstraints		--Tabla que contiene todos los IDs de los constraints (FK) que referencian a algún campo de @vchTabla
(
	constid int not null,
	tiUsado tinyint not null
)

Create Table #tempColumnas		--Tabla que contiene (una vez por cada constID) las tabla y los campos a los que referencia
(
	TablaDesde sysname not null,
	TablaHasta sysname not null,
	ColumnaDesde sysname not null,
	ColumnaHasta sysname not null,
	tiUsado tinyint not null
)

--Declare @vchTabla varchar(200)
--Set @vchTabla = 'ACFDEPE1'

Declare @constid int, @vchCreate varchar(4000), @vchDrop varchar(1000)
Declare @TablaF varchar(100), @TablaR varchar(100)
Declare @ColF varchar(100), @ColR varchar(100)
Declare @CamposIzquierda varchar(500), @CamposDerecha varchar(500)

-- Lleno la temporal de constraints 
Insert #tempConstraints
Select r.constid, 0
from sysreferences r, sysobjects o
where o.name = @vchTabla
And rkeyid = o.id
order by 1

If not exists (select * from #tempConstraints)
	If object_id(@vchTabla) Is Null 
		Print 'La tabla [' + @vchTabla + '] no existe en [' + db_name() + ']'
	Else
		Print 'La tabla [' + @vchTabla + '] no tiene referencias foráneas'
Else
	While exists (Select * From #tempConstraints Where tiUsado = 0)
	Begin
		Select Top 1 @constid = constid From #tempConstraints Where tiUsado = 0
	
		Set @CamposIzquierda = ''
		Set @CamposDerecha = ''
		Set @vchCreate = ''
		Set @vchDrop = ''
	
		-- Lleno la temporal de columnas	
		Insert #tempColumnas (TablaDesde, TablaHasta,  ColumnaDesde, ColumnaHasta, tiUsado)
		Select TablaF.name, TablaR.name, ColF.name, ColR.name, 0
		From sysforeignkeys fk, sysobjects ofk, sysobjects TablaF, sysobjects TablaR, 
		syscolumns ColF, syscolumns ColR
		Where ofk.name = object_name(@constid)
		And ofk.id = fk.constid
		And TablaF.id = fk.fkeyid
		And TablaR.id = fk.rkeyid
		And ColF.id = TablaF.id And ColF.colid = fk.fkey
		And ColR.id = TablaR.id And ColR.colid = fk.rkey

--		Select * from #tempColumnas

		While Exists (Select * From #tempColumnas Where tiUsado = 0)
		Begin
			Select Top 1 @ColF = ColumnaDesde, @ColR = ColumnaHasta
			From #tempColumnas
			Where tiUsado = 0
			
			Set @CamposIzquierda = @CamposIzquierda + @ColF + ', '
			Set @CamposDerecha = @CamposDerecha + @ColR + ', '
		
			Update #tempColumnas
			Set tiUsado = 1
			Where ColumnaDesde = @ColF And ColumnaHasta = @ColR
		End	

		Set @CamposIzquierda = LEFT(@CamposIzquierda, LEN(@CamposIzquierda) - 1)
		Set @CamposDerecha = LEFT(@CamposDerecha, LEN(@CamposDerecha) - 1)

		Select Top 1 @TablaF = TablaDesde, @TablaR = TablaHasta From #tempColumnas

		Set @vchCreate = 'If Not Exists (Select * From SysObjects Where Name = ''' + object_name(@constid) + ''') '
		Set @vchCreate = @vchCreate + 'And object_id(''' + @TablaF + ''') is not null ' + char(13)
		Set @vchCreate = @vchCreate + char(9) + 'Alter Table ' + @TablaF + char(13) 
		Set @vchCreate = @vchCreate + char(9) + char(9) + 'Add Constraint ' + object_name(@constid) + ' Foreign Key' + char(13)
		Set @vchCreate = @vchCreate + char(9) + char(9) + '(' + @CamposIzquierda + ') '
		Set @vchCreate = @vchCreate + 'References ' + @TablaR 
		Set @vchCreate = @vchCreate + ' (' + @CamposDerecha + ')'
	
		Set @vchDrop = 'If Exists (Select * From SysObjects Where Name = ''' + object_name(@constid) + ''') ' + char(13)
		Set @vchDrop = @vchDrop + char(9) + 'Alter Table ' + @TablaF + char(13)
		Set @vchDrop = @vchDrop + char(9) + char(9) + 'Drop Constraint ' + object_name(@constid)

		If @tiTipo = 1
			Print @vchDrop
		else 
			Print @vchCreate			

		Update #tempConstraints
		Set tiUsado = 1
		Where constid = @constid
	
		Delete #tempColumnas
		Where tiUsado = 1
	End

Set nocount off
GO



If exists ( Select * From sysobjects Where name = 'SP_ppinGenera_Insert' ) 
	Drop procedure SP_ppinGenera_Insert
GO

Create Procedure SP_ppinGenera_Insert (
	@vchTabla varchar(200),
	@vchWhere varchar(8000) = '',
	@tiTipo tinyint = 0,
	@tiTipoResultado tinyint = 0
)
AS
/* Federico Colombo */
/*
** Nombre:					sp_Genera_Insert
** Propósito:				Genera el script que inserta los datos de una tabla
** Parámetros:				@vchTabla	Nombre de la tabla
**						@vchWhere	(opcional) filtro para el where
**						@tiTipo	0: Genera el if exists DELETE->INSERT
**								1: Genera el if not exists INSERT
**								2: Genera el if exists UPDATE else INSERT
**						@tiTipoResultado Tipo de resultado
**								0:	El resultado se arroja con prints, se informa al usuario en caso de errores o llaves primarias
**								1:	El resultado se arrojo con select para que se posible atrapar el resultado en insert a alguna tabla
**										el resultado siempre tendra un unico campo, se eliminan los mensajes informativos
**
** Dependencias:				
**
** Fecha creación:			23/11/05
** Autor creación:			FDCG
*/

Set Nocount On

Declare @tiEsCampoText tinyint
Declare @vchBaseDatos varchar(100)
Declare @vchBaseDatosConPunto varchar(100)
Declare @vchBaseDatosConTabla varchar(100)
Declare @iPosicionNombreTabla int
Declare @nvchQuery nvarchar(4000)
Declare @nvchParametros nvarchar(512)
Declare @iCantRegistro int
Declare @vchBaseDatosActual varchar(100)
Declare @Enter char(2)
Declare @vchEnter nvarchar(20)
Declare @tiLlavePrimaria tinyint 
Select @vchBaseDatosActual = db_name()
Select @Enter = char(13) + char(10)
Set @vchEnter = 'char(13) + char(10)' --Donde se quiere que el script retornado haga enter's
create table #tmpIndex
(
	TABLE_QUALIFIER	sysname NOT NULL,
	TABLE_OWNER		sysname NOT NULL,
	TABLE_NAME		sysname NOT NULL,
	COLUMN_NAME		sysname NOT NULL,
	KEY_SEQ		smallint NOT NULL,
	PK_NAME		sysname  NOT NULL
)

Create Table #Campos 
(
	vchNombre varchar(60) not null,		-- Nombre de la columna
	tiLlavePrimaria tinyint not null,		-- Indica si es llave primaria
	tiEsCadena tinyint not null,			-- Indica si el campo es una cadena (varchar, nvarchar, etc)
	tiUsado tinyint not null,			-- Campo para hacer ciclos while
	tiEsTimeStamp tinyint not null,		-- Indica si es del tipo TimeStamp (para poner la palabra NULL en el values)
	tiAdmiteNulos tinyint not null,		-- Indica si el campo admite nulos
	tiEsFecha tinyint not null,
	tiEsCampoText tinyint not null --Indica que es un campo tipo text, para no utilizar el replace

)
Create table #tmpTexto
(
	vchTexto varchar(8000)
)

--Revisar si en el nombre de la table trae concatenada la base de datos
If @vchTabla like '%..%'
Begin
	Select @vchBaseDatosConTabla= @vchTabla,
			@iPosicionNombreTabla = PATINDEX('%..%', @vchTabla)

	Select @vchBaseDatosConPunto = substring( @vchBaseDatosConTabla, 1 , @iPosicionNombreTabla + 1) --Base de datos con puntos
	Select @vchBaseDatos = substring( @vchBaseDatosConTabla, 1 , @iPosicionNombreTabla - 1) 
	
	Select @vchTabla = substring( @vchBaseDatosConTabla, @iPosicionNombreTabla + 2, 200)
End
Else
Begin
	Set @vchBaseDatosConTabla = @vchTabla
	Set @vchBaseDatos = ''
	Set @vchBaseDatosConPunto = ''
End

Set @nvchQuery = N'Select @iCantRegistro = count(*) From ' + @vchBaseDatosConPunto + 'sysobjects o ' 
Set @nvchQuery = @nvchQuery + N'Where o.name = ''' + @vchTabla + ''' and xtype = ''' + 'u' + ''''

Set @nvchParametros = N'@iCantRegistro int output ' 
Exec sp_executesql @nvchQuery, @nvchParametros, @iCantRegistro = @iCantRegistro output

If @iCantRegistro <= 0
Begin
	if @tiTipoResultado = 0
	Begin
		Print 'La tabla ' + @vchTabla + ' no existe'
	End
	Goto Fin
End


If @vchBaseDatosActual <> @vchBaseDatos And @vchBaseDatos <> ''
Begin
	Set @nvchQuery = N'' + @vchBaseDatosConPunto
	Set @nvchQuery = @nvchQuery + N'sp_pkeys ''' + @vchTabla + ''''

	Insert into #tmpIndex
	Exec (@nvchQuery)
End
Else
Begin
	Insert into #tmpIndex
	Exec ('sp_pkeys ''' + @vchTabla + '''')
End


--Inserto todos los campos de la tabla en la temporal
Set @nvchQuery = N'Select c.name, 0, ' + @Enter
Set @nvchQuery = @nvchQuery + N'Case When c.xtype IN ( 35, 36, 98, 99, 240, 165, 167, 173, 175, 231, 239, 241, 231 ) Then ' + @Enter --35->(ntext, text), 47->(char, nchar), 39(nvarchar, varchar, sysname, sql_variant) 
Set @nvchQuery = @nvchQuery + N'	1 Else 0 End, ' + @Enter
Set @nvchQuery = @nvchQuery + N'0, Case When c.xtype = 189 Then 1 Else 0 End, ' + @Enter
Set @nvchQuery = @nvchQuery + N'c.isnullable, ' + @Enter
Set @nvchQuery = @nvchQuery + N'Case When c.xtype IN ( 40, 41, 42, 58, 61 ) Then 1 Else 0 End, ' + @Enter -- date, time, datetime2, smalldatetime, datetime
Set @nvchQuery = @nvchQuery + N'Case When c.xtype IN ( 35, 99, 241 ) Then ' + @Enter -- (ntext, text, xml)
Set @nvchQuery = @nvchQuery + N'	1 Else 0 End ' + @Enter
Set @nvchQuery = @nvchQuery + N'From ' + @vchBaseDatosConPunto + 'sysobjects o, ' + @vchBaseDatosConPunto + 'syscolumns c ' + @Enter
Set @nvchQuery = @nvchQuery + N'Where o.id = c.id ' + @Enter
Set @nvchQuery = @nvchQuery + N'And o.name = ''' + @vchTabla + ''' ' + @Enter
Set @nvchQuery = @nvchQuery + N'And c.name not in (''CreatedDate'', ''CreatedBy'', ''LastUpdatedDate'', ''LastUpdatedBy'') '
Set @nvchQuery = @nvchQuery + N'And o.type = ''U''' + @Enter
Set @nvchQuery = @nvchQuery + N'Order by c.colid ' + @Enter
--Select @nvchQuery as nvchQuery

Insert #Campos (vchNombre, tiLlavePrimaria,
tiEsCadena,
tiUsado, tiEsTimeStamp,
tiAdmiteNulos,
tiEsFecha,
tiEsCampoText )
execute (@nvchQuery)

--Actualizo el valor de tiLlavePrimaria, para los que pertenecen al PK
Update #Campos
Set tiLlavePrimaria = 1
From #tmpIndex tmp
Where tmp.COLUMN_NAME = vchNombre

Declare @vchReturn varchar(8000), @vchWhere1 varchar(1000), @vchInsert varchar(1000), @vchValues varchar(8000)
Declare @vchCamposComa varchar(1000)

Declare @vchUpdate1 varchar(8000), @vchUpdate2 varchar(8000), @vchTemp varchar(8000)
Declare @esFecha tinyint
Select @vchUpdate1 = '', @vchUpdate2 = ''


Declare @Columna nvarchar(128), @esCadena tinyint, @tiEsTimeStamp tinyint
Set @vchReturn = ''
Set @vchCamposComa = ''

If not exists (Select * from #tmpIndex)
-- No hay ninguna llave primaria, las marco a todas como primarias (las que no aceptan nulos y son distintas de timestamp
Begin
	if @tiTipoResultado = 0
	Begin
		Print 'Tabla sin llave primaria, se usarán como llave primaria todos los campos que no admitan nulos' + @Enter + @Enter
	End
	Update #Campos
	Set tiLlavePrimaria = 1
	Where tiLlavePrimaria = 0 And tiAdmiteNulos = 0 And tiEsTimeStamp = 0
End

-- Actualizo [nombre]
Update #Campos
Set vchNombre = '[' + vchNombre + ']'

-- Muestro la llave primaria
While exists (Select * From #Campos Where tiUsado = 0 And tiLlavePrimaria = 1)
Begin
	Select Top 1 @Columna = vchNombre From #Campos Where tiUsado = 0 And tiLlavePrimaria = 1
	
	Set @vchReturn = @vchReturn + @Columna + ', '

	Update #Campos
	Set tiUsado = 1
	Where vchNombre = @Columna
	And tiLlavePrimaria = 1
End
Set @vchReturn = LEFT(@vchReturn, LEN(@vchReturn) - 1)	--Quito la última coma
if @tiTipoResultado = 0
Begin
	Print 'Llave primaria de la tabla [' + @vchTabla + ']: ' + @vchReturn
End

Set @vchReturn = ''
Update #Campos
Set tiUsado = 0

----------LLENO EL WHERE
Set @vchWhere1 = 'Where '
While exists (Select * from #Campos where tiLlavePrimaria = 1 And tiUsado = 0 And tiEsTimeStamp = 0)
Begin
	Select Top 1 @Columna = vchNombre, @esCadena = tiEsCadena, @tiEsCampoText = tiEsCampoText
	From #Campos where tiLlavePrimaria = 1 And tiUsado = 0 And tiEsTimeStamp = 0

	Set @vchWhere1 = @vchWhere1 + @Columna + ' = '
	If @esCadena = 1
		-- Hay que poner comillas
		Begin
			If @tiEsCampoText = 1
			Begin
				Set @vchWhere1 = @vchWhere1 + ''''''' + ' + @Enter + 'Convert(nvarchar(max), '+ @Columna + ') + '''''' '
			End
			Else
			Begin
				Set @vchWhere1 = @vchWhere1 + ''''''' + ' + @Enter + 'Convert(nvarchar(max), Replace(' + @Columna + ', '''''''', '''''''''''')) + '''''' '
			End

			Set @vchWhere1 = @vchWhere1 + ' AND '		
		End
	Else
		-- Sin comillas
		Begin
			--Set @vchWhere1 = @vchWhere1 + ''' + Convert(VarChar(8000),' + @Columna + ') + '
			Set @vchWhere1 = @vchWhere1 + ''' + ' + @Enter + 'Convert(nvarchar(max),' + @Columna + ') + '
			Set @vchWhere1 = @vchWhere1 + ''' AND '
		End

	Update #Campos
	Set tiUsado = 1
	Where vchNombre = @Columna
End

-- Quito el último AND 
If @esCadena = 1		--Si el último fue cadena
	Set @vchWhere1 = LEFT(@vchWhere1, LEN(@vchWhere1) - 5) + ''''
Else
	Set @vchWhere1 = LEFT(@vchWhere1, LEN(@vchWhere1) - 7)

-------------- LLENO EL INSERT
-- Lleno la variable @vchCamposComa con los campos de la tabla separados por coma
Update #Campos
Set tiUsado = 0
While exists (Select * from #Campos Where tiUsado = 0)
Begin
	Select Top 1 @Columna = vchNombre
	From #Campos
	Where tiUsado = 0

	Set @vchCamposComa = @vchCamposComa + @Columna + ', '

	Update #Campos
	Set tiUsado = 1
	Where vchNombre = @Columna
End
--Quito la última coma
Set @vchCamposComa = LEFT(@vchCamposComa, LEN(@vchCamposComa) - LEN(', ')) 

Set @vchInsert = 'Insert Into ' + @vchTabla + '(' + @vchCamposComa + ')'

-------------- LLENO EL VALUES
Update #Campos
Set tiUsado = 0
Set @vchValues = 'Values ('''
While exists (Select * from #Campos Where tiUsado = 0)
Begin
	Select Top 1 @Columna = vchNombre, @esCadena = tiEsCadena, @tiEsTimeStamp = tiEsTimeStamp, @esFecha = tiEsFecha,
	@tiEsCampoText = tiEsCampoText, @tiLlavePrimaria = tiLlavePrimaria
	From #Campos
	Where tiUsado = 0

	If @esCadena = 1 Or @esFecha = 1
	Begin
		--Poner comillas
		Begin
			If @tiEsCampoText = 1
			Begin
				Set @vchTemp = ' + ' + @Enter + 'Case When ' + @Columna + ' Is Null Then ''Null'' Else ''N'''''' + Convert(nvarchar(max), ' + @Columna + ') + '''''''' End + '', '''
			End
			Else --No campo tipo text
			Begin
				Set @vchTemp = ' + ' + @Enter + 'Case When ' + @Columna + ' Is Null Then ''Null'' Else ''N'''''' + Convert(nvarchar(max), Replace(' + @Columna + ','''''''','''''''''''')) + '''''''' End + '', '''
			End
			Set @vchValues = @vchValues + @vchTemp
		End
	End
	Else
	Begin
		If @tiEsTimeStamp = 1 
		Begin
			Set @vchTemp = ' + ' + @Enter + '''Null'' + '', '''
			Set @vchValues = @vchValues + @vchTemp
			-- De los timestamps no hago update
		End
		Else
		Begin
			Set @vchTemp = ' + ' + @Enter + 'Case When ' + @Columna + ' Is Null Then ''Null'' Else Convert(nvarchar(max), ' + @Columna + ') End + '', '''
			Set @vchValues = @vchValues + @vchTemp
		End
	End
	
	-- If es la ultima columna, qutar la coma del final
	if ( Select count(1) from #Campos Where tiUsado = 0 ) = 1
	Begin
		Set @vchTemp = LEFT(@vchTemp, LEN(@vchTemp) - 6)
	End
	
	-- Armar el update
	If @tiLlavePrimaria = 0
	Begin
		If len(@vchUpdate1) + len(@vchTemp) <= 7500 
		Begin
			Set @vchUpdate1 = @vchUpdate1 + '''' + @Columna + ' = ''' + @vchTemp + ' + ' + @vchEnter + ' + char(9) + '
		End
		Else 
		Begin
			Set @vchUpdate2 = @vchUpdate2 + '''' + @Columna + ' = ''' + @vchTemp + ' + ' + @vchEnter + ' + char(9) + '
		End
	End
	
	Update #Campos
	Set tiUsado = 1
	Where vchNombre = @Columna
End

--Quito la última coma
If @esCadena = 1
Begin
	Set @vchValues = LEFT(@vchValues, LEN(@vchValues) - 6) + '+ '')'''      -- 8
	If len(@vchUpdate1) + len(@vchTemp) <= 7500 
	Begin
		Set @vchUpdate1 = LEFT(@vchUpdate1, LEN(@vchUpdate1) - 34) 
	End
	Else
	Begin
		Set @vchUpdate2 = LEFT(@vchUpdate2, LEN(@vchUpdate2) - 34) 
	End
End
Else
	If @tiEsTimeStamp = 1
	Begin
		Set @vchValues = LEFT(@vchValues, LEN(@vchValues) - 3) + ')'''		
	End
	Else
	Begin
		Set @vchValues = LEFT(@vchValues, LEN(@vchValues) - 6) + '+ '')'''
		If len(@vchUpdate1) + len(@vchTemp) <= 7500 
		Begin
			Set @vchUpdate1 = LEFT(@vchUpdate1, LEN(@vchUpdate1) - 34) 	
		End
		Else
		Begin
			select len(@vchUpdate1), LEN(@vchUpdate2)
			Set @vchUpdate2 = LEFT(@vchUpdate2, LEN(@vchUpdate2) - 34) 	
		End
	End

--FINAL
if @tiTipo = 0			-- Generar el if exists->delete->Insert
	Begin
		Set @vchReturn = 'Select ''If Exists (Select * From ' + @vchTabla + ' ' + @vchWhere1 + '+ '')'' + ' + @vchEnter + ' + Char(9) + ' + @Enter + '''Delete ' + @vchTabla
		Set @vchReturn = @vchReturn + ' ' + @vchWhere1 + ' + ' + @Enter + '' + @vchEnter + ' + ''GO'' + ' + @vchEnter + ' + '
		Set @vchReturn = @vchReturn + @Enter + '''' + @vchInsert + ''' + ' + @vchEnter + ' + ' + @Enter + '''' + @vchValues + ' + ' + @Enter + '' + @vchEnter + ' + ''GO'' + ' + @vchEnter + ' ' + @Enter + 'From ' + @vchBaseDatosConPunto + @vchTabla 
	End
else if @tiTipo = 1		-- Generar el if not exists->Insert
	Begin
	 	Set @vchReturn = 'Select ''If Not Exists (Select * From ' + @vchTabla + ' ' + @vchWhere1 + '+ '')'' + Char(9) + ' + @Enter 
		Set @vchReturn = @vchReturn + ' + ' + @vchEnter + ' + char(9) + '
		Set @vchReturn = @vchReturn + @Enter + '''' + @vchInsert + ''' + ' + @vchEnter + ' + char(9) + ' + @Enter + '''' + @vchValues + ' + ' + @Enter + '' + @vchEnter + ' + ''GO'' + ' + @vchEnter + ' ' + @Enter + 'From ' + @vchBaseDatosConPunto + @vchTabla 
	End
else if @tiTipo = 2		-- Generar el if exists Insert else Update
	Begin
		-- En este caso, no alcanzan los 8000 caracteres que permite el query analizer como respuesta de un select, entonces hago prints parciales
		if @tiTipoResultado = 0 --resultado con prints
		Begin
			Print ''
			Print 'Select ''If Exists (Select * From ' + @vchTabla + ' ' + @vchWhere1 + '+ '')'' + ' + @vchEnter + ' + Char(9) + ' 
			Print '''Update ' + @vchTabla + @Enter + char(9) + 'Set ' + ''' + ' 
			Print @vchUpdate1 
			Print @vchUpdate2 + ' + ' + @vchEnter + ' + char(9) + ''' + @vchWhere1
			Print ' + ' + @vchEnter + ' + ''Else'' + ''' + @Enter + char(9) + @vchInsert + ''' + ' + @vchEnter + ' + char(9) + ''' + @vchValues 
			Print ' + ' + @Enter + '' + @vchEnter + ' + ''GO'' + ' + @vchEnter + ' + ' + @vchEnter + ' ' + @Enter + 'From ' + @vchBaseDatosConPunto + @vchTabla 
			If @vchWhere <> ''
				Print 'Where ' + @vchWhere
		End
		Else if @tiTipoResultado = 1 --resultado con selects
		Begin
			Insert into #tmpTexto
			Select ''

			Insert into #tmpTexto
			Select 'Select ''If Exists (Select * From ' + @vchTabla + ' ' + @vchWhere1 + '+ '')'' + ' + @vchEnter + ' + Char(9) + '

			Insert into #tmpTexto
			Select '''Update ' + @vchTabla + @Enter + char(9) + 'Set ' + ''' + '

			Insert into #tmpTexto
			Select @vchUpdate1  + @Enter

			Insert into #tmpTexto
			Select @vchUpdate2 + ' + ' + @vchEnter + ' + char(9) + ''' + @vchWhere1
			
			Insert into #tmpTexto
			Select ' + ' + @vchEnter + ' + ''Else'' + ''' + @Enter + char(9) + @vchInsert + ''' + ' + @vchEnter + ' + char(9) + ''' + @vchValues

			Insert into #tmpTexto
			Select ' + ' + @Enter + '' + @vchEnter + ' + ''GO'' + ' + @vchEnter + ' + ' + @vchEnter + ' ' + @Enter + 'From ' + @vchBaseDatosConPunto + @vchTabla

			If @vchWhere <> ''
			Begin
				Insert into #tmpTexto
				Select 'Where ' + @vchWhere + @Enter
			End

			Select *
			From #tmpTexto
		End
	End

If @vchWhere <> ''
	Set @vchReturn = @vchReturn + @Enter + 'Where ' + @vchWhere

if @tiTipo <> 2
	if @tiTipoResultado = 0 --resultado con prints
	Begin
		Print @vchReturn
	End
	Else if @tiTipoResultado = 1 --resultado con selects
	Begin
		Insert into #tmpTexto
		Select @vchReturn

		Select * from #tmpTexto
	End
Fin:
Set Nocount Off
GO

If exists ( Select * From sysobjects Where name = 'sp_longitud' ) 
	Drop procedure sp_longitud
GO

Create procedure sp_longitud(
@vchValor varchar(8000)
)
AS
Print len(@vchValor)
GO

If exists ( Select * From sysobjects Where name = 'sp_doc_comment' ) 
	Drop procedure sp_doc_comment
GO

Create procedure sp_doc_comment
AS
Begin
	Declare @now nvarchar(25) = convert(nvarchar, GetDate(), 103), @user nvarchar(100) = SYSTEM_USER
	Set @user = SUBSTRING(@user, CHARINDEX('\', @user) + 1, 100)

	Print '/*'
	Print '** Name:			'
	Print '** Purpose:		'		
	Print '** Parameters:	'				
	Print '** Dependencies: '				
	Print '** Errors:		'			
	Print '** Usage sample:	'			
	Print '** Return:		'
	Print '**	'
	Print '** Creation Date: ' + @now
	Print '** Creation User: ' + @user
	Print '** Revision:      0'
	Print '** '
	Print '** Changes history'
	Print '** ------------------------------------------------------------------'
	Print '** Date        User             Description'
	Print '**'
	Print '*/'
End
GO



If exists ( Select * From sysobjects Where name = 'sp_drop' ) 
	Drop procedure sp_drop
GO

Create procedure sp_drop(
@objeto varchar(100)
)
AS
Declare @tipoObjeto char(2), @vchCommand varchar(500)

If Substring(@objeto, 1, 1) = '#'
Begin
	-- Posible temporal, intento hacer el drop sin más
	Set @vchCommand = 'DROP TABLE ' + @objeto
	EXECUTE (@vchCommand)
	If @@error = 0
		Print @objeto + ' Eliminado'
	Return 0
End

Set @vchCommand = ''
Select @tipoObjeto = o.type From SysObjects o Where Name = @objeto
If @tipoObjeto IS NULL
BEGIN
	If object_id(@objeto) Is Null
		Print 'El objeto [' + @objeto + '] no existe en [' + db_name() + ']'
	else
		Print 'El objeto [' + @objeto + '] no es un objeto válido'
	Return -1
END

If @tipoObjeto = 'P' OR @tipoObjeto = 'X'	-- Store Procedure
		Set @vchCommand = @vchCommand + 'DROP PROCEDURE ' + @objeto
If @tipoObjeto = 'U' 				-- Tabla
		Set @vchCommand = @vchCommand + 'DROP TABLE ' + @objeto

EXECUTE (@vchCommand)
If @@error = 0
	Print @objeto + ' Eliminado'
Return 0
GO



If exists ( Select * From sysobjects Where name = 'sp_ppinNombreTablaTemp' ) 
	Drop procedure sp_ppinNombreTablaTemp
GO

Create Procedure sp_ppinNombreTablaTemp
(
	@vchTabla varchar(512)
)
AS
/*
** Nombre:				sp_ppinNombreTablaTemp
** Propósito:				Dado un nombre de tabla temporal (ej. #tmp) devuelve el nombre real de la tabla en tempdb
** Campos/Parámetros:		@vchTabla			Nombre de la tabla
**
** Dependencias:			?
**
** Fecha creación:			03-01-06
** Autor creación:			FDCG
*/
Declare @vchReal varchar(512)
If LEFT(@vchTabla, 1) <> '#'
	Begin
		Print @vchTabla
		Return
	End
Select @vchReal = convert(varchar(512),name) From tempdb..sysobjects where name like @vchTabla + '_%'
Print @vchReal
GO


-- SP que dada una tabla, devuelve un SELECT de la misma con las cláusula From y Where según sus llaves foráneas
If exists ( Select * From sysobjects Where name = 'sp_ppinSelectFromWhereForaneo' ) 
	Drop procedure sp_ppinSelectFromWhereForaneo
GO

Create Procedure sp_ppinSelectFromWhereForaneo
(
	@vchTabla varchar(100),
	@vchAliasTabla varchar(5) = 'A'
)
AS
/*
** Nombre:					sp_ppinSelectFromWhereForaneo
** Propósito:					SP que genera un Select * a partir de una tabla.
**							El select se genera con el From y el Where según las llaves foráneas de la tabla
** Campos:					@vchTabla: Tabla a la que se hará el select
**							@vchAliasTabla: Alias que tendrá la tabla en el select
** Dependencias: 				
**												
** Fecha creación:				17/Mayo/2007
** Autor creación:				FDCG
** Csd creación:				csd171
** Fecha modificación: 	
** Autor modificación: 	
** Csd modificación:			
** Compatibilidad:				1.75
** Revisión:					0
*/
Set nocount On
Declare @TablaR sysname, @ColF sysname, @ColR sysname, @vchAlias varchar(5)
Declare @vchFrom varchar(4000), @vchWhere varchar(4000), @iCont int, @iHayMas int

If not exists ( Select * From sysobjects where name = @vchTabla And xtype in ('U') )
Begin
	Set nocount Off
	Print 'La tabla ' + @vchTabla + ' no existe en [' + db_name() + ']'
	Return
End

If exists ( Select * From tempdb..sysobjects Where name like '#tmpForeign[_]%' ) 
	Drop table #tmpForeign

Create Table #tmpForeign
(
	iIdentity int not null identity (1,1),
	TablaF sysname,
	TablaR sysname,
	ColF sysname,
	ColR sysname,
	FKName sysname,
	vchAlias varchar(5),
	tiProceso tinyint 
)

Insert Into #tmpForeign (TablaF, TablaR, ColF, ColR, FKName, 
vchAlias, tiProceso)
Select TablaF.name, TablaR.name, ColF.name, ColR.name, ofk.name,
substring(TablaR.name, 1, 1) + substring(TablaR.name, 4, 1) , 0
From sysforeignkeys fk, sysobjects ofk, sysobjects TablaF, sysobjects TablaR, 
syscolumns ColF, syscolumns ColR
Where TablaF.name = @vchTabla
And ofk.id = fk.constid
And TablaF.id = fk.fkeyid
And TablaR.id = fk.rkeyid
And ColF.id = TablaF.id And ColF.colid = fk.fkey
And ColR.id = TablaR.id And ColR.colid = fk.rkey
order by Left(TablaR.name, 2)

Update t
Set vchAlias = Upper(vchAlias) + Cast(iIdentity As varchar)
From #tmpForeign t


If exists ( Select * From #tmpForeign Where tiProceso = 0 )
Begin
	Set @vchFrom = 'From ' + @vchTabla + ' ' + @vchAliasTabla + ', ' 
	Set @vchWhere = 'Where '
End
Else
Begin
	Print 'La tabla ' + @vchTabla + ' no tiene llaves foráneas'
	Return
End

Set @iCont = 0
While exists ( Select * From #tmpForeign Where tiProceso = 0 )
Begin
	Set @iCont = @iCont + 1
	Set @iHayMas = Case When (Select count(*) From #tmpForeign Where tiProceso = 0) > 1 Then 1 Else 0 End

	Select Top 1 @TablaR = TablaR, @ColF = ColF, @ColR = ColR, @vchAlias = vchAlias From #tmpForeign Where tiProceso = 0

	-- Armo el From 
	Select @vchFrom = @vchFrom + @TablaR + ' ' + @vchAlias  

	If @iHayMas = 1 
		Set @vchFrom = @vchFrom + ', '

	If @iCont = 3 And @iHayMas = 1
		Select @iCont = 0, @vchFrom = @vchFrom + char(13) + char(10)

	-- Armo el Where:	A.Campo = B.Campo
	Select @vchWhere = @vchWhere + @vchAliasTabla + '.' + @ColF + ' = ' + @vchAlias + '.' + @ColR

	If @iHayMas = 1 
		Set @vchWhere = @vchWhere + char(13) + char(10) + 'And '

	Update tmp Set tiProceso = 1 From #tmpForeign tmp Where TablaR = @TablaR And ColF = @ColF And ColR = @ColR And tiProceso = 0
End

If exists ( Select * From #tmpForeign Where tiProceso = 1 )
	Select 'Select * ' + char(13) + @vchFrom + ' ' + char(13) + @vchWhere
Else
	Select ''
Set nocount Off
GO


-- Procedimiento para generar el insert de los Errores del sistema enlace
If exists ( Select * From sysobjects Where name = 'sp_ppinInsertaObjetoError' ) 
	Drop procedure sp_ppinInsertaObjetoError
GO

Create Procedure sp_ppinInsertaObjetoError
(
	@vchNombreObjeto varchar(100) = '',
	@vchComentarioObjeto varchar(1024) = '',
	@iIdMensajeError int = 0,
	@vchMensajeError varchar(255) = '',
	@iIdTipoMensaje int = 5361,
	@tiEjecutaScript tinyint = 0
)
AS
/*
** Nombre:				sp_ppinInsertaObjetoError
** Propósito:				Insertar y devolver script de inserción de un error determinado a la tabla CatMensaje_ProcAlmacenado
** Campos:				@vchNombreObjeto: Nombre del objeto al que se le insertará el error
**						@vchComentarioObjeto: Comentario que tendrá el objeto en caso de no existir en CatGralObjeto
**						@iIdMensajeError: ID del mensaje de error (el ID que devuelve el objeto cuando ocurre el error)
**						@vchMensajeError: La descripción del mensaje de error (ej: 'la factura ya existe')
**						@iIdTipoMensaje: Tipo de mensaje (catconstante, 5360, 4), por defecto, Crítico
**						@tiEjecutaScript: Para indicar si además de generar el script, lo ejecuta (insert a catgralobjeto y/o CatMensaje_ProcAlmacenado)
** Fecha creación:			2/Agosto/2007
** Autor creación:			FDCG
** Csd creación:			csd172
** Fecha modificación: 		
** Autor modificación: 		
** Csd modificación:			
** Compatibilidad:			1.75
** Revisión:				0
*/
Declare @iError int, @iIdObjeto int, @siTipoObjeto int, @iIdTipoObjeto_CC int
Declare @vchScript varchar(4000)
Set @iError = 0

Set nocount on

If len(ltrim(rtrim(@vchNombreObjeto))) = 0 Or @iIdMensajeError = 0 Or @vchMensajeError = ''
Begin
	Print 'Favor de proporcionar los siguientes parámetros: ' + char(13) + char(10) + char(13) + char(10)
	Print '@vchNombreObjeto: Nombre del objeto al que se le insertará el error'
	Print '@vchComentarioObjeto: Comentario que tendrá el objeto en caso de no existir en CatGralObjeto'
	Print '@iIdMensajeError: ID del mensaje de error (el ID que devuelve el objeto cuando ocurre el error)'
	Print '@iIdTipoMensaje: Tipo de mensaje (catconstante, 5360, 4), por defecto, Crítico'
	Print '@tiEjecutaScript: Para indicar si además de generar el script, lo ejecuta (insert a catgralobjeto y/o CatMensaje_ProcAlmacenado)'
	Set @iError = -1
	Goto _Fin
End

-- Si existe el mensaje, envío error
If exists ( Select * From bd_sicyproh..CatMensaje_ProcAlmacenado Where iIdMensaje = @iIdMensajeError )
Begin
	Print 'WARNING: El mensaje con ID ' + convert(varchar, @iIdMensajeError) + ' ya existe en la tabla bd_sicyproh..CatMensaje_ProcAlmacenado' + char(13) + char(10) + char(13) + char(10)
	Set @tiEjecutaScript = 0
End

-- Si no existe el objeto en el diccionario de datos, envío error
If not exists ( Select * From bd_sicyproh..trangraldiccionariodatos Where vchNombre = @vchNombreObjeto )
Begin
	Print 'ERROR: El objeto ' + @vchNombreObjeto + ' no existe en el diccionario de datos'
	Set @iError = -1
	Goto _Fin
End

-- Si no existe el objeto en CatGralObjeto, lo inserto
Select @iIdObjeto = iIdObjeto, @siTipoObjeto = siTipoObjeto, @iIdTipoObjeto_CC = DD.iReferencia 
From bd_sicyproh..trangraldiccionariodatos GD, bd_sicyproh..CatConstanteDiccionarioDatos DD
Where GD.vchNombre = @vchNombreObjeto
And GD.siTipoObjeto = DD.siconsecutivo

If @iIdObjeto Is null
Begin
	Print 'ERROR: al obtener el ID del objeto'
	Set @iError = -1
	Goto _Fin
End

if not exists ( Select * From bd_sicyproh..catgralobjeto where iIdGralObjeto = @iIdObjeto )
Begin
	-- Armo la cadena del Insert a catgralobjeto y lo imprimo
	Set @vchScript = 'If not exists ( Select * From CatGralObjeto Where iIdGralObjeto = ' + convert(varchar, @iIdObjeto) + ' )' + char(13) + char(10) 
	Set @vchScript = @vchScript + char(9) + 'Insert Into CatGralObjeto ( iIdGralObjeto, vchNombre, iIdTipoObjeto, tiActivo, vchComentario, tiBitacora )' + char(13) + char(10)
	Set @vchScript = @vchScript + char(9) + 'Values (' + convert(varchar, @iIdObjeto) + ', ''' + @vchNombreObjeto + ''', ' + convert(varchar, @iIdTipoObjeto_CC) + ', 1, ''' + @vchComentarioObjeto + ''', 0)' + char(13) + char(10)
	Set @vchScript = @vchScript + 'GO' + char(13) + char(10) + char(13) + char(10)

	Print @vchScript
	Set @vchScript = ''

	If @tiEjecutaScript <> 0
	Begin
		Insert Into bd_sicyproh..CatGralObjeto ( iIdGralObjeto, vchNombre, iIdTipoObjeto, tiActivo, vchComentario, tiBitacora )
		Values (@iIdObjeto, @vchNombreObjeto, @iIdTipoObjeto_CC, 1, @vchComentarioObjeto, 0)
	End

	
End


-- Insertar y devolver script de inserción a CatMensaje_ProcAlmacenado
Set @vchScript = 'If not exists ( Select * From CatMensaje_ProcAlmacenado Where iIdMensaje = ' + convert(varchar, @iIdMensajeError) + ' )' + char(13) + char(10)
Set @vchScript = @vchScript + char(9) + 'Insert Into CatMensaje_ProcAlmacenado (iIdMensaje, vchDescripcion, iIdGralObjeto, tiActivo, iIdTipoMensage)' + char(13) + char(10)
Set @vchScript = @vchScript + char(9) + 'Values (' + convert(varchar, @iIdMensajeError) + ', ''' + @vchMensajeError + ''', ' + convert(varchar, @iIdObjeto) + ', 1, ' + convert(varchar, @iIdTipoMensaje) + ')' + char(13) + char(10)
Set @vchScript = @vchScript + 'GO' + char(13) + char(10) + char(13) + char(10)

Print @vchScript
Set @vchScript = ''

If @tiEjecutaScript <> 0
Begin
	Insert Into bd_sicyproh..CatMensaje_ProcAlmacenado (iIdMensaje, vchDescripcion, iIdGralObjeto, tiActivo, iIdTipoMensage)
	Values (@iIdMensajeError, @vchMensajeError, @iIdObjeto, 1, @iIdTipoMensaje )
End


_Fin:
Set nocount off
Return @iError
GO

If exists ( Select * From sysobjects Where name = 'sp_ppinDependenciaSP' ) 
	Drop procedure sp_ppinDependenciaSP
GO
Create procedure sp_ppinDependenciaSP
(
	@vchSP varchar(255), 
	@niveles int
)
AS
/*
** Nombre:				sp_ppinDependenciaSP
** Propósito:				Devuelve las dependencias por exec dentro de un SP según la cantidad de niveles máximos indicados.
**						O sea, si el procedimiento p01 llama al procedimiento p02 y éste a su vez al p03,
**						se devolverán los tres procedimientos llamando a este SP con los parámetros: sp_ppinDependenciaSP 'p01', 3
** Campos:				@vchSP: Nombre del procedimiento (nivel 0)
**						@niveles: cantidad máxima de niveles a escanear
** Fecha creación:			12/Enero/2009
** Autor creación:			FDCG
** Revisión:				0
*/
Set nocount on

Declare @iNivel int, @id int
Set @iNivel = 1

If object_id(@vchSP) Is null
Begin
	print 'El objeto [' + @vchSP + '] no existe en [' + db_name() + ']'
	Return 1
End

Create Table #tmpDepends
(
	id int,
	name sysname,
	nivel int
)

Insert Into #tmpDepends (id, name, nivel)
Select Object_id(@vchSP), Object_name(Object_id(@vchSP)), 0

While (@iNivel <= @niveles)
Begin
	Insert Into #tmpDepends (id, name, nivel)
	Select distinct d.depid, o.name, @iNivel
	From sysdepends d, sysobjects o, #tmpDepends t
	Where d.id = t.id
	and d.depid = o.id
	and o.xtype = 'P'
	and not exists ( Select * From #tmpDepends t2 where t2.id = d.depid )

	Set @iNivel = @iNivel + 1
End

Print 'Dependencias por exec del objeto ' + @vchSP + ':'
Select Convert(varchar(100), Space(nivel * 2) + name) as NombreNivel, nivel, id, name 
From #tmpDepends

Set nocount off
Return 0
GO

If exists ( Select * From sysobjects Where name = 'sp_ppinGeneraScriptObjeto' ) 
	Drop procedure sp_ppinGeneraScriptObjeto
GO
CREATE procedure dbo.sp_ppinGeneraScriptObjeto
(
@iAccion int = 0,
@vchValor1 varchar(512) = '',
@vchValor2 varchar(512) = '',
@vchValor3 varchar(512) = '',
@vchValor4 varchar(512) = '',
@vchValor5 varchar(512) = '',
@vchValor6 varchar(512) = NULL
)
AS
/* Federico Colombo */
/*
** Nombre:		sp_ppinGeneraScriptObjeto
** Propósito:	Procedimiento almacenado para facilir el manejo o manipulacion de la base de datos
** Campos:			@iAccion -->0		ejecuta un sp_helptext de este procedimiento almacenado
**							
**					@iAccion -->1		Arma el query para eliminar o crear un objeto de la base de datos. El crear o eliminar depende del tipo de objeto
**									@vchValor1		Nombre del objeto (Requerido)
**
**					@iAccion -->2		Retorna los objecto que cumplen los criterios proporcionado (Nombre o parte del nombre)
**									@vchValor1		Nombre del objeto (Requerido)
**									@vchValor2		Tipo de objeto (opcional)
**					@iAccion -->3		Retorna los objetos que contienen en el cuerpo del mismo un texto (procedimientos, vistas y triggers)
**									@vchValor1		Texto a busca (Requerido)
**									@vchValor2		Tipo de objeto (opcional)
**					@iAccion -->4		Retorna las columnas de una tabla o vista o parámetros de un SP separados por coma
**									@vchValor1		Nombre de la Tabla, vista o SP
**									@vchValor2		Cantidad de columnas por cada fila devuelta
**									@vchValor3		Alias de la tabla
**									@vchValor4		Enviar el numÃ©ro uno si se quiere que lugar de separar los campos
**																por espacios se desea separarlos por tabuladores.
**					@iAccion -->5		Retorna el script CREATE TABLE de la tabla existente proporcionada
**									@vchValor1		Nombre de la Tabla
**					@iAccion -->6		Retorna los comentarios que deben llevar los objetos de la base datos
**
**					@iAccion -->7	Generates the constant insert/update script
**										vchValor1: The id used for the first constant id, and also used for the group id
**										vchValor2: The name of the new group
**										vchValor3: Comma separated values of names, with the names and friendly names that the constants will have.
**													Any item could be optionally separated into name and friendly name by a "|"
**													i.e.: "Open|Connection is open,Closed|Connection is closed"
**
**					@iAccion -->8		Genera automáticamente un script con los alter table (drop o add) de los constraints
**									que hacen referencia (foránea) a la tabla especificada
**									@vchValor1		Nombre de la Tabla
**									@vchValor2		0: Genera los Add Constraint (por defecto)
**												1: Genera los Drop Constraint
**					@iAccion -->9		Genera el script que inserta los datos de una tabla
**									@vchValor1		Nombre de la Tabla
**									@vchValor2		Cláusula where a usar (opcional)
**									@vchValor3		Tipo de resultado: 0: Genera el If Exists->Delete->Insert (dafault)
**																	 1: Genera el If Not Exists->Insert
**					@iAccion -->10		Muestra la consulta al diccionario de datos para un objeto dado
**									@vchValor1		Nombre del objeto.
**					@iAccion -->11		Retorna las consultas a las listas y constantes mas usuales
**									@vchValor1 Nombre de la tabla, si se envia un vacio se retorna todas las tablas ( catconstante, sysvalorlista, catvaloreslista, sysparametro, configuracion)
**									@vchValor2 Valor para el filtro, si se envia un vacio no se coloca ningun filtro
**									@vchValor3 Campo por que se quiere filtrar(nombre) o enviar un uno para filtrar por el consecutivo y un 2
**									para filtrar por el agrupador, si se envia un vacio se filtra por el consecutivo (llave de la tabla).
**					@iAccion -->12		Retorna los objectos que hacen un insert a x tabla de la base de datos
**									@vchValor1 Nombre de la tabla, debe especificarse una sola tabla
**									@vchValor2 Tipo de objeto (<p>-->Procedimientos almacenados, <TR>--Trigrer, <vacío>-->Sin filtrar el tipo de objeto.
**									@vchValor4 varchar(512) = '',
**									@vchValor5 varchar(512) = '',
**									@vchValor6		Filtro
**					@iAccion -->13		Dada una tabla y un alias para la misma, Retorna un SELECT con FROM y WHERE según sus llaves foráneas
**									@vchValor1 Nombre de la tabla
**									@vchValor2 Alias que tendrá la tabla en el select devuelto
**
**					@iAccion -->14		Dado un comando del shell lo ejecuta y devuelve el output
**									@vchValor1: Comando. por ejemplo: 'dir *.exe'
**
**					@iAccion -->15		Devuelve los inserts a CatGralObjeto y CatEspObjeto para una tabla que existe en el diccionario de datos
**									@vchValor1: Nombre de la tabla. por ejemplo: 'ACFMATE1'
**
**					@iAccion -->16		Devuelve las dependencias de un SP (execs anidados a otros SPs)
**									@vchValor1: Nombre del procedimiento almacenado
**									@vchValor2: Cantidad máxima de niveles de anidamiento
**
** Dependencias: 	
**
** Fecha creación: 	12/Noviembre/2005
** Autor creación: 	CJFU
** Fecha modificación: 	24/11/05, 03-03-07, 05-07-06, 01-08-07, 30-04-08, 12-01-09, 26/Febrero/2010
** Autor modificacion: 	FDCG, FDCG, FDCG, FDCG, FDCG, FDCG, CJFU
** Compatibilidad:	1.75
** Revision:		9
*/
Declare @vchQuery varchar(4000)
Declare @tipoObj varchar(100)

If @iAccion = 0 --Ejecutar sp_helptext de este procedimiento almacenado
	Begin
		Select c.text
		From master..sysobjects o, master..syscomments c
		Where o.id = c.id
		And o.name = 'sp_ppinGeneraScriptObjeto'
	End

If @iAccion = 1	--Drop
	Begin
		If rtrim(ltrim(@vchValor1)) = ''
		Begin
			Print 'Esta accion es para la validación de la creaccion/eliminacion de un objeto '
			Print '(creacion para tablas, reportes o campos de tablas y eliminacion para el resto de objetos'
			Print 'Favor de proporcionar el nombre del objeto'
			Print '@vchValor1		-->Nombre del objeto'
			Print '@vchValor2		-->Nombre del campo (siempre y cuando sea una tabla)'
		End
		Else
		If Substring(@vchValor1, 1, 1) = '#' 	-- Si es una temporal
			Begin
				Select Top 1 'If exists ( Select * From tempdb..sysobjects Where name like ''' + @vchValor1 + '[_]%'' ) ' + char(13) + Char(10) + char(9) + 'Drop ' + @vchValor1 + char(13) + Char(10) + 'GO' + char(13) + Char(10)
				From tempdb..sysobjects o
				Where o.name like @vchValor1 + '[_]%'
			End
		Else If substring(@vchValor1, len(@vchValor1) -3, 4) = '.rpt'--Es un reporte
		Begin
			Exec SP_PpInGenera_ScriptRpt
			@vchNombreReporte = @vchValor1
		End
		Else
			Begin
				
				Set @vchValor2 = ltrim(rtrim(@vchValor2))
				--Revisar si es una tabla, si es así para cambiar que en lugar del exists sea un not exists
				If exists ( Select * From sysobjects o
					Where o.name = @vchValor1 And o.xtype = 'U' ) --Tabla
				Begin
					--Si no se está enviando el segundo parametro, quiere decir que unicamente se quiere el if not exists
					If @vchValor2 = '' or @vchValor2 is null
					Begin
						--Select 'If not exists ( Select * From sysobjects Where name = ''' + name + ''' ) '
						Select 'If OBJECT_ID(''' + name + ''', ''U'') Is Null'
						From sysobjects o
						Where o.name = @vchValor1						
					End
					Else
					Begin
						Select 'If not exists ( Select * From sysobjects o, syscolumns c Where o.id = c.id' + char(13)  + Char(10)+ char(9) +
							'And o.name = ''' + o.name + ''' And c.name = ''' + @vchValor2 + ''' ) '
						From sysobjects o
						Where o.name = @vchValor1
					End
				End
				Else
				Begin
					Select @tipoObj = Case When xtype = 'P' Then 'Procedure' When xtype = 'V' Then 'View' When xtype = 'TR' Then 'Trigger' Else '' End
					From sysobjects where name = @vchValor1
					Select 'If exists ( Select * From sysobjects Where name = ''' + name + ''' ) ' + char(13) + Char(10) + char(9) + 'Drop ' + @tipoObj + ' ' + name + char(13) + Char(10) + 'GO' + char(13) + Char(10) 
					From sysobjects o
					Where o.name = @vchValor1
				End
			End
	End
If @iAccion = 2	--Nombres like...
		If rtrim(ltrim(@vchValor1)) = ''
			Print 'Favor de proporcionar el filtro'
		Else
		Begin
			Set @vchQuery  = 'Select Distinct o.name '
			Set @vchQuery  = @vchQuery + 'From sysobjects o '
			Set @vchQuery  = @vchQuery + 'Where o.name like ' + char(39) + '%' + @vchValor1 + '%' + char(39) + ' '
			If @vchValor2 <> ''
				Set
 @vchQuery  = @vchQuery + 'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
			Exec ( @vchQuery  )

			Select @vchQuery as vchQuery
		End
If @iAccion = 3	--Comentarios like
		If rtrim(ltrim(@vchValor1)) = ''
			Print 'Favor de proporcionar el filtro'
		Else
		Begin
			
			Set @vchQuery  = 'Select Distinct o.name '
			Set @vchQuery  = @vchQuery + 'From sysobjects o, syscomments c '
			Set @vchQuery  = @vchQuery + 'Where o.id = c.id '
			Set @vchQuery  = @vchQuery + 'And c.text like ' + char(39) + '%' + @vchValor1 + '%' + char(39) + ' '
			If @vchValor2 <> ''
				Set @vchQuery  = @vchQuery + 'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
			Set @vchQuery  = @vchQuery + ' And o.name <> ''' + @vchValor1 + ''' '
			Exec ( @vchQuery  )

			Select @vchQuery as vchQuery
		End

If @iAccion = 4	-- Campos de una tabla o vista ó parámetros de un SP separados por coma
Begin
		If rtrim(ltrim(@vchValor1)) = ''
			Print 'Favor de proporcionar el nombre del objeto'
		Else
		Begin
			Declare @ColName varchar(70), @cont int

			Create Table #tmpColumnas (
				ya smallint default(0),
				colName varchar(200),
			)
			Set nocount on
			
			If @vchValor3 is null
			Begin
					Set @vchValor3 = ''
			End
			Else
			Begin--eliminar los espacios
				Set @vchValor3 = rtrim(ltrim(@vchValor3))
			End
	
			If @vchValor3 <> ''
			Begin
				Set @vchValor3 = @vchValor3 + '.'
			End

			If exists (Select * from sysobjects where name = @vchValor1 and type IN ('U', 'S', 'V', 'P'))
			BEGIN
				Insert #tmpColumnas
				Select 0, @vchValor3 + '[' + c.name + ']'
				From sysobjects o, syscolumns c
				Where o.id = c.id
				AND o.name = @vchValor1
				Order by c.colid 
			END
			ELSE
			BEGIN
				If exists ( Select * from tempdb..sysobjects where name like @vchValor1 + '[_]%' )
				Begin
					-- Es una tabla temporal
					Insert #tmpColumnas
					Select 0, @vchValor3 + '[' + c.name + ']'
					From tempdb..sysobjects o, tempdb..syscolumns c
					Where o.id = c.id
					AND o.name = (Select Top 1 name From tempdb..sysobjects Where name like @vchValor1 + '[_]%')
					Order by c.colid 					
				End
				Else
				Begin
					-- No existe o no es un objeto válido
					If object_id(@vchValor1) Is Null
						Print 'El objeto [' + @vchValor1 + '] no existe en [' + db_name() + ']'
					else
						Print 'El objeto [' + @vchValor1 + '] no es un objeto válido'
					Return -1
				End
			END
			
			Update tmp
			Set colName = colName
			From #tmpColumnas tmp
			
			Set @vchQuery = ''
			If (@vchValor2 = '')
				Set @vchValor2 = '0'
			Set @cont = 0
			while exists (Select * From #tmpColumnas Where ya=0)
				Begin
					Select TOP 1 @ColName = colName From #tmpColumnas Where ya=0
					Update #tmpColumnas Set ya = 1 Where colName = @colName
					Set @vchQuery = @vchQuery + @ColName 

					If @vchValor4 = 1
					Begin
						Set @vchQuery = @vchQuery + char(9)
					End			
					Else If exists (Select * From #tmpColumnas Where ya=0)
					Begin
						Set @vchQuery = @vchQuery + ', '
					End

					Set @cont = @cont + 1
					If @cont = Convert(int, @vchValor2)
						BEGIN
							Set @vchQuery = @vchQuery + char(13) + Char(10) 
							Set @cont = 0
						END
				End
			Set nocount off
			Select @vchQuery

		End
	End

If @iAccion = 5 	-- Create Table con los campos, tipo, longitud y nullable
	Begin
		If rtrim(ltrim(@vchValor1)) = ''
			Print 'Favor de proporcionar el nombre del objeto'
		Else
		Begin 
			Exec sp_ppinScriptTabla @vchValor1
		End
	End	

If @iAccion = 6 	--Retorna los comentarios que deberán llevar los objetos de la base de datos (triggers, vistas y procedimientos almacenados)
	Begin
		Declare @type varchar(100)
		Declare @v varchar(max)
		Declare @nextCode varchar(12)
		Declare @description varchar(max)
		If len(rtrim(ltrim(@vchValor1))) = 0
			set @type = 'text'
		else
			set @type = @vchValor1
		If len(rtrim(ltrim(@vchValor2))) = 0
			Set @description = '?????'
		else
			Set @description = @vchValor2
		Select @nextCode = cast(Max(Code)+1 as varchar) From d_FFRts..rtslanguage Where [Type] = @type
		If @nextCode is null
		begin
			Print 'Type "' + @type + '" not found.'
			Print ''
		end
		Set @v = 'If Exists (Select * From rtslanguage Where code = ''' + @nextCode + ''' and [Language] = ''English [US]'')' + char(13) + Char(10)
		Set @v = @v + '	Update rtslanguage' + char(13) + Char(10)
		Set @v = @v + '	Set [Language] = ''English [US]'', ' + char(13) + Char(10)
		Set @v = @v + '	[Type] = ''' + @type + ''', ' + char(13) + Char(10)
		Set @v = @v + '	[Code] = ''' + @nextCode + ''', ' + char(13) + Char(10)
		Set @v = @v + '	[Description] = ''' + @description + ''', ' + char(13) + Char(10)
		Set @v = @v + '	[StatusID] = 1' + char(13) + Char(10)
		Set @v = @v + '	Where code = ''' + @nextCode + ''' and [Language] = ''English [US]''' + char(13) + Char(10)
		Set @v = @v + 'Else' + char(13) + Char(10)
		Set @v = @v + '	Insert Into rtslanguage([Language], [Type], [Code], [Description], [StatusID])' + char(13) + Char(10)
		Set @v = @v + '	Values (''English [US]'', ''' + @type + ''', ''' + @nextCode + ''', ''' + @description + ''', 1)' + char(13) + Char(10)
		Set @v = @v + 'GO'
		Print @v
	End
If @iAccion = 7	-- Generate the constant insert/update script
	Begin
		Exec ('sp_GenerateConstantScript ' + @vchValor1 + ', ''' + @vchValor2 + ''', ''' +  @vchValor3 + '''')
	End
If @iAccion = 8	--SP_AddDrop_ForeignKeys
Begin
	Exec ('SP_ppinAddDrop_ForeignKeys ''' + @vchValor1 + ''',''' + @vchValor2 + '''')
End
If @iAccion = 9	--SP_Genera_Insert 
	Exec ('SP_ppinGenera_Insert ''' + @vchValor1 + ''',''' + @vchValor2 + ''', ' + @vchValor3)
If @iAccion = 10 --Consulta al diccionario de datos
Begin
	Set Nocount On
	Select CC2.vchdescripcion AS Base, G.vchNombreObjeto, CC1.vchdescripcion AS TipoObjeto, 
	CC3.vchdescripcion AS Modulo,	vchDescripcionObjeto, E.vchNombreCampo, E.vchDescripcionCampo, G.siTipoObjeto,
	G.iIdObjeto
	Into #tmpAccion10
	From bd_sicyproh..vpinGralDiccionarioDatos G, bd_sicyproh..vpinEspDiccionarioDatos E,
	bd_sicyproh..CatConstanteDiccionarioDatos CC1, bd_sicyproh..CatConstanteDiccionarioDatos CC2,
	bd_sicyproh..CatConstanteDiccionarioDatos CC3
	Where G.iIdObjeto=E.iIdObjeto
	And CC1.siconsecutivo = G.siTipoObjeto
	And CC2.siconsecutivo = G.siBaseDatos
	And CC3.siconsecutivo = G.siIdModulo
	And vchNombreObjeto = @vchValor1
	And CC2.vchdescripcion = db_name()
	

	If Not Exists ( Select * From #tmpAccion10 )
	Begin
		Print 'El objeto [' + @vchValor1 + '] no existe en el diccionario de datos para [' + db_name() + ']'
		Return -1
	End
	
	Declare @tmpBase varchar(512), @tmpObjeto varchar(512), @tmpTipoObjeto varchar(512), @tmpDescripcionObjeto varchar(1000)
	Declare @tmpTipo smallint, @tmpModulo varchar(512), @iIdObjeto int
	Declare @tmpCampo varchar(512), @tmpDesc varchar(1000)
	Select Top 1 @tmpBase = Base, @tmpObjeto = vchNombreObjeto, @tmpTipoObjeto = TipoObjeto, 
	@tmpDescripcionObjeto = vchDescripcionObjeto, @tmpTipo = siTipoObjeto, @tmpModulo = Modulo, @iIdObjeto = iIdObjeto
	From #tmpAccion10

	Print '---------------- CONSULTA AL DICCIONARIO DE DATOS ----------------'
	Print 'Objeto: [' + @tmpTipoObjeto + '] ' + @tmpBase + '..' + @tmpObjeto + ' (' + @tmpDescripcionObjeto + ')' + char(13) + Char(10) + 'ID Objeto: ' + convert(varchar, @iIdObjeto) + char(13) + Char(10) 
	Print 'Módulo: ' + @tmpModulo + char(13) + Char(10) + char(13) + Char(10) 
	if @tmpTipo = 1		-- Store Procedure
		Select '@' + vchNombreCampo AS Parametro, Replace(vchDescripcionCampo,char(13)+char(10),' ') AS Descripcion From #tmpAccion10
	Else
		Select vchNombreCampo AS Campo, Replace(vchDescripcionCampo,char(13)+char(10),' ') AS Descripcion From #tmpAccion10
	Set Nocount Off
End

If @iAccion = 11 --Retornar las consultas de tablas de listas más usuales
Begin
	If @vchValor1 = ''
	Begin
		Select @vchQuery = 'Select * From catconstante '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'siconsecutivo = ' + @vchValor2
													when '1' then 'siconsecutivo = ' + @vchValor2
													when '2' then 'siagrupador = ' + @vchValor2
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
			+ char(13) + Char(10)  --Un enter
		Select @vchQuery = @vchQuery + 'Select * From sysvalorlista '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'siConsecutivo = ' + @vchValor2
													when '1' then 'siConsecutivo = ' + @vchValor2
													when '2' then 'siAgrupador = ' + @vchValor2
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
			+ char(13) + Char(10) --Un enter
		Select @vchQuery = @vchQuery + 'Select * From catvaloreslista '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'iconsecutivo = ' + @vchValor2
													when '1' then 'iconsecutivo = ' + @vchValor2
													when '2' then 'sicodpal = ' + @vchValor2
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
			+ char(13) + Char(10) 
		Select @vchQuery = @vchQuery + 'Select * From sysparametro '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'iCodParametro = ' + @vchValor2
				
									when '1' then 'iCodParametro = ' + @vchValor2
													when '2' then 'siAgrupador = ' + @vchValor2
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
			+ char(13) + Char(10) 
		Select @vchQuery = @vchQuery + 'Select * From configuracion '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'iCodConfiguracion = ' + @vchValor2
													when '1' then 'iCodConfiguracion = ' + @vchValor2													
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
			+ char(13) + Char(10) 
	End
	Else
	Begin
		Select @vchQuery + 'Select * From ' + @vchValor1 + ' '
			+ case @vchValor2 when '' then ''
				else 'Where ' +
					case @vchValor3 when '' then 'iConsecutivo = ' + @vchValor2
													when '1' then 'iConsecutivo = ' + @vchValor2
													when '2' then 'iAgrupador = ' + @vchValor2													
													else @vchValor3 + ' = ' + @vchValor2 end
			end--Fin del case
	End
	Select @vchQuery as vchQuery
End

If @iAccion = 12 --Retornar las consultas de tablas de listas más usuales
Begin
	Set @vchValor1 = ltrim(rtrim(@vchValor1))
	Set @vchValor2 = ltrim(rtrim(@vchValor2))
	If @vchValor1 <> '' And @vchValor1 is not null
	Begin
		--Insert con un espacio
		Set @vchQuery = 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%insert ' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
		End
		--Insert con dos espacios
		Set @vchQuery = @vchQuery +	'Union all '		
		Set @vchQuery = @vchQuery + 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%insert  ' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
		End
		--Insert con tabulador
		Set @vchQuery = @vchQuery +	'Union all '		
		Set @vchQuery = @vchQuery + 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%insert	' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
		End
		--Into con un espacio
		Set @vchQuery = @vchQuery +	'Union all '		
		Set @vchQuery = @vchQuery + 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%into ' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
		End
		--Into con dos espacios
		Set @vchQuery = @vchQuery +	'Union all '		
		Set @vchQuery = @vchQuery + 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%Into  ' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '
		End
		--Into con tabulador
		Set @vchQuery = @vchQuery +	'Union all '		
		Set @vchQuery = @vchQuery + 'Select Distinct o.name '
		Set @vchQuery = @vchQuery +	'From sysobjects o, syscomments c '
		Set @vchQuery = @vchQuery +	'Where o.id = c.id '
		Set @vchQuery = @vchQuery +	'And c.text like ' + char(39) + '%Into	' + @vchValor1 + '%' + char(39) + ' '
		If @vchValor2 <> '' And @vchValor2 is not null
		Begin
			Set @vchQuery = @vchQuery +	'And o.type = ' + char(39) + @vchValor2 + char(39) + ' '

		End
		Execute ( @vchQuery )
		Select @vchQuery as vchQuery
	End
	Else
	Begin
		Select 'Favor de proporcionar el nombre la de la tabla'
		Select '@iAccion -->12		Retorna los objectos que hacen un insert a x tabla de la base de datos'
		Select '@vchValor1 Nombre de la tabla, debe especificarse una sola tabla'
		Select '@vchValor2 Tipo de objeto (<p>-->Procedimientos almacenados, <TR>--Trigrer, <vacío>-->Sin filtrar el tipo de objeto.'
	End
End

If @iAccion = 13 -- Retornar SELECT de una tabla según sus llaves foráneas
Begin
	If @vchValor2 = '' Set @vchValor2 = 'A'
	Exec ('sp_ppinSelectFromWhereForaneo ''' + @vchValor1 + ''',''' + @vchValor2 + '''')
End

If @iAccion = 14 -- cmdShell
Begin
	Exec ('master..xp_cmdshell ''' + @vchValor1 + '''')
End

If @iAccion = 15 -- Inserts a CatGralObjeto y CatEspObjeto
Begin
	Exec ('sp_ppinTablaCatObjeto ''' + @vchValor1 + '''')
End

If @iAccion = 16 -- Dependencias por execs anidados
Begin
	If len(ltrim(rtrim(@vchValor2))) = 0
		Set @vchValor2 = '10'
	Exec ('sp_ppinDependenciaSP ''' + @vchValor1 + ''', ' + @vchValor2)
End
GO

If exists ( Select * From sysobjects Where name = 'sp_ppinSeparaParametro_ScrObj' ) 
	Drop procedure sp_ppinSeparaParametro_ScrObj
GO

CREATE  procedure sp_ppinSeparaParametro_ScrObj
@vchParametro varchar(1024)
AS
Declare @tiHayComa tinyint
Set @tiHayComa = 0

Declare @vchParametro1 varchar(50)
Declare @vchParametro2 varchar(50)
Declare @vchParametro3 varchar(50)
Declare @vchParametro4 varchar(50)
Declare @vchParametro5 varchar(50)
Declare @vchParametro6 varchar(50)
Declare @vchParametro7 varchar(50)
Declare @vchParametro8 varchar(50)
Declare @vchParametro9 varchar(50)
Declare @vchParametro10 varchar(50)

Declare @iParametroNum1 int
Declare @iParametroNum2 int

Set @vchParametro1 = ''
Set @vchParametro2  = ''
Set @vchParametro3  = ''
Set @vchParametro4  = ''
Set @vchParametro5  = ''
Set @vchParametro6  = ''
Set @vchParametro7  = ''
Set @vchParametro8  = ''
Set @vchParametro9  = ''
Set @vchParametro10  = ''

Set @iParametroNum1 = 0
Set @iParametroNum2  = 0

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el primer parametro
Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
If @tiHayComa >= 1
Begin
	Select @vchParametro1 = substring ( @vchParametro, 1, @tiHayComa - 1 )
	--Eliminar de la cadena el parametro obtenido
	Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
End
Else --si no hay coma
Begin
	Select @vchParametro1 = @vchParametro
	--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
	Select @vchParametro = ''
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el segundo parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro2 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro2 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el tercer parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro3 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro3 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el cuarto parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro4 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro4 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el quinto parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro5 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro5 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el sexto parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro6 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro6 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el septimo parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro7 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro7 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el octavo parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro8 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro8 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el noveno parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro9 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro9 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final
Set @vchParametro = ltrim(rtrim(@vchParametro))

--Obtener el decimo parametro, siempre y cuando la variable <<@vchParametro>> tenga datos
If @vchParametro <> ''
Begin
	Select @tiHayComa = PATINDEX ( '%,%' , @vchParametro )
	If @tiHayComa >= 1
	Begin
		Select @vchParametro10 = substring ( @vchParametro, 1, @tiHayComa - 1 )
		--Eliminar de la cadena el parametro obtenido
		Select @vchParametro = substring ( @vchParametro, @tiHayComa + 1, 1000 )
	End
	Else --si no hay coma
	Begin
		Select @vchParametro10 = @vchParametro
		--Eliminar de la cadena el parametro obtenido, vacio por que ya no existen más parametros
		Select @vchParametro = ''
	End
End

--eliminar los espacios al inicio y al final de todos los parametros
Set @vchParametro1 = ltrim(rtrim(@vchParametro1))
Set @vchParametro2 = ltrim(rtrim(@vchParametro2))
Set @vchParametro3 = ltrim(rtrim(@vchParametro3))
Set @vchParametro4 = ltrim(rtrim(@vchParametro4))
Set @vchParametro5 = ltrim(rtrim(@vchParametro5))
Set @vchParametro6 = ltrim(rtrim(@vchParametro6))
Set @vchParametro7 = ltrim(rtrim(@vchParametro7))
Set @vchParametro8 = ltrim(rtrim(@vchParametro8))
Set @vchParametro9 = ltrim(rtrim(@vchParametro9))
Set @vchParametro10 = ltrim(rtrim(@vchParametro10))

--Executa el procemiento almacenado dependiendo del parametro enviado
If isnumeric(@vchParametro1) = 1
Begin
	Select @iParametroNum1 = cast(@vchParametro1 as int)

	Exec sp_ppinGeneraScriptObjeto
	@iAccion = @iParametroNum1,
	@vchValor1 = @vchParametro2,
	@vchValor2 = @vchParametro3,
	@vchValor3 = @vchParametro4,
	@vchValor4 = @vchParametro5,
	@vchValor5 = @vchParametro6,
	@vchValor6 = @vchParametro7
End
Else
Begin
	Exec sp_ppinGeneraScriptObjeto
	@iAccion = 0,
	@vchValor1 = '',
	@vchValor2 = '',
	@vchValor3 = '',
	@vchValor4 = '',
	@vchValor5 = '',
	@vchValor6 = ''
End
GO

If exists ( Select * From sysobjects Where name = 'sp_GenerateConstantScript' ) 
	Drop Procedure sp_GenerateConstantScript
GO
Create Procedure sp_GenerateConstantScript
(
	@FirstId int,
	@GroupName nvarchar(400),
	@Names nvarchar(max)
)
As 
/*
** Purpose:		 Obtain the insert/update scripts for a new group of constants
** Parameters:	 @FirstId: The id used for the first constant id, and also used for the group id
**				 @GroupName: The name of the new group
**				 @Names: Comma separated values of names, with the names and friendly names that the constants will have.
**						 Any item could be optionally separated into name and friendly name by a "|"
**						 i.e.: "Open|Connection is open,Closed|Connection is closed"
**
** Usage samples:	
**	Exec sp_GenerateConstantScript 5000, 'Connection Status', 'Open|Connection is open, Close|Connection is closed, None'
**	Exec sp_GenerateConstantScript 5100, 'Gender', 'Male,Female'
**	
** Creation Date: 15/07/2013
** Creation User: federicoc
** Revision:      0
*/

Begin
	Set nocount on
	Declare @index int, @value nvarchar(max), @name nvarchar(max), @fname nvarchar(max), @script nvarchar(max), @err nvarchar(max), 
			@constantsScript nvarchar(max), @lastCgcId int, @lastCrId int, @cgid int, @constantGroupConstantsScript nvarchar(max), @constantRegionsScript nvarchar(max),
			@regionId int
	Declare @newLine CHAR(2) = CHAR(13) + CHAR(10)
	Declare @constant table ( [Index] int, Value nvarchar(max) )
	Declare @region table ( id int, ok bit )

	If exists ( Select * From DEM_DEV..ConstantGroup Where Id = @FirstId )
	Begin
		Set @err = N'*** WARNING *** ConstantGroup with id ' + Cast(@FirstId as nvarchar(max)) + ' already exists'
		RAISERROR (@err, 12, 1); 
	End
	If exists ( Select * From DEM_DEV..Constant Where Id = @FirstId )
	Begin
		Set @err = N'*** WARNING *** Constant with id ' + Cast(@FirstId as nvarchar(max)) + ' already exists'
		RAISERROR (@err, 12, 1); 
	End

	Select Top 1 @lastCgcId = Id + 1 From DEM_DEV..ConstantGroupConstant Order by Id Desc 
	Select Top 1 @lastCrId = Id + 1 From DEM_DEV..ConstantRegion Order by Id Desc 

	-- {id}: Constant.Id. {fname}: FriendlyName, {name}: Name, {key}: Key.
	Declare @scriptConstant nvarchar(max) = 
'If Exists (Select * From Constant Where [Id] = {id})
	Update Constant
	Set [FriendlyName] = N''{fname}'', 
	[Name] = N''{name}'', 
	[Key] = N''{key}'', 
	[Comment] = Null
	Where [Id] = {id}
Else
	Insert Into Constant([Id], [FriendlyName], [Name], [Key], [Comment])
	Values ({id}, N''{fname}'', N''{name}'', N''{key}'', Null)'

	-- {id}: ConstantGroup.Id. {name}: Name
	Declare @scriptConstantGroup nvarchar(max) = 
'If Exists (Select * From ConstantGroup Where [Id] = {id})
	Update ConstantGroup
	Set [Name] = N''{name}''
	Where [Id] = {id}
Else
	Insert Into ConstantGroup([Id], [Name])
	Values ({id}, N''{name}'')'
		
	-- {id}: ConstantGroupConstant.Id. {cgid}: ConstantGroupId, {cid}: ConstantId, {order}: Order.
	Declare @scriptConstantGroupConstant nvarchar(max) = 
'If Exists (Select * From ConstantGroupConstant Where [Id] = {id})
	Update ConstantGroupConstant
	Set [ConstantGroupId] = {cgid}, 
	[ConstantId] = {cid}, 
	[Order] = {order}, 
	[IsDefault] = 0
	Where [Id] = {id}
Else
	Insert Into ConstantGroupConstant([Id], [ConstantGroupId], [ConstantId], [Order], [IsDefault])
	Values ({id}, {cgid}, {cid}, {order}, 0)'

	Declare @scriptConstantRegion nvarchar(max) = 
'If Exists (Select * From ConstantRegion Where [Id] = {id})
	Update ConstantRegion
	Set [ConstantId] = {cid}, 
	[RegionId] = {rid}
	Where [Id] = {id}
Else
	Insert Into ConstantRegion([Id], [ConstantId], [RegionId])
	Values ({id}, {cid}, {rid})'

	-- ConstantGroup script
	Set @cgid = @FirstId
	Set @script = REPLACE(@scriptConstantGroup, '{id}', @cgid)
	Set @script = REPLACE(@script, '{name}', @GroupName)
	Print @newLine + @script + @newLine

	Insert into @constant
	select [Index], LTRIM(rtrim(value)) 
	from DEM_DEV.dbo.fn_Split(@Names, ',')
	
	Insert into @region
	select Id, 0
	from DEM_DEV..Region
	Where IsActive = 1
	
	Select @constantsScript = '', @constantGroupConstantsScript = '', @constantRegionsScript = ''
	
	While exists ( Select * from @constant )
	Begin
		Select Top 1 @index = [Index], @value = Value From @constant
		Select Top 1 @name = [Value] From DEM_DEV.dbo.fn_Split(@value, '|') Order By [Index] Asc
		Select Top 1 @fname = [Value] From DEM_DEV.dbo.fn_Split(@value, '|') Order By [Index] Desc
		
		-- Constant script
		Set @script = REPLACE(@scriptConstant, '{id}', @FirstId)
		Set @script = REPLACE(@script, '{fname}', @fname)
		Set @script = REPLACE(@script, '{name}', @name)
		Set @script = REPLACE(@script, '{key}', 'K' + CAST(@FirstId as nvarchar(max)))
		
		Set @constantsScript = @constantsScript + @newLine + @script + @newLine
		
		-- ConstantGroupConstant script
		Set @script = REPLACE(@scriptConstantGroupConstant, '{id}', @lastCgcId)
		Set @script = REPLACE(@script, '{cgid}', @cgid)
		Set @script = REPLACE(@script, '{cid}', @FirstId)
		Set @script = REPLACE(@script, '{order}', @index + 1)
		
		Set @constantGroupConstantsScript = @constantGroupConstantsScript + @newLine + @script + @newLine
		
		-- ConstantRegion
		While exists ( Select * From @region where ok = 0 )
		Begin
			Select top 1 @regionId = id from @region where ok = 0
			
			Set @script = REPLACE(@scriptConstantRegion, '{id}', @lastCrId)
			Set @script = REPLACE(@script, '{cid}', @FirstId)
			Set @script = REPLACE(@script, '{rid}', @regionId)
			
			Set @constantRegionsScript = @constantRegionsScript + @newLine + @script + @newLine
			
			Set @lastCrId = @lastCrId + 1
			
			Update @region Set ok = 1 where id = @regionId 
		End
	
		Update @region Set ok = 0
		
		
		Select @FirstId = @FirstId + 1, @lastCgcId = @lastCgcId + 1
		
		Delete from @constant Where [Index] = @index
	End

	Print @constantsScript + @newLine
	Print 'Set Identity_insert ConstantGroupConstant On'
	Print @constantGroupConstantsScript
	Print 'Set Identity_insert ConstantGroupConstant Off' + @newLine + @newLine
	Print 'Set Identity_insert ConstantRegion On'
	Print @constantRegionsScript
	Print 'Set Identity_insert ConstantRegion Off'
End
GO

