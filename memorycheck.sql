if object_id('tempdb.dbo.#memory_performance','U') is not null
drop table #memory_performance

if object_id('tempdb.dbo.#temp_error_log','U') is not null
drop table #temp_error_log 

			select distinct opc.counter_name,
							opc.cntr_value,
							case when opc.counter_name = 'Page life expectancy' then '300'
								 when opc.counter_name = 'memory grants pending' then '10'
								 when opc.counter_name = 'Total server Memory (MB)' then cast((((tmem.cntr_value/1024))) as varchar)
							end 'expected_value',
							case when opc.counter_name = 'Page life expectancy' and opc.cntr_value < 300 then 'RED'
								 when opc.counter_name = 'Page life expectancy' and opc.cntr_value > 300 then 'Green'
								 when opc.counter_name = 'Memory Grants Pending' and opc.cntr_value between 0 and 3 then 'Green'
								 when opc.counter_name = 'Memory Grants Pending' and opc.cntr_value between 3 and 6 then 'Yellow'
								 When opc.counter_name = 'Memory Grants Pending' and opc.cntr_value > 6 then 'Red'
								 when opc.counter_name = 'Total server Memory (MB)' and ((opc.cntr_value/100)*90) > (((tmem.cntr_value/1024))) then 'Red' --target memory node is the amount needed to run ok,  total memory is the amount in use
								 when opc.counter_name = 'Total server Memory (MB)' and ((opc.cntr_value/100)*90) < (((tmem.cntr_value/1024))) then 'Green' -- if total memory is not within 90% then we need to look into if there is enough memory
				
							end 'Status'
				into #Memory_performance
			from (
			select case when opc.counter_name = 'Total server memory (kb)' then '1'
					else '0' 
					end 'join_row_opc',  
				   case when opc.counter_name = 'Total server Memory (kb)' then 'Total server Memory (MB)'
				   else opc.counter_name
				   end 'counter_name',
				   case when opc.counter_name = 'Total server Memory (kb)' then convert(numeric(9,2),(opc.cntr_value/1024))
						else opc.cntr_value end 'cntr_value' 
	   
			from sys.dm_os_performance_counters OPC
			where opc.counter_name in (
			'Total server Memory (KB)',
			'Memory Grants outstandinng',
			'Memory Grants Pending',
			'page life expectancy'                                                                                                            
			)
			) OPC

			left outer join (
			select '1' 'join_row', counter_name,instance_name,cntr_value from  sys.dm_os_performance_counters where counter_name = 'Target memory (KB)' and instance_name = 'internal'
			) tmem on  OPC.join_row_opc = tmem.join_row





if object_id('tempdb.dbo.#num','U') is not null
drop table #num
declare @@memory varchar(200)
create table #num (memory varchar(200) null)			
IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','') as int) > 10
begin

insert #num
 execute sp_executesql  N'(SELECT (physical_memory_kb/1024)  FROM sys.dm_os_sys_info)'

select @@memory = memory from #num
end
IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','')as int) <= 10
begin

insert #num
execute sp_executesql N'(SELECT  ((physical_memory_in_bytes/1024)/1024) FROM sys.dm_os_sys_info)'
select @@memory = memory from #num
end

			insert into #Memory_performance (
						counter_name,
						cntr_value,
						[expected_value],
						Status
						)
			select  'Total Memory to high',
				   (cntr_value/1024) 'cntr_value',
				   ((cast(@@memory as numeric(9,2))/100)*90),
				   case when (cntr_value/1024) < ((cast(@@memory as numeric(9,2))/100)*90) then 'Green'
						when (cntr_value/1024) < ((cast(@@memory as numeric(9,2))/100)*90) then 'Red'
					end 'Status'
			from  sys.dm_os_performance_counters 
			where counter_name = 'Target memory (KB)' and instance_name = 'internal'
			

			insert into #Memory_performance (
						counter_name,
						cntr_value,
						[expected_value],
						Status
						)
			select 
				a.ssm_counter_name,
				a.ssm_cntr_value,
				((c.tsm_counter_value/100)*20) 'expected value',
				case when a.ssm_cntr_value > ((c.tsm_counter_value/100)*20) then 'Red'
					 When a.ssm_cntr_value > ((b.br_counter_value/100)*75) then 'yellow'
					 else 'Green'
				end 'status'
			from (
			select 1 'a_join_row',
				   a.counter_name 'ssm_counter_name',
				   a.cntr_value/1024  'ssm_cntr_value'
			from sys.dm_os_performance_counters a
			where a.counter_name in ( 'Stolen Server Memory (KB)' )) a                                                                                         
			inner join (select 1 'join_row',
				   counter_name 'br_counter_name',
				   cntr_value 'br_counter_value'
				  from sys.dm_os_performance_counters
			where counter_name in ('Batch Requests/sec') ) b  on a.a_join_row = b.join_row
			inner join (select 1 'join_row',
				   counter_name 'tsm_counter_name',
				   cntr_value/1024 'tsm_counter_value'
			from sys.dm_os_performance_counters
			where counter_name in ('Total server Memory (KB)')) c on a.a_join_row = c.join_row


			select * from #Memory_performance



--select count(case when Status = 'Green' then 1 end) 'Green_count',
--	   count(case when Status = 'Yellow' then 1 end) 'Yellow_count',
--	   count(case when Status = 'Red' then 1 end ) 'Red_count'
--from #Memory_performance

 --select* from  sys.dm_os_performance_counters where object_name like '%memory%'
 --create table #temp_error_log (
 --log_date	datetime2(7)	null,
 --error_level int		null,
 --error_text varchar(4000) null
 --)
 --execute sys.xp_readerrorlog 0,2, "insufficient system memory"


-- select count(*) from #temp_error_log