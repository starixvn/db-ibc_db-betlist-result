ALTER PROCEDURE [dbo].[Acc_BetList_SelBettype]
@CustID int,
@FromDate datetime,  
@ToDate datetime,
@MoveBetsDay datetime, 
@BalanceUpDay datetime 
AS 

/*	Created: Henry
	Date:28/12/2009
	DB: DBAGE/BODB02
	
	Revisions:
	- 13/01/2010@Henry: Newly created
	- 20110516@Lukas: re-arrange bettype
	- 20110524@Henry: change to use winlostdate instead of transdate
	- 20130121@Dan: change linked server DB06 to DBARC
	- 20140311@Dom: Add keno translog
	- 20150615@Edward: Remove bettype 903 of BetTrade
	- 20150529@Tom: Add filter by custid on translog
	- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
*/

SET NOCOUNT ON  
DECLARE @BettypeTable TABLE (bettype INT)

Declare @TempFromDate datetime
Declare @TempToDate datetime

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay 
		set @TempFromDate =  dateadd(day,1,@MoveBetsDay)
	ELSE
		set @TempFromDate = @FromDate
		
	INSERT INTO @BettypeTable
	SELECT 
		DISTINCT bettype 
		FROM bettrans b (nolock)
	WHERE 
		bettype < 19001 
		AND bettype <> 903
		AND custid = @CustID
		AND winlostdate BETWEEN @TempFromDate AND @todate
		--exclude metric gaming running ticket
		AND (b.bettype NOT BETWEEN 801 AND 806 OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
	UNION ALL
	SELECT 
		DISTINCT gameID bettype 
		FROM translog (nolock)
	WHERE 
		winlostdate BETWEEN @TempFromDate AND @todate		
		AND custid = @CustID
		AND statusID = 0
		
			
END
IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		set @TempToDate = @MoveBetsDay
	ELSE
		set  @TempToDate = @ToDate
	
	IF @BalanceUpDay < @FromDate 
		SELECT @BalanceUpDay=@FromDate
	
	INSERT INTO @BettypeTable
	SELECT 
		DISTINCT bettype 
		FROM bettrans14 (nolock)
	WHERE 
		bettype < 19001 
		AND bettype <> 903
		AND custid = @CustID
		AND winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
END

IF @FromDate < @BalanceUpDay
BEGIN
	IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @todate
	
	INSERT INTO @BettypeTable
	SELECT 
		DISTINCT bettype
	FROM DBARC.bodb_archive.dbo.bettrans_bk with (nolock)
	WHERE 
		bettype < 19001
		AND bettype <> 903
		AND custid = @CustID
		AND winlostdate between @fromdate and @TempToDate 
END

DELETE @BettypeTable WHERE bettype = 903
select 
	typeid,
	typenamee
from bettype bt (nolock)
inner join (SELECT DISTINCT bettype FROM  @BettypeTable) btt on bt.typeid = btt.bettype


GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelBettype] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelBettype] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelBettype] TO [vnteam] 