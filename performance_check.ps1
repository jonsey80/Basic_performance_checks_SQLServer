############################################################################################
#                                                                                          #
#Author: M Jones                                                                           #
#Date: 16/06/2020                                                                          #
#Version: 1.0                                                                              #
#Details: Checks system performance                                                        #                                                                   
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
# Version      Author        Date        Notes                                             #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
#  1.0         M Jones       16/06/2020  Initial Script                                    #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
############################################################################################

#install SQL Module
#inport-module -name SqlServer
#Import-Module -name sqlps

#variables needed through the server
$user_name = ""
$password = ""


#list of servers to process

$list_folder= $PSScriptRoot
$list_location = "$list_folder\serverlist.csv"
$list_location = $list_location
$path_test = Test-Path $list_location
$path_test = $path_test.ToString()

    if($path_test -eq "True") {
        $server_list = get-content -Path $list_location
        Write-Output "Reading from file list....."
        }
    else {
        $server_list = Read-Host "Which Server do you want to script from: "
        }


#functions to run each of the SQL Scripts 
function CPU_CHECKS {
param (
[string]
$instance_name
)

$result_CPU = invoke-sqlcmd -ServerInstance $instance_name  -InputFile $list_folder\cpuCHECK.sql


return $result_CPU

}


function CPU_ERROR {
param(
[string]
$instance_name
)
$CPU_error = invoke-sqlcmd -ServerInstance $instance_name -Query "
                                                                create table #temp_error_log (
                                                                 log_date	datetime	null,
                                                                 error_level int		null,
                                                                 error_text varchar(4000) null
                                                                )`
                                                                execute sys.xp_readerrorlog 0,2, `"CPU usage exceeds`"


                                                                select * from #temp_error_log"
return $CPU_error
}


function memory_checks { 
param (
[string]
$instance_name
)

$result_Memory = invoke-sqlcmd -ServerInstance $instance_name  -InputFile $list_folder\memorycheck.sql

return $result_Memory
 
}

function memory_errors {
param (
[string]
$instance_name
)

$memory_error = invoke-sqlcmd -ServerInstance $instance_name -query "
                                                                    create table #temp_error_log (
                                                                     log_date	datetime	null,
                                                                     error_level int		null,
                                                                     error_text varchar(4000) null
                                                                     )
                                                                     execute sys.xp_readerrorlog 0,2, `"insufficient system memory`"


                                                                     select * from #temp_error_log
 
                                                              "
   return $memory_error  
    }  


function disk_query {
param (
[string]
$instance_name
)

$result_Disk = invoke-sqlcmd -ServerInstance $instance_name  -InputFile $list_folder\disk_query.sql

return $result_Disk
}


function wait_stats {
param (
[string]
$instance_name
)

$result_Wstats = invoke-sqlcmd -ServerInstance $instance_name  -InputFile $list_folder\WaitStat.sql


return $result_Wstats

}

function latche_query {
param (
[string]
$instance_name
)

$result_latches = invoke-sqlcmd -ServerInstance $instance_name -inputFile $list_folder\Latches.sql
return $result_latches
}



 $result_CPU ="wait"
$cpu_error ="wait"
$RESULTS_MEMORY ="wait"
$memory_error ="wait"
 $table_disk ="wait"
$waits ="wait" 
$latches ="wait"



#run the functions to get the results 

foreach ($server in $server_list) {
#clear each variable from the previous run
clear-variable -name result_CPU
Clear-Variable -name cpu_error
Clear-Variable -name RESULTS_MEMORY
Clear-Variable -name memory_error
Clear-Variable -name table_disk
Clear-Variable -name waits
Clear-Variable -name latches

#create new work document
$word=new-object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()
$write=$word.Selection

#get filename and filepath for saving
$filename = $server + "_performance_check"
$file_name = $filename.Replace("`\","`_") #named instances need to remove the \ 
$filepath = "C:\Users\Mark.Jones1\Documents\performancedocs\$file_name.doc"

#flush out document
$write.Style = "Heading 1"
$write.TypeText("Performance Check " + $server)
$write.TypeParagraph()
$write.TypeParagraph()

$write.Style = "subtitle"
$write.font.underline = 1 
$write.TypeText("CPU Breakdown")
$write.TypeParagraph()
$write.TypeParagraph()

$write.Style = "Normal"
$write.TypeText(" The CPU is the main processor on the server, the more strain it is under the slower queries and other processors will be")
$write.TypeTexT(" We monitor 3 separate metrics: ")
$write.TypeParagraph()
$write.Range.ListFormat.ListIndent()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeText("CPU_Signal_waits - this is where SQL Server is waiting for the CPU, anything over 20 may indicate an issue")
$write.TypeParagraph()
$write.TypeText("CPU_USAGE_LAST_100Mins - what the % of CPU use has been over the last 100 minutes, anything over 80 needs checking")
$write.TypeParagraph()
$write.TypeText("Waiting_tasks - average waiting tasks in SQL Server which needs CPU resource")
$write.TypeParagraph()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeParagraph()

$write.TypeParagraph()
$write.TypeText("Status: Green means the system is fine, Yellow means there is some area of concern and Red means the system is under strain for this metric")
$write.TypeParagraph()
$write.TypeParagraph()
$write.ParagraphFormat.Alignment=1
$Range = $write.Range()

$write.Tables.Add($Range,4,4)|Out-Null

$result_CPU = CPU_CHECKS -instance_name $server

$table = $write.Tables.item(1)
$table.Cell(1,1).Range.Text="Metric"
$table.Cell(1,2).Range.Text="Counter Value"
$table.Cell(1,3).Range.Text="Expected Value"
$table.Cell(1,4).Range.Text="Status"
$x = 2 
foreach ($t in $result_CPU) {
    $table.Cell($x,1).Range.Text = $t.COUNTER_NAME
    $table.Cell($x,2).Range.Text = $t.CNTR_VALUE.ToString()
    $table.Cell($x,3).Range.Text = $t.EXPECTED_VALUE.ToString()
    $table.Cell($x,4).Range.Text = $t.STATUS
    $X++
    }

 $table.AutoFormat(9)   
 
 $write.EndKey(6)

#$write.Paragraphs.Alignment = wdAlignParagraphLeft 
$write.TypeParagraph()
$write.TypeText("Any Recent CPU related errors from the SQL error logs are listed below")


$cpu_error = cpu_error -instance_name $server

if(!$cpu_error) {$cpu_error = "No errors found"}
$write.TypeText($cpu_error)

$write.TypeParagraph()
$write.TypeParagraph()
$write.TypeParagraph()

$write.Style = "subtitle"
$write.font.underline = 1 
$write.TypeText("Memory Breakdown")
$write.TypeParagraph()
$write.TypeParagraph()
$write.TypeText("All processes  will occur within the server's memory, Active data is also kept within the RAM - this is good for performance as the onboard RAM is a lot faster than disk, if memory is fulll substantial slowdown will be seen")
$write.TypeParagraph()
$write.TypeText("We have 5 metrics for this:")
$write.TypeParagraph()
$write.Range.ListFormat.ListIndent()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeText("Memory Grants Pending: Number of processes waiting on memory - the higher this number the more pressure on the server")
$write.TypeParagraph() 
$write.TypeText("Page life expectancy: How long data stays in memory, the lower this number the less available memory")
 $write.TypeParagraph() 
 $write.TypeText("Total server Memory (MB): How much memory is used by SQL - should not be above 90%")     
  $write.TypeParagraph() 
 $write.TypeText("Total Memory to high: How much memory is in use by SQL - should not be above 90%") 
 $write.TypeParagraph()    
 $write.TypeText("Stolen Server Memory (KB): Memory stolen from other services, the higher this value the more memory issues there are")
 $write.TypeParagraph()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeParagraph()
$write.TypeText("Status: Green means the system is fine, Yellow means there is some area of concern and Red means the system is under strain for this metric")
$write.TypeParagraph()
$RESULTS_MEMORY = memory_checks -instance_name $server 
$Range_1 = $write.Range()
$write.Tables.Add($Range_1,6,4)|Out-Null
$table_mem = $write.Tables.item(1)
$table_mem.Cell(1,1).Range.Text="Metric"
$table_mem.Cell(1,2).Range.Text="Counter Value"
$table_mem.Cell(1,3).Range.Text="Expected Value"
$table_mem.Cell(1,4).Range.Text="Status"
$x = 2 
foreach ($t in $RESULTS_MEMORY) {
    $table_mem.Cell($x,1).Range.Text = $t.counter_name
    $table_mem.Cell($x,2).Range.Text = $t.cntr_value.ToString()
    $table_mem.Cell($x,3).Range.Text = $t.expected_value.ToString()
    $table_mem.Cell($x,4).Range.Text = $t.Status
    $X++
    }
 $table_mem.AutoFormat(9)   
 
 $write.EndKey(6)
 $write.TypeParagraph()
 $write.TypeText("Any Recent Memory related errors from the SQL error logs are listed below")
 $write.TypeParagraph()

$memory_error = memory_errors -instance_name $server
if(!$memory_error) {$memory_error = "No errors found"}
$write.TypeText($memory_error)
$write.TypeParagraph()
$write.TypeParagraph()
$write.TypeParagraph()

$write.Style = "subtitle"
$write.font.underline = 1 
$write.TypeText("IO Breakdown")
$write.TypeParagraph()
$write.TypeParagraph()
$write.TypeText("The disk condition will have a significant impact on performance as slowdowns in read/write and any disk errors can result in performance and data consistency issues")
$write.TypeParagraph()
$write.TypeText("Each file on the server is checked for the following: ")
$write.Range.ListFormat.ListIndent()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeText("Drive Location: Which Disk Drive the file is on")
$write.TypeParagraph()
$write.TypeText("AVG_READ_STALL: Delay on reading data from the drive")
$write.TypeParagraph()
$write.TypeText("AVG_WRITE_STALL: Delay on writting to the drive")
$write.TypeParagraph()
$write.TypeText("File_on_os_drive: is the file on the same drive as the OS - this is not recomended")
$write.TypeParagraph()
$write.TypeText("File_log_same_drive: is the data and log file on the same drive - this is not recomended")
$write.TypeParagraph()
$write.TypeText("Capacity(GB): how large the drive is")
$write.TypeParagraph()
$write.TypeText("Freespace(GB): how much room is left on the drive")
$write.TypeParagraph()
$write.Range.ListFormat.ApplyBulletDefault()
$write.TypeParagraph()
$write.TypeText("Status: Green means the system is fine, Yellow means there is some area of concern and Red means the system is under strain for this metric")
$write.TypeParagraph()
$disk_results = disk_query -instance_name $server
$rowsd = $disk_results.count + 1  
$Range_2 = $write.Range() 

$write.Tables.Add($Range_2,$rowsd,11)|Out-Null

$table_disk = $write.Tables.item(1)
$table_disk.Cell(1,1).Range.Text="File Type"
$table_disk.Cell(1,2).Range.Text="File Name"
$table_disk.Cell(1,3).Range.Text="Drive Location"
$table_disk.Cell(1,4).Range.Text="Average Read Stall"
$table_disk.Cell(1,5).Range.Text="Average Write Stall"
$table_disk.Cell(1,6).Range.Text="File on OS Drive"
$table_disk.Cell(1,7).Range.Text="All Files on Same drive"
$table_disk.Cell(1,8).Range.Text="Disk Speed Status"
$table_disk.Cell(1,9).Range.Text="Capacity(GB)"
$table_disk.Cell(1,10).Range.Text="Freespace (GB)"
$table_disk.Cell(1,11).Range.Text="Disk Space Status"
$x = 2 
foreach ($t in $disk_results) {
    $table_disk.Cell($x,1).Range.Text = $t.file_type
    $table_disk.Cell($x,2).Range.Text = $t.file_name
    $table_disk.Cell($x,3).Range.Text = $t.drive_location
    $table_disk.Cell($x,4).Range.Text = $t.AVG_READ_STALL.ToString()
    $table_disk.Cell($x,5).Range.Text = $t.AVG_WRITE_STALL.ToString()
    $table_disk.Cell($x,6).Range.Text = $t.FILE_ON_OS_DRIVE.ToString()
    $table_disk.Cell($x,7).Range.Text = $t.File_log_same_drive.ToString()
    $table_disk.Cell($x,8).Range.Text = $t.Disk_speed
     $table_disk.Cell($x,9).Range.Text = $t.capacity.ToString()
    $table_disk.Cell($x,10).Range.Text = $t.freespace.ToString()
    $table_disk.Cell($x,11).Range.Text = $t.Disp_space_remaining
    $X++
    }
 $table_disk.AutoFormat(9)   
 
 $write.EndKey(6)
 $write.TypeParagraph()

 $write.Style = "subtitle"
$write.font.underline = 1 
$write.TypeText("Wait Stats and latches")
$write.TypeParagraph()
$write.TypeParagraph()
$write.TypeText("The most common wait stats and latches, this information with the details above can be combined to give some indications if there are problems with the server ")
$write.TypeParagraph()

$waits = wait_stats -instance_name $server
$row3 = $waits.count
$Range_4 = $write.Range()
$write.Tables.Add($Range_4,$row3,9)|Out-Null

$table_wait = $write.Tables.item(1)
$table_wait.Cell(1,1).Range.Text="wait_type"
$table_wait.Cell(1,2).Range.Text="WaitS"
$table_wait.Cell(1,3).Range.Text="ResourceS"
$table_wait.Cell(1,4).Range.Text="SignalS"
$table_wait.Cell(1,5).Range.Text="WaitCount"
$table_wait.Cell(1,6).Range.Text="Percentage"
$table_wait.Cell(1,7).Range.Text="AvgWait_S"
$table_wait.Cell(1,8).Range.Text="AvgRes_S"
$table_wait.Cell(1,9).Range.Text="AvgSig_S"
$x = 2 
foreach ($t in $waits) {

    $table_wait.Cell($x,1).Range.Text = $t.WaitType
    $table_wait.Cell($x,2).Range.Text = $t.Wait_S.ToString()
    $table_wait.Cell($x,3).Range.Text = $t.Resource_S.ToString()
    $table_wait.Cell($x,4).Range.Text = $t.Signal_S.ToString()
    $table_wait.Cell($x,5).Range.Text = $t.WaitCount.ToString()
    $table_wait.Cell($x,6).Range.Text = $t.Percentage.ToString()
    $table_wait.Cell($x,7).Range.Text = $t.AvgWait_S.ToString()
    $table_wait.Cell($x,8).Range.Text = $t.AvgRes_S.ToString()
     $table_wait.Cell($x,9).Range.Text = $t.AvgSig_S.ToString()
    $X++
    }
 $table_wait.AutoFormat(9)   
 
 $write.EndKey(6)
 $write.TypeParagraph()

 $latches = latche_query -instance_name $server
 $row1 = $latches.count + 1 
$Range_5 = $write.Range()
$write.Tables.Add($Range_5,$row1,5)|Out-Null
$table_latches = $write.Tables.item(1)
$table_latches = $write.Tables.item(1)
$table_latches.Cell(1,1).Range.Text="LatchClass"
$table_latches.Cell(1,2).Range.Text="Wait_S"
$table_latches.Cell(1,3).Range.Text="WaitCount"
$table_latches.Cell(1,4).Range.Text="Percentage"
$table_latches.Cell(1,5).Range.Text="AvgWait_S"
$x = 2 
foreach ($t in $latches) {
    
    $table_latches.Cell($x,1).Range.Text = $t.LatchClass
    $table_latches.Cell($x,2).Range.Text = $t.Wait_S.ToString()
    $table_latches.Cell($x,3).Range.Text = $t.WaitCount.ToString()
    $table_latches.Cell($x,4).Range.Text = $t.Percentage.ToString()
    $table_latches.Cell($x,5).Range.Text = $t.AvgWait_S.ToString()
   
    $X++
    }
 $table_latches.AutoFormat(9)   
 
 $write.EndKey(6)
 $write.TypeParagraph()


$doc.SaveAs($filepath)
$doc.Close()
$word.Quit()

}
