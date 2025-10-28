/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_SelParlayDetail]
	@TransId		BIGINT,
	@CustId			INT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: 20220727@Kos
	Task: LAP - Bet List - Get parlay sub tickets - SiteDB
	DB: DBSID.bodb02

	Revisions:
		- 20220727@Kos: Created [Redmine: #175297]
		- 20230522@Kos: Hotfix - Can not show all parlay detail [Redmine: #188539]
		- 20231225@Kos: Hide Saba text for Jollysports licensees [Redmine: 198697]
		- 20240305@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240801@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20251014@Kelvin: Upgrade ExchangeId Datatype [Redmine: #222339]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype(ProductId, Bettype, EventType)
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27, 83, 88)

	DECLARE @tmpParlay TABLE (
		TransId				BIGINT,
		BetId				TINYINT,
		BetCheck			VARCHAR(100),
		SportType			INT,
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		BetType				INT,
		Stake				MONEY,
		Currency			INT,
		MatchId				INT,
		EventDate			DATETIME,
		ShowTime			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		BetTeam				NVARCHAR(50),
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		BIT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		TransDesc			NVARCHAR(1000))

	DECLARE @RefNo			BIGINT,
		@CurrencyId			SMALLINT,
		@Status				NVARCHAR(10),
		@IsMainTicketMarked	BIT				= 0

	IF EXISTS ( SELECT 1 FROM dbo.MarkedTransaction WITH (NOLOCK) WHERE transid = @TransId AND MatchId = 29)
	BEGIN
		SET @IsMainTicketMarked = 1
	END

	SELECT
		@RefNo = b.refno,
		@CurrencyId = b.currency,
		@Status = b.status
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@CurrencyId = b.currency,
			@Status = b.status
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.transid = @TransId AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		(
			TransId,
			BetId,
			BetCheck,
			SportType,
			LeagueId,
			LeagueGroupId,
			BetType,
			Stake,
			Currency,
			MatchId,
			EventDate,
			ShowTime,
			HomeId,
			AwayId,
			Hdp1,
			Hdp2,
			Odds,
			BetTeam,
			LiveHomeScore,
			LiveAwayScore,
			LiveIndicator,
			BetStatus,
			IsNeutral,
			Status,
			SettlementStatus,
			TransDate,
			TransDesc
		)
		SELECT
			b.transid,
			NULL,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE
				WHEN sbt.EventType = 1 THEN m.sporttype
				WHEN sbt.EventType = 5 THEN m3rd.SportType
				ELSE 0
			END AS SportType,
			CASE
				WHEN sbt.EventType = 1 THEN m.leagueid
				WHEN sbt.EventType = 5 THEN m3rd.League3rdId
				ELSE 0
			END AS LeagueId,
			l.LeagueGroupID,
			b.bettype,
			b.stake,
			@CurrencyId AS Currency,
			b.matchid,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			CASE
				WHEN sbt.EventType = 1 THEN m.homeid
				WHEN sbt.EventType = 5 THEN m3rd.HomeId
				ELSE 0
			END AS HomeId,
			CASE
				WHEN sbt.EventType = 1 THEN m.awayid
				WHEN sbt.EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			CASE
				WHEN b.status IN ('WON','LOSE','DRAW') AND @IsMainTicketMarked = 1 THEN 255
				ELSE ISNULL(m.SettlementStatus, 0)
			END AS SettlementStatus,
			b.transdate,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON sbt.EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON sbt.EventType = 1 AND l.leagueid = m.leagueid
			LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON sbt.EventType = 5 AND m3rd.Match3rdId = b.matchid
		WHERE b.refno = @RefNo
			AND b.custid = @CustId
			AND (b.winlostdate > @MoveBetsDay OR b.winlostdate IS NULL)
	END

	SELECT DISTINCT
		TransId,
		BetId,
		BetCheck,
		SportType,
		LeagueId,
		LeagueGroupId,
		BetType,
		Stake,
		Currency,
		MatchId,
		EventDate,
		ShowTime,
		HomeId,
		AwayId,
		Hdp1,
		Hdp2,
		Odds,
		BetTeam,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		BetStatus,
		IsNeutral,
		Status,
		SettlementStatus,
		TransDate,
		TransDesc
	FROM @tmpParlay
	ORDER BY TransId DESC
END
GO
