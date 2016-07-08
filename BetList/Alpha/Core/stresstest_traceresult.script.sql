use bodb_lukas
go

declare @SPName VARCHAR(100), @numRow INT 

SET @SPName = 'Age_BetList_SelRunningByDate_Mem'


--original 10rows
select @SPName SPName
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from case120x100_10rows
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 10 rows
select @SPName + '_xtest' SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from case120x100_10rows
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'

--original 100rows
select @SPName SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from case120x100_100rows
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 100 rows
select @SPName + '_xtest' SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from case120x100_100rows
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'


SET @SPName = 'Age_BetList_SelRunningByBettype_Ag'


--original 10rows
select @SPName SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_Ag_10_2
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 10 rows
select @SPName + '_xtest' SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_Ag_10_2
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'

--original 100rows
select @SPName SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_Ag_100_2
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 100 rows
select @SPName + '_xtest' SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_Ag_100_2
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'


SET @SPName = 'Age_BetList_SelRunningByBettype_MAg'


--original 10rows
select @SPName SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_MAg_10
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 10 rows
select @SPName + '_xtest' SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_MAg_10
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'



--original 100rows
select @SPName SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_MAg_100
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 100 rows
select @SPName + '_xtest' SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettype_MAg_100
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'


SET @SPName = 'Age_BetList_SelRunningByBettypeMatch_SAg'


--original 10rows
select @SPName SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettypeMatch_SAg_10
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 10 rows
select @SPName + '_xtest' SPName 
	, 10 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettypeMatch_SAg_10
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'

--original 100 rows

select @SPName SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettypeMatch_SAg_100
where EventClass = 41
and TextData like '%'+@SPName+'%'
and TextData not like '%'+@SPName+'_xtest%'

--_xtest 100 rows
select @SPName + '_xtest' SPName 
	, 100 NumRow
	, COUNT(1) Total
	, AVG(CPU) CPU
	, AVG(Reads) Reads
	, AVG(Writes) Writes
	, AVG(Duration)/1000 Durations
from Age_BetList_SelRunningByBettypeMatch_SAg_100
where EventClass = 41
and TextData like '%'+@SPName+'_xtest%'
