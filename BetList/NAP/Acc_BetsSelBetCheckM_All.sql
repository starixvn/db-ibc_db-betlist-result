ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckM_All]
	@TransId	BIGINT,
	@RefNo		BIGINT,
	@Language	NVARCHAR(2) = 'E'
AS

/*
	Created by: Henry
	Date: 2009-12-05
	Task: Get info of Mix Parlay Bets
	DB: DBAGE.BODB02
	Original: Acc_BetsSelBetCheckM
	
	Revisions:
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110513@Lukas: re-arrange bettype
		- 20110928@Johnson: get column statusid to mark void sub-ticket
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20141006@Sophia: get Betcheck
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Return transdesc to support PH All In One 1.2 [#Redmine: 50897]
		- 20160407@Kos: Add TransId param, support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

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
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(200)
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
			FROM DBACC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId
		END
	END

	-- Get parlay selection detail
	IF EXISTS(	SELECT 1
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
				bm.transdesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo ) AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS(	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
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
				bm.transdesc
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo) AS b
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS(	SELECT 1
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
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
				bm.transdesc
			FROM DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo) AS b
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	SELECT * FROM @BetListMP
	ORDER BY TransId DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM_All] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM_All] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetCheckM_All] TO [vnteam]
