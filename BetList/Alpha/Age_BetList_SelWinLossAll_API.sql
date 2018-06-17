ALTER PROCEDURE [dbo].[Age_BetList_SelWinLossAll_API]
	@custid int,
	@fromdate smalldatetime,
	@todate smalldatetime,
	@language varchar(2) = 'E',
	@movebetsday smalldatetime
AS
/*
Created: 
Task : Agent Web Service, function: GetAgentBetListWinLoss
DB: DB053.bodb02
Original:
Revisions:
	- 20070519@Thien: add username for calling from API
	- 20070528@Thien: Always get data from bettrans and bettrans14
	- 20080104@Vinh: Remove @GetOldData
	- 20080417@Phuc: Add matchid
	- 20080620@Vinh: Add betstatus
	- 20080629@Viet: remove UNION, uses temporary table instead, Remove Teamname, Leaguename, Sportname, TypeName also.
	- 20080805@Thien:-- Remove DB06.bodb_archive.dbo.bettrans_bk, separate to new DB.
					 --Remove temp Table Also
					 --Add @MoveBetsDay
	- 20080611@VinhTrinh: Get more result(Sporttype: Horseracing) for betlist
    - 20100107@Hanh: Get Odds Type, remove ComStatus column
    - 20110408@Amy: Change function to get Odds value and showed odds type 
					remove status instead of statusID
	- 20110421@Amy: Change TransID to BIGINT
	- 20110512@Johnson: Apply new arrange bettype
	- 20111201@Jamie: Get two more fields: apositiontaking & discount 
*/

SET NOCOUNT ON

DECLARE @MemberList TABLE(
	custid int,
	username nvarchar(20),
	ugroup varchar(3)
)
insert into @MemberList
	select custid,username,ugroup 
	from customer c(nolock) where c.recommend=@CustID
--*end-region: List of members of the agent

--No Oddstype
DECLARE @BetListByDateMem TABLE(
	Sporttype smallint,
	Username nvarchar(20), 
	TransID bigint,
	Bettype smallint,
	hdp1 smallmoney, 
	hdp2 smallmoney, 
	Odds smallmoney, 
	Stake money, 
	Betteam nvarchar(20),
	Status nvarchar(10),
	RefNO bigint,
	Transdate datetime,
	Winlostdate datetime,
	Winlost money,
	Comm money,
	AWinlost money,
	AComm money,
	
	Liveindicator bit,
	Livehomescore smallint,
	Liveawayscore smallint,
	IP nvarchar(15),	
	LeagueID int,
	MatchID int,
	MatchCode nvarchar(50),--VinhTrinh Add for Horseracing
	Race nvarchar(20),--VinhTrinh Add for Horseracing
	HomeID int,
	AwayID int, 	
	Betstatus nvarchar(50),
	isNeutral bit,
	OddsType varchar(10),
	apositiontaking SMALLMONEY,
	discount SMALLMONEY
)
IF @Todate > @MoveBetsDay
BEGIN
	INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			c.username, 
			b.TransID,
			b.Bettype,
			b.hdp1, 
			b.hdp2, 
			dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,  
			b.Stake, 
			dbo.f_GetChoice(b.betteam, b.bettype,@Language), --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,			
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' as Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType 
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans AS b with (nolock)		
			INNER JOIN dbo.match AS m with (nolock) ON b.matchid=m.matchid 	
			INNER JOIN @MemberList as c on b.custid=c.custid	
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and --to improve performance
			b.statusID <> 0  and
			b.bettype <= 19000
	
	-- Outright, Horseracing	
	INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			c.username, 
			b.TransID,
			b.Bettype,
			0 as hdp1, 
			0 as hdp2, 
			b.Odds, 
			b.Stake, 
			'' as Betteam, --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			0 as LiveIndicator , 
			0 as LiveHomescore, 
			0 as LiveAwayscore,
			b.IP,			
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) as IsNeutral,
			0
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans AS b with (nolock)		
			INNER JOIN dbo.Outright AS m with (nolock) ON b.matchid=m.orid
			INNER JOIN dbo.League as l with (nolock) ON m.leagueID = l.leagueID
			INNER JOIN @MemberList as c on b.custid=c.custid	
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and
			b.statusID <> 0  and
			b.bettype in (10, 31, 32, 33)

	-- Mix Parlay		
	INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			c.username, 
			b.TransID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			b.Odds, 
			b.Stake, 
			dbo.f_GetChoice(b.betteam, b.bettype,@Language), --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,			
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) as IsNeutral,
			0
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans AS b with (nolock)	
			INNER JOIN @MemberList as c on b.custid=c.custid	
			--left join dbo.Match_Remark as mr with (nolock) on mr.matchid = b.matchid
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and			
			b.statusID <> 0 and
			b.bettype = 9
END

IF @Fromdate <= @MoveBetsDay
BEGIN	
	INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			c.username, 
			b.TransID,
			b.Bettype,
			b.hdp1, 
			b.hdp2, 
			dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,  
			b.Stake, 
			dbo.f_GetChoice(b.betteam, b.bettype,@Language), --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,			
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' as Race,	--Race
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType  
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans14 AS b with (nolock, index=bettrans1413)		
			INNER JOIN dbo.match14 AS m with (nolock) ON b.matchid=m.matchid
			INNER JOIN @MemberList as c on b.custid=c.custid	 					
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and
			b.statusID <> 0  and
			b.bettype <= 19000

	INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			c.username, 
			b.TransID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			b.Odds, 
			b.Stake, 
			dbo.f_GetChoice(b.betteam, b.bettype,@Language), --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,			
			0, --LeagueID
			0, --MatchID
			'',--MatchCode
			'',--Race	
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) as isNeutral,
			0
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans14 AS b with (nolock, index=bettrans1413)	
			--LEFT JOIN dbo.Match_Remark as mr with (nolock) on b.matchid = mr.matchid		
			INNER JOIN @MemberList as c on b.custid=c.custid			
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and			
			b.statusID <> 0  and
			b.bettype = 9
		
			
	INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			c.username, 
			b.TransID,
			b.Bettype,
			0 as hdp1, 
			0 as hdp2, 
			b.Odds, 
			b.Stake, 
			'' as Betteam, --Betteam
			b.Status,
			b.TransID,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.PlayerComm,
			b.awinlost,
			b.comm,
			
			0 as LiveIndicator, 
			0 as LiveHomescore, 
			0 as LiveAwayscore,
			b.IP,			
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch as Race,--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) as isNeutral,
			0
			,b.apositiontaking,
			b.discount 
		FROM
			dbo.bettrans14 AS b with (nolock, index=bettrans1413)		
			INNER JOIN dbo.Outright14 AS m with (nolock) ON b.matchid=m.orid
			INNER JOIN dbo.League as l with (nolock) ON m.leagueID = l.leagueID
			INNER JOIN @MemberList as c on b.custid=c.custid	
		WHERE
			b.winlostdate between @fromdate and @todate and
			b.recommend = @custid and
			b.statusID <> 0  and
			b.bettype in (10, 31, 32, 33)
END		
	
SELECT * FROM  @BetListByDateMem ORDER BY RefNO



GO
GRANT	EXECUTE	ON	Age_BetList_SelWinLossAll_API	TO	bodbDownlineNet
GO
GRANT	EXECUTE	ON	Age_BetList_SelWinLossAll_API	TO	bodbDownlineNetView
GO
GRANT	VIEW DEFINITION	ON	Age_BetList_SelWinLossAll_API	TO	vnteam
GO
