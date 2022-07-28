/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

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
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @tmpParlay TABLE (
		TransId				BIGINT,
		BetId				TINYINT,
		BetCheck			VARCHAR(100),
		SportType			INT,
		LeagueId			INT,
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
		@CurrencyId			TINYINT,
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

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			ISNULL(b.betcheck, '') AS BetCheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyId AS Currency,
			m.matchid,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
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
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo
			AND b.custid = @CustId
			AND (b.winlostdate > @MoveBetsDay OR b.winlostdate IS NULL)
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY TransId DESC
END
GO
