USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_CoreBetList_Running_SelBetTicket]    Script Date: 5/5/2015 1:45:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_SelRunning]
(
	-- MEM INFO
	@CustId				INT
	, @RoleId			TINYINT
	, @Username			NVARCHAR(50)	= NULL
	--Event
	, @MatchId			INT				= 0
	, @LiveIndicator	INT				= NULL
	, @BetTeam			NVARCHAR(20)	= ''
	-- PRODUCT - BETTYPE - STATUS
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @Language			VARCHAR(2)		= 'E'
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	, @Error			INT				= 0 OUTPUT
	, @ErrorMsg			VARCHAR(250)	= '' OUTPUT
)
AS

/*
	Created: Bobby
	Task: Aphla site - refactor betlist core 
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150814@Bobby: #41600 - Update time range to datetime formation
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20150925@Bobby: Add MO & CB ticket
		- 20151217@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20171109@Kos: Return IsNeutral for neutral match [#Redmine: 86312]
		- 20171113@Kos: Wrong column name [#Redmine: 86508]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180617@Kos: Move SP from bodb_Age to bodb02 [#Redmine: 97037]
					- Don't support Metric Gaming and translog anymore
		- 20180621@Kos: Add index hint for Master and Agent level [#Redmine: 97249]

	Param's Explanation:
		- @BettypeMatrix	: Table TYPE variable

	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		SportType			SMALLINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, BetType			SMALLINT
		, LeagueId			INT
		, RefNo				BIGINT
		, TransId			BIGINT
		, BetId				BIGINT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, MatchId			INT
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, Odds				MONEY
		, MOdds				MONEY
		, Status			NVARCHAR(10)
		, Stake				MONEY
		, Actual_Stake		MONEY
		, TransDate			DATETIME
		, BetTeam			NVARCHAR(20)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, Ip				NVARCHAR(15)
		, IsNeutral			BIT
		, OddsType			TINYINT
		, ShowTime			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, BetCheck			NVARCHAR(50)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		SMALLMONEY
		, ProductId			TINYINT
		, EventType			TINYINT
	)

	SELECT @Error	= 0
		, @ErrorMsg	= ''
		, @CustId	= ISNULL(@CustId, 0)
		, @MatchId	= ISNULL(@MatchId, 0)
		, @BetTeam	= ISNULL(@BetTeam, '')

	-- CHECK member info
	IF( (@CustId = 0 AND @RoleId = 1)
		AND @UserName IS NOT NULL
	)
	BEGIN
		SELECT TOP(1) @CustId = custid
		FROM bodb02.dbo.custinfo WITH (NOLOCK)
		WHERE username = @UserName
	END

	IF ISNULL(@CustId, 0) = 0
	BEGIN
		SELECT @Error 	= 100
			, @ErrorMsg	= 'The customer was not found.'

		RETURN;
	END

	IF @RoleId = 1
	BEGIN
		INSERT INTO @Data
		SELECT
			0 Sporttype
			, b.custid
			, b.Username
			, b.Bettype
			, 0 LeagueID
			, b.refno
			, b.TransID
			, b.BetID
			, '' MatchCode
			, '' Race
			, b.matchid
			, 0 HomeID
			, 0 AwayID
			, '' AS BetStatus
			, b.hdp1
			, b.hdp2
			, b.Odds
			, b.Modds
			,CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status
			, b.Stake
			, b.actual_stake
			, b.Transdate
			, b.Betteam
			, b.APositiontaking
			, b.MPositiontaking
			, b.SPositiontaking
			, b.tpositiontaking
			, b.discount AS Adiscount --Agent
			, b.adiscount AS Mdiscount --Master
			, b.sdiscount AS Sdiscount --Super
			, b.Liveindicator
			, b.Livehomescore
			, b.Liveawayscore
			, b.IP
			,CONVERT(BIT,0) IsNeutral
			, b.oddstype
			, '' showtime
			, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
			, b.BetCheck
			, '' AS transdesc
			, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
			, bt.productid
			, bt.eventtype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
	END

	IF @MatchId = 0
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				,CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.recommend = @CustId
				AND b.statusID IN (0, 1)
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				,CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.mrecommend = @CustId
				AND b.statusID IN (0, 1)
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				, CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			WHERE b.srecommend = @CustId
				AND b.statusID IN (0, 1)
		END
	END
	ELSE
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				,CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_betrunning_recommend)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.recommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				,CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN ('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX=IX_betrunning_mrecommend)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.mrecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.TransID
				, b.BetID
				, '' MatchCode
				, '' Race
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				, CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				,CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				,CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, CASE WHEN bt.SubProduct IN('MO') THEN b.OddsSpread ELSE 0 END AS OddsSpread
				, bt.productid
				, bt.eventtype
			FROM dbo.bettrans b WITH (NOLOCK, INDEX=IX_betrunning_srecommend)
				INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			WHERE b.srecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	END

	IF @LiveIndicator IS NOT NULL OR @BetTeam <> ''
	BEGIN
		DELETE b
		FROM @Data AS b
			INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
		WHERE ( @LiveIndicator IS NOT NULL
				AND bt.productid = 3
				AND b.Liveindicator <> @LiveIndicator)
			OR ( @BetTeam <> '' 
				AND bt.productid = 3
				AND b.betteam <> @BetTeam )
	END

	UPDATE b
	SET
		SportType	= m.sporttype,
		LeagueId	= m.leagueid,
		MatchCode	= m.matchcode,
		HomeId		= m.homeid,
		AwayId		= m.awayid,
		BetStatus	= m.betstatus,
		ShowTime	= m.showtime,
		IsNeutral	= m.IsNeutral
	FROM @Data AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
	WHERE b.EventType = 1

	UPDATE b
	SET
		SportType = l.sporttype,
		LeagueId = m.leagueid,
		MatchCode = m.matchcode,
		HomeId = m.teamid,
		AwayId = 0,
		ShowTime = ''
	FROM @Data AS b
		INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.MatchId = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.EventType = 2

	SELECT * FROM @Data
	ORDER BY TransId DESC

	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(300)
	)

	SELECT * FROM @BettransDetail
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SelRunning] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SelRunning] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CoreBetList_SelRunning] TO [vnteam]
GO
