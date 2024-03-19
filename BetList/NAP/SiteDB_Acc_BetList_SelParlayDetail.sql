/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelParlayDetail]
	@TransId		BIGINT,
	@RefNo			BIGINT,
	@CustId			INT,
	@IsCN88			BIT				= 0,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20220727@Kos
	Task: NAP - Bet List - Get parlay ticket detail
	DB: DBSIG.bodb02

	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20231129@Razor: Support Project 777 - return SpecialPlatfrom [Redmine: #194591]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook, Betradar Virtual Sports only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @BetListMP TABLE (
		TransId				BIGINT,
		BetType				INT,
		Stake				MONEY,
		Currency			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		BetTeam				NVARCHAR(10),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		BIT,
		LeagueId			INT,
		SportType			SMALLINT,
		IsNeutral			BIT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		LeagueGroupId		SMALLINT
	)

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@Status				NVARCHAR(10),
		@MainTicketIsMarked BIT,
		@IsChinaView 		BIT,
		@SpecialPlatfrom	SMALLINT

	SELECT @MainTicketIsMarked = COUNT(1)
	FROM dbo.MarkedTransaction WITH (NOLOCK)
	WHERE transid = @TransId 
		AND MatchId = 29

	SELECT
		@CurrencyName = ex.currency,
		@Status = b.status,
		@IsChinaView = s.IsChinaView,
		@SpecialPlatfrom = s.SpecialPlatfrom
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		LEFT JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON c.CustId = b.CustId
		LEFT JOIN CustDB.dbo.Site AS s WITH (NOLOCK) ON s.Site = c.Site
	WHERE b.transid = @TransId AND b.custid = @CustId

	-- Get parlay selection detail
	IF EXISTS(	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			b.transid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN @IsCN88 = 1 AND @Status = 'Reject' AND b.status = 'Reject' THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			CASE 
				WHEN b.status IN ('WON','LOSE','DRAW') AND @MainTicketIsMarked = 1 THEN 255
				ELSE ISNULL(m.SettlementStatus, 0)
			END AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.IsNeutral,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.matchid
				ELSE m.matchid
			END AS MatchId,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.matchcode
				ELSE m.matchcode
			END AS MatchCode,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.GlobalShowTime
				ELSE m.GlobalShowTime
			END AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.showtime
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc,
			l.LeagueGroupId
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN dbo.match AS pm WITH (NOLOCK)
				ON pm.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
			LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE b.refno = @RefNo
			AND b.custid = @CustId
			AND (b.winlostdate IS NULL OR b.winlostdate > @MoveBetsDay)
	END

	SELECT DISTINCT *,
		@IsChinaView AS IsChinaView,
		@SpecialPlatfrom AS SpecialPlatfrom
	FROM @BetListMP
	ORDER BY TransId DESC
END
GO