/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_Parlay_GetSubTickets]
	@TransId	BIGINT,
	@CustId		INT,
	@HeadlineId	INT		= 0
AS

/*
	Created: Kos@20190304
	Task: Get sub tickets of Parlay tickets of CN88
	DB: DBACC.bodb02
	Original: Age_BetList_SelParlayDetail

	Revisions:
		- 20190304@Kos: Create new [Redmine: #109230]
		- 20190926@Kos: Hotfix - duplicate data during Balance Up [Redmine: #120962]
		- 20190920@Kos: Support Move Super, add new param @HeadlineId [Redmine: #118962]
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

	DECLARE @tmpParlay TABLE (
		TransId			BIGINT,
		SportType		INT,
		LeagueId		INT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		MatchId			INT,
		EventDate		DATETIME,
		ShowTime		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		Status			NVARCHAR(10),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000)
	)

	DECLARE @RefNo		BIGINT,
		@CurrencyName	NVARCHAR(50),
		@Status			NVARCHAR(10),
		@WinLostDate	SMALLDATETIME

	SELECT
		@RefNo = b.refno,
		@CurrencyName = ex.currency,
		@Status = b.status,
		@WinLostDate = b.winlostdate
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@CurrencyName = ex.currency,
			@Status = b.status,
			@WinLostDate = b.winlostdate
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId AND b.custid = @CustId

		IF @RefNo IS NULL
		BEGIN
			SELECT
				@RefNo = b.refno,
				@CurrencyName = ex.currency,
				@Status = b.status,
				@WinLostDate = b.winlostdate
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId AND b.custid = @CustId
		END
	END

	IF @HeadlineId > 0		-- Headline view
	BEGIN
		DECLARE @SuperId INT

		DECLARE @tblWinLostDate TABLE (FromDate DATETIME, ToDate DATETIME)

		SELECT @SuperId = srecommend
		FROM bodb02.dbo.Customer WITH (NOLOCK)
		WHERE custid = @CustId

		INSERT INTO @tblWinlostDate (FromDate, ToDate)
		SELECT DISTINCT
			FromDate,
			ToDate
		FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
		WHERE UplineId = @HeadlineId AND SuperId = @SuperId

		IF NOT EXISTS (SELECT 1 FROM @tblWinlostDate WHERE @WinLostDate BETWEEN FromDate AND ToDate)
		BEGIN
			SET @RefNo = NULL
		END
	END

	IF EXISTS ( SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			b.matchid,
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
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			b.matchid,
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
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			b.matchid,
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
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custID = @CustId
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY TransId DESC
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_Parlay_GetSubTickets] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_Parlay_GetSubTickets] TO [bodbDownlineNetView]
GO
