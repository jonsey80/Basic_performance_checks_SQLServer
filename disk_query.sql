

IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','') as int) > 10
begin --need 'xp_cmdshell' to be 1 
EXEC sp_configure 'show advanced options', 1  
  
-- To update the currently configured value for advanced options.  
RECONFIGURE with override;  


EXEC sp_configure 'xp_cmdshell', 1;

RECONFIGURE with override;
end


IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','')as int) <= 10
begin
EXEC sp_configure 'show advanced options', 1 
 
-- To update the currently configured value for advanced options.  
RECONFIGURE with override;  


EXEC sp_configure 'xp_cmdshell', 1;

RECONFIGURE with override;
end


declare @svrName varchar(255)
declare @sql varchar(400)
--by default it will take the current server name, we can the set the server name as well
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'
--creating a temporary table

CREATE TABLE #output
(line varchar(255))

insert #output
EXEC xp_cmdshell @sql

create table #output2
(line varchar(255))

insert #output2
EXEC xp_cmdshell 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -filter ''DriveType = 3'' | Select-Object name, BlockSize | foreach{$_.name +''|''+$_.BlockSize}"'






; WITH [FILE_DETAILS] AS (
select MF.DATABASE_ID, 
			  type_desc 'File_type',
			   name 'File_name',
			   substring(physical_name,0,3) 'Drive_Location',
			   io_stall_read_ms/case when isnull(num_of_reads,1) = 0 then 1 else num_of_reads end 'AVG_READ_STALL',
			   io_stall_write_ms/case when isnull(num_of_writes,1) = 0 then 1 else num_of_reads end 'AVG_WRITE_STALL'
		from sys.master_files mf
		inner join sys.dm_io_virtual_file_stats(NULL,NULL) ivfs on (
		mf.database_id = ivfs.database_id and 
		mf.file_id = ivfs.file_id 
		)
		where mf.database_id not in (1,3,4) 
		),
[disk_space] as (


--inserting disk name, total space and free space value in to temporary table

--script to retrieve the values in MB from PS Script output
--select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
--   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
--   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity(MB)'
--   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
--   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0) as 'freespace(MB)'
--from #output
--where line like '[A-Z][:]%'
--order by drivename
--script to retrieve the values in GB from PS Script output

select drivename,
case when capacity = 0 then 0 else [capacity]/1024 end 'capacity'
,case when [freespace] = 0 then 0 else freespace/1024 end 'freespace'
,convert(numeric(9,2),([freespace]/[capacity])*100) '% free'    from (
select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -2))) as drivename
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity'
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float)  ,2)as 'freespace'

from #output
where line like '[A-Z][:]%') x

)

select file_type,
	   file_name,
	   a.drive_location,
	   AVG_READ_STALL,
	   AVG_WRITE_STALL,
	   CASE WHEN a.DRIVE_LOCATION = 'c:' THEN 1
			ELSE  0
		END 'FILE_ON_OS_DRIVE',
		c.File_log_same_drive,
		case when (a.AVG_READ_STALL > 30 or AVG_WRITE_STALL > 30) then 'Yellow'
			 when (a.AVG_READ_STALL > 80 or AVG_WRITE_STALL > 80) then 'Red'
		     else 'Green'
		end 'Disk_speed',
		dsp.[capacity],
		dsp.[freespace],
		case when dsp.[% free] < 10 then 'Red'
			 when dsp.[% free] between 11 and 15 then 'Yellow'
			 else 'Green'
		end 'Disp_space_remaining'
FROM FILE_DETAILS A
INNER JOIN (	select a.database_id,
					   a.drive_location,
					   case when a.Drive_Location = b.drive_location then '1'
							else 0
						end 'File_log_same_drive'
				from (

						SELECT DATABASE_ID,
							   FILE_TYPE,
							   DRIVE_LOCATION
						FROM FILE_DETAILS A
						WHERE FILE_TYPE = 'Rows') a
						INNER JOIN (SELECT DATABASE_ID,
							   FILE_TYPE,
							   DRIVE_LOCATION
						FROM FILE_DETAILS 
						where file_type = 'LOG') B ON A.database_id = b.Database_id ) C on a.database_id = c.database_id 
																						and a.Drive_Location = c.Drive_Location
left outer join [disk_space] dsp on a.Drive_Location = dsp.drivename


--script to drop the temporary table
drop table #output
drop table #output2



IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','') as int) > 10
begin --need 'xp_cmdshell' to be 1 
EXEC sp_configure 'show advanced options', 1  
  
-- To update the currently configured value for advanced options.  
RECONFIGURE with override;  


EXEC sp_configure 'xp_cmdshell',0;

RECONFIGURE with override;
end


IF cast(replace(CAST(SERVERPROPERTY('ProductVersion') AS CHAR(2)),'.','')as int) <= 10
begin
EXEC sp_configure 'show advanced options', 1 
 
-- To update the currently configured value for advanced options.  
RECONFIGURE with override;  


EXEC sp_configure 'xp_cmdshell', 0;

RECONFIGURE with override;
end