-- A function that creates Hexadecimal Values by mapping it to data from original table

USE [data_migration]
GO
/****** Object:  UserDefinedFunction [dbo].[fx_generate_hexadecimal_id_for_test_group_assignments]    Script Date: 25-Sep-2025 11:14:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE function [dbo].[fx_generate_hexadecimal_id_for_test_group_assignments] (
		@defaault_document_id varchar(100),
		@testgroup_id varchar(100)
)
returns varchar(8000)
begin

-- Declaring transformed values

declare @transformed_valid_to bigint, 
		@transformed_valid_from bigint, 
		@transformed_test_id bigint,
		@rand_time_val int,
		@rand_add_val int,
		@transformed_test_sequence int,
		@default_document_ref bigint,
		@transformed_testgroupid bigint,
		@hex_value varchar(1),
		@output_string varchar(8000),
		@random_val_1 decimal(18,8),
		@random_val_2 decimal(18,8),
		@random_val_3 decimal(18,8),
		@random_val_4 decimal(18,8),
		@random_val_5 decimal(18,8),
		@valid_from varchar(100),
		@valid_to varchar(100)

declare @temp_table table (
	document_id_part bigint
	, test_sequence_part bigint
	, valid_from_part bigint
	, valid_to_part bigint
	, testgroup_part bigint
	, testid_part bigint
)

SELECT @valid_from = format(PARSE('2020-01-01 00:00:00' as datetime2 USING 'en-US'), 'M/d/yyyy HH:mm:ss'), @valid_to  = format(PARSE('2154-12-31 23:59:59' as datetime2 USING 'en-US'), 'M/d/yyyy HH:mm:ss')

SELECT
		@random_val_1 = random_val_1
		,@random_val_2 = random_val_2
		,@random_val_3 = random_val_3
		,@random_val_4 = random_val_4
		,@random_val_5 = random_val_5
FROM data_migration.dbo.vw_auto_generate_random_number


select @transformed_valid_to = abs(cast(cast(PARSE(@valid_to as datetime2 USING 'en-US') as datetime) as bigint) - cast(cast(CURRENT_TIMESTAMP as datetime) as bigint)),
		@transformed_valid_from = abs(cast(cast(PARSE(@valid_from as datetime2 USING 'en-US') as datetime) as bigint)- cast(cast(CURRENT_TIMESTAMP as datetime) as bigint)),
		@transformed_test_id = coalesce(try_cast(replace('10000-1000','-','') as bigint),0),
		@rand_time_val = CEILING(random_val_1*10),
		@rand_add_val = CEILING((random_val_5/random_val_2) * 1000),
		@transformed_test_sequence = try_cast(cast(@rand_add_val as varchar(10)) + (random_val_5 * 100) as int),
		@default_document_ref = ceiling(sqrt(@defaault_document_id) * @random_val_3 + 4294967295 * @random_val_3),
		@transformed_testgroupid = ceiling(log(coalesce(try_cast(@transformed_testgroupid as int),100), 10) * 4294967295 * random_val_3)
		from data_migration.dbo.vw_auto_generate_random_number


insert into @temp_table (
	document_id_part 
	, test_sequence_part
	, valid_from_part
	, valid_to_part
	, testgroup_part
	, testid_part
)

select
	case when @default_document_ref between 0 and 4294967295 then @default_document_ref
	else floor(@default_document_ref/@random_val_1) end
	, case when @transformed_test_sequence  between 0 and 42949 then @transformed_test_sequence
	else CEILING(@transformed_test_sequence/ 100) end
	, case 
	when @transformed_valid_to between 0 and 42949 then @transformed_valid_to
	else case 
		when FLOOR(@random_val_4 * @transformed_valid_to) between 0 and 42949 then FLOOR(@rand_time_val*@transformed_valid_to)
		else FLOOR(42949 /2) + @rand_add_val end
	end
	, case 
	when @transformed_valid_from between 0 and 42949 then @transformed_valid_to
	else case 
		when FLOOR(@random_val_3*@transformed_valid_from) between 0 and 42949 then FLOOR(@rand_time_val*@transformed_valid_to)
		else FLOOR((42949)/2) + @rand_add_val end
	end
	,case when @transformed_testgroupid between 0 and 4294967295 then  @transformed_testgroupid
	else case 
	when @transformed_testgroupid * @random_val_2 between 0 and 4294967295 then FLOOR(@transformed_testgroupid * @random_val_3) 
	else coalesce(nullif((@transformed_testgroupid % 8),0),.5) * (FLOOR(4294967295/2) * @random_val_4) end
	end  
	
	, case when @transformed_test_id/(@rand_time_val* 10) between 0 and 42949 then @transformed_test_id/(@rand_time_val* 10)
	else 
		case
			when FLOOR((@transformed_test_id/100) * @random_val_3) between 0 and 42949 then FLOOR((@transformed_test_id/100) * @random_val_2)
			else FLOOR(@transformed_test_id) / 100
		end
	end

	select 
	@hex_value = hex_value
	from [data_migration].[dbo].[reference_hex_padding]
	where "value" = (cast(ceiling(@random_val_5*100) as int) % 15) 


	select
	@output_string =
	document_id_part + '-' + test_sequence_part + '-' + valid_from_part + '-' + valid_to_part + '-' + testgroup_part + testid_part
	FROM (
	select
		case 
			when len(document_id_part) = 8 then document_id_part
			when len(document_id_part) > 8 then substring(document_id_part,1,8)
			else trim(document_id_part + coalesce(REPLICATE(@hex_value, 8-len(document_id_part)),''))
		end as document_id_part
		, case 
			when len(test_sequence_part) = 4 then test_sequence_part
			when len(test_sequence_part) > 4 then substring(test_sequence_part,1,4)
			else trim(coalesce(REPLICATE(@hex_value, 4-len(test_sequence_part)),'') + test_sequence_part)
		end as test_sequence_part
		, case 
			when len(valid_from_part) = 4 then valid_from_part
			when len(valid_from_part) > 4 then substring(valid_from_part,1,4)
			else trim(coalesce(REPLICATE(@hex_value, 4-len(valid_from_part)),'') + valid_from_part)
		end as valid_from_part
		, case 
			when len(valid_to_part) = 4 then valid_to_part
			when len(valid_to_part) > 4 then substring(valid_to_part,1,4)
			else  trim(coalesce(REPLICATE(@hex_value, 4-len(valid_to_part)),'') + valid_to_part) 
		end as valid_to_part
		, case 
			when len(testgroup_part) = 8 then testgroup_part
			when len(testgroup_part) > 8 then substring(testgroup_part,1,8)
			else trim(testgroup_part + coalesce(REPLICATE(@hex_value, 8-len(testgroup_part)),''))
		end as testgroup_part
		, case 
			when len(testid_part) = 4 then testid_part
			when len(testid_part) > 4 then substring(testid_part,1,4)
			else trim(coalesce(REPLICATE(@hex_value, 4-len(testid_part)),'') + testid_part)
		end as testid_part
	from (
	select 
	FORMAT(document_id_part, 'X') as document_id_part
	, FORMAT(test_sequence_part, 'X') as test_sequence_part
	, FORMAT(valid_from_part, 'X') as valid_from_part
	, FORMAT(valid_to_part, 'X') as valid_to_part
	, FORMAT(testgroup_part, 'X') as testgroup_part
	, FORMAT(testid_part, 'X') as testid_part
	from @temp_table
	) x
	) y

	return @output_string
end
GO
