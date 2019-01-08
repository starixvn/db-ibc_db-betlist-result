/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_Rpt_BetList_Parlay_SubTickets]
	@TransId	BIGINT,
	@RefNo		BIGINT,
	@CustId		INT
AS

/*
	Created by: 20190125@Kos
	Task: Get sub tickets of Parlay tickets (bettype 9, 29, 2799)
	DB: DBAGE.bodb02
	Original: Acc_BetsSelBetCheckM_All

	Revisions:
		- 20190125@Kos: Support Parlay Changes [#Redmine: 105585]
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
		TransId			BIGINT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			NVARCHAR(10),
		Status			NVARCHAR(10),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		LeagueId		INT,
		SportType		SMALLINT,
		IsNeutral		BIT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		EventDate		DATETIME,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000)
	)

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@Status				NVARCHAR(10)

	SELECT
		@CurrencyName = ex.currency,
		@Status = b.status
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @CurrencyName IS NULL
	BEGIN
		SELECT
			@CurrencyName = ex.currency,
			@Status = b.status
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId AND b.custid = @CustId

		IF @CurrencyName IS NULL
		BEGIN
			SELECT
				@CurrencyName = ex.currency,
				@Status = b.status
			FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId AND b.custid = @CustId
		END
	END

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
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.IsNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS(	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
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
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.IsNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS(	SELECT 1
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
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
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.isNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	SELECT DISTINCT * FROM @BetListMP
	ORDER BY TransId DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_BetList_Parlay_SubTickets] TO [bodbAdminNet]
GO
