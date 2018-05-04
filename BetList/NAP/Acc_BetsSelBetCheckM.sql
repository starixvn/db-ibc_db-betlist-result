/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckM]
	@TransId	BIGINT,
	@RefNo		BIGINT,
	@Language	NVARCHAR(2) = 'E'
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Get info of Mix Parlay Bets
	DB: DBAGE.bodb02
	Original: SP mteamlist

	Revisions:
		- 20060222@[]: remove refno
		- 20060310@[]: remove odds depend
		- 20090408@PhuongDao: Get checktime as SettleTime
		- 20090514@Simon: Remove RefNo
		- 20091003@Jamie: Remove comstatus out
		- 20091125@Henry: Select appropriate info to avoid redundant data
		- 20091128@Daniel: Fix the issue Mix Parlay Tennis - Cross Day - Move Bet problems: get more data in bettransm14 for Refno in Bettrans
		- 20091204@Henry: Change logic to get data for future Mix Parlay (combine Acc_BetsSelBetCheckM & Acc_BetsSelBetCheckM_History)
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110513@Lukas: re-arrange bettype
		- 20110928@Johnson: get column statusid to mark void sub-tickets
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20150415@Sophia: Get Betcheck for BEtRadar
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Return transdesc to support PH All In One 1.2 [#Redmine: 50897]
		- 20160407@Kos: Add TransId param, support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
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

	DECLARE @BetListMP TABLE(
		TransId			BIGINT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			NVARCHAR(20),
		StatusId		INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		LeagueId		INT,
		SportType		SMALLINT,
		IsNeutral		BIT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000)
	)

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId

	IF @CurrencyName IS NULL
	BEGIN
		SELECT @CurrencyName = ex.currency
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId

		IF @CurrencyName IS NULL
		BEGIN
			SELECT @CurrencyName = ex.currency
			FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId
		END
	END

	-- Get parlay selection detail
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
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
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.isNeutral,
			m.matchid,
			m.matchcode,
			CASE
				WHEN b.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM 
			(SELECT
				bm.transid,
				bm.bettype,
				bm.stake,
				bm.matchid,
				bm.hdp1,
				bm.hdp2,
				bm.odds,
				bm.betteam,
				bm.statusID,
				bm.livehomescore,
				bm.liveawayscore,
				bm.liveindicator,
				bm.betcheck,
				bm.transdesc,
				sbt.ProductId
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo ) AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo )
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
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.isNeutral,
			m.matchid,
			m.matchcode,
			CASE
				WHEN b.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM 
			(SELECT
				bm.transid,
				bm.bettype,
				bm.stake,
				bm.matchid,
				bm.hdp1,
				bm.hdp2,
				bm.odds,
				bm.betteam,
				bm.statusID,
				bm.livehomescore,
				bm.liveawayscore,
				bm.liveindicator,
				bm.betcheck,
				bm.transdesc,
				sbt.ProductId
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo) AS b
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	SELECT DISTINCT * FROM @BetListMP
	ORDER BY TransID DESC
END







GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetCheckM] TO [vnteam]
GO
