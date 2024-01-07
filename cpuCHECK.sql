if object_id('tempdb.dbo.#CPU_MONITOR','U') is not null
drop table #CPU_MONITOR

CREATE TABLE #CPU_MONITOR (
COUNTER_NAME	VARCHAR(300)	NULL,
CNTR_VALUE		NUMERIC(9,2)	NULL,
EXPECTED_VALUE	NUMERIC(9,2)	NULL,
STATUS			VARCHAR(50)		NULL
)

INSERT INTO #CPU_MONITOR (
COUNTER_NAME,
CNTR_VALUE,
EXPECTED_VALUE,
STATUS
)
SELECT 'CPU_SIGNAL_WAITS' as 'counter_name',
	   [% Signal (CPU) Waits],
	   20,
	   case when [% Signal (CPU) Waits] < 20 then 'GREEN'
			WHEN [% Signal (CPU) Waits] > 20 THEN 'RED'
		END 'STATUS'
FROM (
		SELECT CAST(100.0 * SUM(signal_wait_time_ms) / SUM (wait_time_ms) AS NUMERIC(20,2)) 
		AS [% Signal (CPU) Waits],
		CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / SUM (wait_time_ms) AS NUMERIC(20,2)) 
		AS [% Resource Waits]
		FROM sys.dm_os_wait_stats WITH (NOLOCK) 
	  )T


DECLARE @ts BIGINT;
DECLARE @lastNmin TINYINT;
SET @lastNmin = 100;
SELECT @ts =(SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info);
INSERT INTO #CPU_MONITOR (
COUNTER_NAME,
CNTR_VALUE,
EXPECTED_VALUE,
STATUS
)
SELECT 'CPU_USAGE_LAST_1O0MINS' AS 'COUNTER_NAME',
		AVG([SQLServer_CPU_Utilization] + OTHER_PROCESS_CPU_UTILIZATION) 'CNTR_VALUE',
		80 'EXPECTED_VALUE',
		CASE WHEN AVG([SQLServer_CPU_Utilization] + OTHER_PROCESS_CPU_UTILIZATION) <= 70 THEN 'GREEN'
			 WHEN AVG([SQLServer_CPU_Utilization] + OTHER_PROCESS_CPU_UTILIZATION) > 70 THEN 'RED'
		END 'STATUS'
FROM (
 
SELECT TOP(@lastNmin)
		SQLProcessUtilization AS [SQLServer_CPU_Utilization], 
		SystemIdle AS [System_Idle_Process], 
		100 - SystemIdle - SQLProcessUtilization AS [Other_Process_CPU_Utilization], 
		DATEADD(ms,-1 *(@ts - [timestamp]),GETDATE())AS [Event_Time] 
FROM (SELECT record.value('(./Record/@id)[1]','int')AS record_id, 
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int')AS [SystemIdle], 
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int')AS [SQLProcessUtilization], 
[timestamp]      
FROM (SELECT[timestamp], convert(xml, record) AS [record]             
FROM sys.dm_os_ring_buffers             
WHERE ring_buffer_type =N'RING_BUFFER_SCHEDULER_MONITOR'AND record LIKE'%%')AS x )AS y 
)Z

INSERT INTO #CPU_MONITOR (
COUNTER_NAME,
CNTR_VALUE,
EXPECTED_VALUE,
STATUS
)
select 'WAITING_TASKS',
		[Avg Wait Task],
		[Avg Current Task],
		case when [Avg Wait Task] > [Avg Current Task] then 'RED'
			 else 'Green'
		end 'status'
from (
SELECT AVG(current_tasks_count) AS [Avg Current Task], 
AVG(runnable_tasks_count) AS [Avg Wait Task]
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
AND status = 'VISIBLE ONLINE' ) t 

SELECT * FROM #CPU_MONITOR


--create table #temp_error_log (
-- log_date	datetime2(7)	null,
-- error_level int		null,
-- error_text varchar(4000) null
-- )
-- execute sys.xp_readerrorlog 0,2, "CPU usage exceeds"


-- select count(*) from #temp_error_log