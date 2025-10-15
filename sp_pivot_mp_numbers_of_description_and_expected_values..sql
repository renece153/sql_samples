-- Build a Dynamic Script to create a pivot table

USE [dm_staging_area]
GO
/****** Object:  StoredProcedure [dbo].[sp_pivot_mp_numbers_of_description_and_expected_values]    Script Date: 25-Sep-2025 11:15:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- select * from commons.dbo.mp_master_and_mainetanance_table where HEADER = 'NO LINK' and [Usage Group] is not null order by [Asset Type]
CREATE procedure [dbo].[sp_pivot_mp_numbers_of_description_and_expected_values]
as
begin
IF OBJECT_ID (N'commons.dbo.temp_checklist_pivoted_values', N'U') IS NOT NULL
	begin
		drop table commons.dbo.temp_checklist_pivoted_values

	end

declare @sql_insert varchar(8000), @sql1 varchar(8000), @sql2 varchar(8000), @sql3 varchar(8000), @sql4 varchar(8000), @number_of_columns int, @sql_desc varchar(8000) = '', @sql_exp varchar(8000) = '', @sql_all_columns varchar(8000) = ''

create table commons.dbo.temp_checklist_pivoted_values (
	Maintenance_num varchar(100)
)



-- select * from commons.dbo.mp_master_and_mainetanance_table where HEADER = 'NO LINK' and [Usage Group] is not null order by [Asset Type]



-- select * from [dm_staging_area].[dbo].[vw_checklist_variable]



IF exists(select * from tempdb..sysobjects where name = '##temp_checklist_base_table')
	begin
		drop table ##temp_checklist_base_table

	end

	create table ##temp_checklist_base_table (
		Maint_num varchar(100)
		, checklist_row int
		, Checklist_Desc varchar(100)
		, Variable_Description varchar(max)
	)
insert into ##temp_checklist_base_table (Maint_num, checklist_row, Checklist_Desc, Variable_Description)
select
	Maint_num
	, ROW_NUMBER() over(partition by Maint_num order by Checklist_Sequence asc) as  checklist_row
	, Checklist_Desc
	, string_agg(
		case when Checklist_Type = 'Choice List' then cast(variable_row as varchar(100)) + ') ' + Variable_Description + ': ' + cast(passing_value as varchar(100))
		else expected_value end
	,','+char(10)+char(13)) as Variable_Description
	-- into ##temp_checklist_base_table
from(
	select
	A.Maint_num
	, Checklist_Desc
	, ROW_NUMBER() over(partition by A.Maint_num, Checklist_Desc order by Variable_description asc) as variable_row
	, Checklist_Sequence
	, Variable_Description
	, Checklist_Type
	, case when IsPassingValue = 1 then 'PASS' else 'FAIL' end as passing_value
	, case
		when Checklist_Type = 'Text' then PlannedText
		when Checklist_Type = 'Numeric' then cast(PlannedBaseLine as varchar(10)) + 
		case
			when PlannedAboveBaseLine = PlannedBelowBaseLine then ' +/- ' + cast(PlannedAboveBaseLine as varchar(10))
			else ' + ' + cast(PlannedAboveBaseLine as varchar(10)) + ', - ' + cast(PlannedBelowBaseLine as varchar(10)) end
		else NULL end as expected_value
from [dm_staging_area].[dbo].[vw_checklist_variable] A
join (SELECT
distinct [Maitenance Number] as Maint_num
FROM commons.dbo.mp_master_and_mainetanance_table
where HEADER = 'NO LINK'
and [Usage Group] is null 
) B
ON A.Maint_num = B.Maint_num) x
group by 
	Maint_num
	, Checklist_Desc
	, Checklist_Sequence;

insert into ##temp_checklist_base_table (Maint_num, checklist_row, Checklist_Desc, Variable_Description)
select
	Maint_num
	, ROW_NUMBER() over(partition by Maint_num order by Checklist_Sequence asc) as  checklist_row
	, Checklist_Desc
	, string_agg(
		case when Checklist_Type = 'Choice List' then cast(variable_row as varchar(100)) + ') ' + Variable_Description + ': ' + cast(passing_value as varchar(100))
		else expected_value end
	,','+char(10)+char(13)) as Variable_Description
	-- into ##temp_checklist_base_table
from(
	select
	A.Maint_num
	, Checklist_Desc
	, Checklist_Sequence
	, ROW_NUMBER() over(partition by A.Maint_num, Checklist_Desc order by Variable_description asc) as variable_row
	, Variable_Description
	, Checklist_Type
	, case when IsPassingValue = 1 then 'PASS' else 'FAIL' end as passing_value
	, case
		when Checklist_Type = 'Text' then PlannedText
		when Checklist_Type = 'Numeric' then cast(PlannedBaseLine as varchar(10)) + 
		case
			when PlannedAboveBaseLine = PlannedBelowBaseLine then ' +/- ' + cast(PlannedAboveBaseLine as varchar(10))
			else ' + ' + cast(PlannedAboveBaseLine as varchar(10)) + ', - ' + cast(PlannedBelowBaseLine as varchar(10)) end
		else NULL end as expected_value
from [dm_staging_area].[dbo].[vw_checklist_variable] A
join (SELECT
distinct [Maitenance Number] as Maint_num
FROM commons.dbo.mp_master_and_mainetanance_table
where HEADER = 'NO LINK'
and [Usage Group] is not null 
) B
ON A.Maint_num = B.Maint_num) x
group by 
	Maint_num
	, Checklist_Desc
	, Checklist_Sequence;




IF exists(select * from tempdb..sysobjects where name = '##temp_checklist_final_description')
	begin
		drop table ##temp_checklist_final_description

	end

SELECT Maint_num, 'Description_' + cast(checklist_row as varchar(10)) as column_names, Checklist_Desc as value_for_column 
into ##temp_checklist_final_description
FROM ##temp_checklist_base_table


IF exists(select * from tempdb..sysobjects where name = '##temp_checklist_final_expected')
	begin
		drop table ##temp_checklist_final_expected

	end

SELECT Maint_num, 'Planned_' + cast(checklist_row as varchar(10))  as column_names, Variable_Description as value_for_column
into ##temp_checklist_final_expected
FROM ##temp_checklist_base_table

SELECT @number_of_columns = MAX(checklist_row) FROM ##temp_checklist_base_table

print(@number_of_columns)

declare @counter int = 1;

while @counter < @number_of_columns + 1
begin

		declare @alter_table_sql varchar(8000), @col_num varchar(10), @desc_value varchar(255), @expected_value varchar(255)

		select @col_num = cast(@counter as varchar(10))

		set @alter_table_sql = 'ALTER TABLE commons.dbo.temp_checklist_pivoted_values ADD Description_' + @col_num + ' varchar(255);'

		exec(@alter_table_sql)

		set @alter_table_sql = 'ALTER TABLE commons.dbo.temp_checklist_pivoted_values ADD Planned_' + @col_num + ' varchar(max);'

		exec(@alter_table_sql)

		select @desc_value = case when @counter = 1 then  '[Description_' + @col_num + ']' else ' , [Description_' + @col_num +']' end
		select @expected_value = case when @counter = 1 then  '[Planned_' + @col_num + ']' else ' , [Planned_' + @col_num +']'  end

		set @sql_desc = @sql_desc + @desc_value

		set @sql_exp = @sql_exp + @expected_value

		IF @counter = 1
		BEGIN
			set @sql_all_columns = @sql_all_columns + ',' + @desc_value + ' ,' + @expected_value
		END
		ELSE
		BEGIN
			set @sql_all_columns = @sql_all_columns +  @desc_value  + @expected_value
		END


		set @counter = @counter + 1;


end

set @sql1 = 'SELECT * FROM (SELECT Maint_num,  column_names, value_for_column FROM ##temp_checklist_final_description) AS SourceTable PIVOT (MAX(value_for_column) FOR column_names IN (' + @sql_desc +')) AS PivotTable'


set @sql2 = 'SELECT * FROM (SELECT Maint_num, column_names, value_for_column FROM ##temp_checklist_final_expected) AS SourceTable PIVOT (MAX(value_for_column )FOR column_names IN (' + @sql_exp +')) AS PivotTable'


set @sql3 = 'SELECT A.Maint_num ' + @sql_all_columns + ' FROM (' + @sql1 + ') A JOIN ( ' + @sql2 + ') B ON A.Maint_num = B.Maint_num'

print(@sql3)

set @sql_insert = 'Insert into commons.dbo.temp_checklist_pivoted_values ( Maintenance_num ' + @sql_all_columns + ')'

set @sql4 = @sql_insert + @sql3

exec(@sql4)

print(@sql1)

-- exec(@sql2)

print(@sql2)
-- exec(@sql)
end
GO
