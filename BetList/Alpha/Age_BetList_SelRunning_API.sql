/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelRunning_API]
	@CustId		INT			= NULL,
	@Username	VARCHAR(50)	= NULL,
	@Language	VARCHAR(2)	= 'E'
AS

/*
	Created:
	Task: Agent Web Service, function: GetAgentBetListRunning
	DB: DBBOF.bodb02
	Original: Age_BetList_SelRunningAll_API
	Revisions:
		- 20100107@Hanh: Get Odds Type, remove ComStatus column
		- 20110408@Amy: Change function to get Odds value and showed odds type
					- Remove status instead of statusID
		- 20110512@Johnson: Apply new arrange bettype
		- 20130924@Jamie: Change to bodb_Age / bettrans_running
		- 20180617@Kos: Change back to use bodb02.bettrans [#Redmine: 97037]
*/

BEGIN
	SET NOCOUNT ON

	if @custid is null
		select @custid = custid from customer with (nolock) where username = @username

	select
		convert(float, b.hdp1) as hdp1, convert(float, b.hdp2) as hdp2, 
		dbo.f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,  
		b.stake,
		b.betteam,
		b.status,
		convert(nvarchar(20),b.transid) AS refno,
		b.transdate,
		b.transid,
		b.bettype,
		b.matchid,
		case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee,
		case @Language when 'E' then h.teamname when 'J' then isnull(h.teamnamej, h.teamname) else isnull(h.teamnamec_uni, h.teamname) end as home,
		case @Language when 'E' then a.teamname when 'J' then isnull(a.teamnamej, a.teamname) else isnull(a.teamnamec_uni, a.teamname) end as away,
		case @Language when 'E' then l.leaguename when 'J' then isnull(l.leaguenamej, l.leaguename) else isnull(l.leaguenamec_uni, l.leaguename) end as leaguename,
		username,	
		(0-case when b.odds>0 then stake else stake*abs(b.odds) end)  winlost,
		(0) AS playercomm,
		b.mpositiontaking,
		b.apositiontaking,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.spositiontaking,	
		dbo.f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType  ,
		s.sportname,
		m.kickofftime
	from 
		bodb02.dbo.bettrans b with (nolock)
		--INNER JOIN dbo.customer AS c with (nolock) ON b.custid=c.custid 
		INNER JOIN dbo.match AS m with (nolock) ON b.matchid=m.matchid 
		INNER JOIN dbo.team AS h with (nolock) ON h.teamid=m.homeid 
		INNER JOIN dbo.team AS a with (nolock) ON a.teamid=m.awayid 
		INNER JOIN dbo.league AS l with (nolock) ON l.leagueid=m.leagueid 
		INNER JOIN dbo.bettype with (nolock) ON bettype.typeid=b.bettype
		inner join Sports as s with (nolock) on l.sporttype = s.sporttype
	where	
		b.recommend=@custid and
		b.statusID = 0  and
		b.bettype < 19999
	union all
	select
		b.hdp1,b.hdp2,
		b.odds ,
		b.stake,
		b.betteam,
		b.status,
		convert(nvarchar(20),b.transid) AS refno,
		b.transdate,
		b.transid,
		b.bettype,
		b.matchid,
		case @Language when 'E' then bettype.typenamee when 'J' then isnull(bettype.typenamej, bettype.typenamee) else isnull(bettype.typenamec_uni, bettype.typenamee) end as typenamee,
		case @Language when 'E' then h.teamname when 'J' then isnull(h.teamnamej, h.teamname) else isnull(h.teamnamec_uni, h.teamname) end as home,
		'' as away,
		case @Language when 'E' then l.leaguename when 'J' then isnull(l.leaguenamej, l.leaguename) else isnull(l.leaguenamec_uni, l.leaguename) end as leaguename,
		username,	
		(0-case when b.odds>0 then stake else stake*abs(b.odds) end)  winlost,
		(0) AS playercomm,
		b.mpositiontaking,
		b.apositiontaking,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.spositiontaking,
		0 as OddsType,
		s.sportname,
		m.kickofftime
	from 
		bodb02.dbo.bettrans b with (nolock)
		--INNER JOIN dbo.customer AS c with (nolock) ON b.custid=c.custid 
		INNER JOIN dbo.outright AS m with (nolock) ON b.matchid=m.orid
		INNER JOIN dbo.team AS h with (nolock) ON h.teamid=m.teamid
		INNER JOIN dbo.league AS l with (nolock) ON l.leagueid=m.leagueid 
		INNER JOIN dbo.bettype with (nolock) ON bettype.typeid=b.bettype
		inner join Sports as s with (nolock) on l.sporttype = s.sporttype 
	where
		b.recommend=@custid and
		b.statusID = 0 and
		b.bettype = 10
	UNION ALL
	select
		b.hdp1,b.hdp2,
		b.odds,b.stake,
		b.betteam,
		b.status,
		convert(nvarchar(20),b.transid) AS refno,
		b.transdate,
		b.transid,
		9 bettype,
		b.matchid,
		'Mix Parlay' typenamee,
		'' home,
		'' away,
		''  leaguename,
		username,	
		(0-case when odds>0 then stake else stake*abs(odds) end)  winlost,
		(0) playercomm,
		b.mpositiontaking,
		b.apositiontaking,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.spositiontaking,
		0 as OddsType,
		'',
		''
	from 
		bodb02.dbo.bettrans b (nolock) 
		--INNER JOIN dbo.customer c (nolock) ON b.custid=c.custid
	where
		b.recommend=@custid and		
		b.statusID = 0  and
		b.bettype = 9
END


GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelRunning_API]  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelRunning_API]  TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunning_API] TO [vnteam]
GO
