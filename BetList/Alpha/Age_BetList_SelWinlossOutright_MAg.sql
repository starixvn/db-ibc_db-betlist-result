USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossOutright_MAg]
	@CustID int=null, --superID
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@leagueID int=NULL,
	@Language varchar(2) = 'E',
	@MoveBetsDay smalldatetime
AS
/*
Created:
Task : get bet tickets for outright, horse racing
DB: DB05.bodb02
Original: 

Revisions:    
	- 20090407@[HanhVu]: remove redundant transid field
	- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
	- 20090505@HiepVo: Change formula of commission
	- 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency.
	- 20101007@Henry: Change column transid from INT to BIGINT
	- 20101224@Johnson: change type of bettype to smallint in temporary table
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120927@Sophia: Get comstatus
	- 20150420@Tom: Add @leagueID parameter
	- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/
SET NOCOUNT ON
DECLARE @MAgWinlossOutright TABLE(
	sporttype smallint,
	username nvarchar(30), 
	bettype smallint,				
	transid bigint,
	matchcode varchar(30),
	homeID int,
	awayID int,
	hdp1 smallmoney,
	hdp2 smallmoney,
	odds money,
	status nvarchar(10),
	stake money,
	winlost money,
	awinlost money,
	mwinlost money,
	swinlost money,
	
	playercomm money,
	comm money,
	acomm money,
	scomm money,
	
	transdate datetime,
	betteam nvarchar(25),
	apositiontaking smallmoney,
	mpositiontaking smallmoney,	
	adiscount smallmoney,
	mdiscount smallmoney,	
	liveindicator bit,
	livehomescore smallint,
	liveawayscore smallint,
	leagueID int,
	matchid int, 
	IP varchar(20),
	betstatus varchar(20),
	isNeutral bit,
	comstatus NVARCHAR(20)
)
IF @Todate > @MoveBetsDay
BEGIN
	INSERT INTO @MAgWinlossOutright SELECT
		l.sporttype,
		b.username,
		b.bettype,					
		b.transid,
		m.matchcode,
		m.teamID,
		0,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.status,
		b.stake,
		(b.winlost-actual_stake),
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.betteam,
		b.apositiontaking,
		b.mpositiontaking,		
		b.discount as adiscount,
		b.adiscount as mdiscount,			
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		l.leagueID,
		b.matchid, 
		b.IP as IP,
		NULL,
		CONVERT(BIT,0) as IsNeutral,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans b with (nolock) 
		inner join outright m with (nolock) on b.matchid=m.orid	
		inner join League l with (nolock) on m.leagueID=l.leagueID		
	WHERE
		b.MRecommend=@CustID AND
		b.Winlostdate>=@FromDate AND
		b.Winlostdate<=@ToDate AND
		b.Bettype=10 AND
		b.Ruben=1AND
		(@leagueID IS NULL OR m.leagueID = @leagueID)
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	INSERT INTO @MAgWinlossOutright SELECT
		l.sporttype,
		b.username,
		b.bettype,					
		b.transid,
		m.matchcode,
		m.teamID,
		0,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.status,
		b.stake,
		(b.winlost-actual_stake),
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		
		b.playercomm,
		(b.comm - b.playercomm) as comm,
		(b.acomm - b.comm) as acomm ,
		(b.scomm - b.acomm) as scomm,
		
		b.transdate,
		b.betteam, 
		b.apositiontaking,
		b.mpositiontaking,		
		b.discount as adiscount,
		b.adiscount as mdiscount,		
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		l.leagueID,
		b.matchid, 
		b.IP as IP,
		NULL,
		CONVERT(BIT,0) as IsNeutral,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM
		bettrans14 b with (nolock) 
		inner join outright14 m with (nolock) on b.matchid=m.orid	
		inner join League l with (nolock) on m.leagueID=l.leagueID
	WHERE
		b.MRecommend=@CustID AND
		b.Winlostdate>=@FromDate AND
		b.Winlostdate<=@ToDate AND
		b.Bettype=10 AND
		b.Ruben=1	AND
		(@leagueID IS NULL OR m.leagueID = @leagueID)
END

SELECT * FROM @MAgWinlossOutright ORDER BY Status, Transid

		
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossOutright_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossOutright_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossOutright_MAg] TO [VNTeam]