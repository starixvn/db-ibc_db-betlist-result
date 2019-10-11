/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BA_BetList]
	@Username		VARCHAR(50) = NULL,
	@Bettype		INT = 0,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@FromStake		INT = 0,
	@ToStake		INT = 0,
	@currency		INT = 0,
	@excludeTest	BIT = 0,
	@TotalRows		INT = 0 OUTPUT,
	@PageSize		INT=1000,
	@PageIndex		INT=1
	WITH RECOMPILE
AS

/*
	Created: Henry 
	Date: 2011-04-15
	Task : Betlist for BA
	DB: DBACC.bodb02

	Revisions:
		- 20110914: Show virtual rate + virtual amt
		- 20110929: Show column actual rate
		- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111208@Jim: change condition bettype <31 
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120803@Jim: add playercomm value ( for give commission to member) 
		- 20130123@Daniel: Change link server alias
		- 20191011@Kos: Support drop table LicenseeBATransaction [Redmine: #103656]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustID INT

	SET @Username = ISNULL(LTRIM(RTRIM(@Username)), '')

	IF LEN(@Username) <> 0
	BEGIN
		SELECT @CustID = CustID FROM Customer c WITH (NOLOCK)
		WHERE 
			srecommend IN (SELECT CustID FROM f_depsuper_1('All'))
			AND RoleID = 1 
			AND 
			(
				c.username LIKE '%' + @Username + '%' OR
				SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) LIKE '%' + @Username + '%'
			)
	END

	DECLARE @BetListByDateMem AS TABLE(
		Sporttype		INT,
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Modds			SMALLMONEY,
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,	
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		AmtDueToBAReal	MONEY,
		comm			MONEY,
		playercomm		MONEY,
		discount		DECIMAL(9,8),
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		LeagueID		INT,
		MatchID			INT,
		MatchCode		NVARCHAR(50),
		HomeID			INT,
		AwayID			INT, 	
		isNeutral		BIT,
		currency		INT,
		CustID			INT,
		virtualrate		float,
		actualrate		float,
		AmtDueToBAVirtual	MONEY
	)

	DECLARE @TempBetList AS TABLE(
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Modds			SMALLMONEY,
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,	
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		AmtDueToBAReal	MONEY,
		comm			MONEY,
		playercomm		MONEY,
		discount		DECIMAL(9,8),
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		currency		INT,
		CustID			INT,
		MatchID			INT,
		virtualrate		float,
		actualrate		float,
		AmtDueToBAVirtual			MONEY
	)

	Declare @TempFromDate DATETIME
	Declare @TempToDate DATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		--general
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate, 
			b.betteam, --Betteam
			--b.status AS Status,				
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			(b.comm * b.actualrate) AS acomm,
			(b.playercomm* b.actualrate ) AS PlayerComm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.custid,
			b.matchid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		FROM
			bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK)	ON b.transid = BA.transid			
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate
			AND ((LEN(@Username) = 0) OR (LEN(@Username) <> 0 AND b.custid = @CustID))
			AND ((@Bettype=0) OR (@Bettype<>0 AND b.bettype = @Bettype))

		--sportbook
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			m.HomeID,
			m.AwayID, 		
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999 )) AND
			b.bettype NOT IN (9,29,10)

		-- Outright
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			b.BetID,
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,	
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.TeamID, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
			INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10

		-- Mix Parlay		
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.Status,
			b.refno,
			b.Transdate,	
			b.winlostdate,
			b.Winlost,
			b.AmtDueToBAReal,
			b.comm,	
			b.playercomm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 

		--Combination Mixed Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.Status,
			b.refno,
			b.Transdate,	
			b.winlostdate,
			b.Winlost,
			b.AmtDueToBAReal,
			b.comm,	
			b.playercomm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 29	
			AND b.matchid = 29
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @ToDate
	
		IF @BalanceUpDay < @FromDate 
			SELECT @BalanceUpDay=@FromDate

		DELETE FROM @TempBetList
	
		--General
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate, 
			b.betteam, --Betteam
			b.status AS Status,
			b.refno,
			b.Transdate,	
			b.winlostdate,
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			(b.comm * b.actualrate) AS acomm,
			( b.playercomm*actualrate ) AS PlayerComm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.custid,
			b.matchid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		FROM
			bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK)	ON b.transid = BA.transid			
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND ((LEN(@Username) = 0) OR (LEN(@Username) <> 0 AND b.custid =@CustID))
			AND ((@Bettype=0) OR (@Bettype<>0 AND b.bettype = @Bettype))
	
		--sportbook
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,	
			b.Winlost,					
			b.AmtDueToBAReal,
			b.comm,	
			b.playercomm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			m.HomeID,
			m.AwayID, 		
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 					
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
			AND b.bettype NOT IN (9,29,10)

		--mix parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,					
			b.AmtDueToBAReal,
			b.comm,	
			b.playercomm,
			b.discount,	
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS isNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 

		--Combination Mixed Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,					
			b.AmtDueToBAReal,
			b.comm,	
			b.playercomm,
			b.discount,	
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS isNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 29	
			AND b.matchid = 29

		--outright	
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			b.BetID,
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,					
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,	
			b.discount,	
			0 AS LiveIndicator, 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.TeamID, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS isNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
			INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate
	
		DELETE FROM @TempBetList
	
		--for general
		INSERT INTO @TempBetList	
		SELECT
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.Oddstype,
			b.Odds,
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate, 
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake)* b.actualrate Winlost,
			- (b.winlost - b.actual_stake + b.comm)* b.actualrate,
			(b.comm* b.actualrate) AS comm ,
			( b.playercomm*b.actualrate ) AS PlayerComm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.custid,
			b.matchid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		FROM
			bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK)
			INNER JOIN bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK,INDEX=IX_transid) ON b.transid = BA.transid
		WHERE 
			b.winlostdate BETWEEN @fromdate AND @TempToDate
			AND ((LEN(@Username) = 0) OR (LEN(@Username) <> 0 AND b.custid =@CustID))
			AND ((@Bettype=0) OR (@Bettype<>0 AND b.bettype = @Bettype))

		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			modds,
			b.Oddstype,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.status AS Status,
			b.refno,
			b.Transdate,	
			b.winlostdate,
			b.winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			m.HomeID,
			m.AwayID, 		
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b	
			INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999 )) AND
			b.bettype NOT IN (9,29,10)

		-- Outright
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,	
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.TeamID, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b		
			INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10

		-- Mix Parlay		
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9
	
		--Combination Mixed Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.AmtDueToBAReal,
			b.comm,
			b.playercomm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			b.AmtDueToBAVirtual
		FROM
			@TempBetList b
		WHERE
			b.bettype = 29
			AND b.matchid = 29
	END

	--Update Betteam, odds and oddstype
	UPDATE @BetListByDateMem
	SET betteam = dbo.f_GetChoice(betteam,bettype,'E')-- edit
	WHERE bettype IN (14,16)

	UPDATE @BetListByDateMem
	SET odds = CASE WHEN OddsType = 1 THEN odds + 1
					WHEN OddsType = 5 THEN odds * 100
					ELSE odds END		
	WHERE bettype IN (1,2,3,7,12,8,20)	

	UPDATE @BetListByDateMem
	SET OddsType = 0 
	WHERE bettype NOT IN (1,2,3,7,12,8,20)

	DECLARE @RowStart INT, @RowEnd INT  
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	IF @excludeTest=1
	BEGIN
		DELETE FROM @BetListByDateMem WHERE Currency = 20
	END 

	IF @currency<>0
	BEGIN
		DELETE FROM @BetListByDateMem WHERE currency <> @currency
	END

	IF (@FromStake<>0 AND @ToStake = 0)
	BEGIN
		DELETE FROM @BetListByDateMem WHERE stake < @FromStake
	END
	ELSE IF (@FromStake=0 AND @ToStake <> 0)
	BEGIN
		DELETE FROM @BetListByDateMem WHERE stake > @ToStake
	END
	ELSE IF (@FromStake<>0 AND @ToStake <> 0)
	BEGIN
		DELETE FROM @BetListByDateMem WHERE stake NOT BETWEEN @FromStake AND @ToStake
	END

	SELECT
		@TotalRows =  COUNT(TransID)
	FROM @BetListByDateMem

	SELECT A.* 
	FROM	
	(
		SELECT
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			b.*,
			c.UserName ,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
			e.currency as CurrencyName
		FROM @BetListByDateMem b
			INNER JOIN Customer c WITH (NOLOCK) ON b.CustID = c.CustID
			INNER JOIN Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
END
GO


GRANT EXECUTE ON [dbo].[Acc_BA_BetList] TO bodbAdminNet
GO
