-- Sample Stored Procedure for Loading Data to another table
USE [dynamics365_temp]
GO
/****** Object:  StoredProcedure [dbo].[sp_load_data_to_units]    Script Date: 25-Sep-2025 11:17:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[sp_load_data_to_units] @UnitSymbol varchar(255) = null, @UnitDescription varchar(255) = null, @DecimalPrecision int = null
as
begin
	declare @temp_table table (UnitSymbol varchar(255) COLLATE Latin1_General_100_CI_AS_SC_UTF8, UnitDescription varchar(255), DecimalPrecision int)

	insert into @temp_table (UnitSymbol, UnitDescription,DecimalPrecision)
	SELECT 
	case when lower(@UnitDescription) like '%ohm%' then 
	case 
		when @UnitDescription = 'ohm' then NCHAR(8486)
		when lower(left(@UnitDescription,3)) = 'log' then 'log(' + NCHAR(8486) + ')'
		else left(@UnitSymbol,1) + NCHAR(8486)
	end
	else @UnitSymbol end,
	@UnitDescription, 
	@DecimalPrecision

	--- Insert into Products
	Insert into dynamics365_temp.dbo.units(
		UnitSymbol, 
		UnitDescription, 
		DecimalPrecision
	)
	SELECT
		A.UnitSymbol, 
		A.UnitDescription, 
		A.DecimalPrecision
	FROM @temp_table A
	LEFT JOIN dynamics365_temp.dbo.units B
	ON A.UnitSymbol = B.UnitSymbol
	where B.UnitSymbol is null

	
	--- Update Records in Products
	Update x
	set 
	x.UnitSymbol = y.UnitSymbol
	, x.UnitDescription = y.UnitDescription
	, x.DecimalPrecision = y.DecimalPrecision
	FROM  dynamics365_temp.dbo.units x
	join 
	(
	SELECT
		A.UnitSymbol, 
		A.UnitDescription, 
		A.DecimalPrecision  
		, case 
			when A.UnitDescription = B.UnitDescription and A.DecimalPrecision = B.DecimalPrecision then 'N'
			else 'Y' end to_update
	FROM @temp_table A
	JOIN dynamics365_temp.dbo.units B
	ON A.UnitSymbol = B.UnitSymbol
	) y ON x.UnitSymbol = y.UnitSymbol and y.to_update = 'Y'


end
GO
