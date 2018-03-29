USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_BetList_SelParlayDetail]    Script Date: 10/17/2014 12:51:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelParlayByTransID]
	@TransId	BIGINT,
	@Language	VARCHAR(2) = 'E'
AS

/*
	Created: 20141017@Bobby
	Task: Get Betlist Parlay by TransID
	DB: DBEXT.bodb02
	Orgiginal: DBEXT.bodb02.dbo.Age_BetList_SelParlayDetail

	Revisions:
		- 20141017@Bobby: Initial SP
		- 20160425@Bobby: #56136 - Support Combo Parlay
		- 20161013@Kos: Add product bet type range for sub tables [Redmine: #65045]
		- 20170324@Kos: Hotfix - Mix Parlay duplicate ticket detail [Redmine: #73984]
		- 20180329@Kos: Increase TransDesc length to 1000 [#Redmine: 92845]
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

	DECLARE @tmpParlay TABLE (
		TransId			BIGINT,
		SportType		INT,
		LeagueId		INT,
		BetType			INT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		Stake			MONEY,
		Currency		VARCHAR(10),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			SMALLMONEY,
		BetTeam			NVARCHAR(50),
		StatusId		INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000))

	DECLARE @RefNo 		BIGINT
		, @CustId 		INT
		, @CurrencyCode	VARCHAR(3)

	SELECT @RefNo = refno
		, @CustId = custid
		, @CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE TransID = @TransId

	IF @RefNo IS NULL
	BEGIN
		SELECT @RefNo = refno,
			@CustId = custid,
			@CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
		FROM dbo.bettrans14 AS b WITH (NOLOCK) 
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE TransID = @TransId

		IF @RefNo IS NULL
		BEGIN
			SELECT @RefNo = refno,
				@CustId = custid,
				@CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
			FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK) 
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE TransID = @TransId
		END
	END

	IF EXISTS (	SELECT 1
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
			m.matchid,
			m.homeid,
			m.awayid,
			b.Stake,
			@CurrencyCode AS Currency,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			b.betcheck,
			b.transdesc
		FROM (	SELECT
					bm.transid,
					bm.matchid,
					bm.bettype,
					bm.stake,
					bm.hdp1,
					bm.hdp2,
					bm.odds,
					bm.betteam,
					bm.statusID,
					bm.livehomescore,
					bm.liveawayscore,
					bm.liveindicator,
					bm.betcheck,
					ISNULL(bm.transdesc, '') AS transdesc
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE refno = @RefNo AND custID = @CustId
			) AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
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
			m.matchid,
			m.homeid,
			m.awayid,
			b.Stake,
			@CurrencyCode AS Currency,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.BetCheck,
			b.transdesc
		FROM (	SELECT
					bm.transid,
					bm.matchid,
					bm.bettype,
					bm.stake,
					bm.hdp1,
					bm.hdp2,
					bm.odds,
					bm.betteam,
					bm.statusID,
					bm.livehomescore,
					bm.liveawayscore,
					bm.liveindicator,
					bm.betcheck,
					ISNULL(bm.transdesc, '') AS transdesc
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId
			) AS b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS (	SELECT 1
				FROM DBARC.bodb_archive.dbo.BettransM AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.Sporttype,
			m.LeagueID,
			b.Bettype,
			m.MatchId,
			m.homeID,
			m.awayID,
			b.Stake,
			@CurrencyCode AS Currency,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.BetCheck,
			b.transdesc
		FROM(	SELECT 
					bm.transid,
					bm.matchid,
					bm.bettype,
					bm.stake,
					bm.hdp1,
					bm.hdp2,
					bm.odds,
					bm.betteam,
					bm.statusID,
					bm.livehomescore,
					bm.liveawayscore,
					bm.liveindicator,
					bm.betcheck,
					ISNULL(bm.transdesc, '') AS transdesc
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custID = @CustId
			) AS b
			INNER JOIN DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY TransId DESC 
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelParlayByTransID] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelParlayByTransID] TO [bodbDownlineNet] AS [dbo]
GO
