USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelParlayDetail]    Script Date: 04/24/2015 08:52:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelParlayDetail]
	@TransId	BIGINT,
	@Langkey	VARCHAR(10) = 'en-US'
AS

/*
	Created: Henry@20101210
	Task : get parlay tickets
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelParlayDetail]

	Revisions:
		- 20110930@Henry: Add column statusID
		- 20111229@Henry: change the way to get odds/oddstype/betteam to web dev
		- 20141106@Florent: fix show SS bettype, get betcheck
		- 20141212@Florent: fix when betcheck = '' will return NULL
		- 20150424@Jim: support Betradar (add column betcheck in result)
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161007@Kos: Add product bet type range for sub tables [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @tmpParlay TABLE (
		TransId			BIGINT,
		BetId			TINYINT,
		BetCheck		VARCHAR(100),
		SportType		INT,
		LeagueId		INT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			FLOAT,
		Hdp2			FLOAT,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		StatusId		INT,
		TransDesc		NVARCHAR(200))

	DECLARE @RefNo		BIGINT,
		@CustId			INT,
		@CurrencyCode	VARCHAR(3)

	SELECT @RefNo = b.refno,
		@CustId = b.custid,
		@CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId

	IF @RefNo IS NULL
	BEGIN
		SELECT @RefNo = b.refno,
			@CustId = b.custid,
			@CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId

		IF @RefNo IS NULL
		BEGIN
			SELECT @RefNo = b.refno,
				@CustId = b.custid,
				@CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
			FROM DBACC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId
		END
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			b.betcheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyCode AS Currency,
			m.matchid,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS Hdp1,
			CONVERT(FLOAT, b.hdp2) AS Hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.statusID,
			b.transdesc
		FROM (
			SELECT
				bm.transid,
				CASE WHEN bm.betcheck = '' THEN NULL ELSE betcheck END AS betcheck,
				bm.stake,
				bm.matchid,
				bm.bettype,
				bm.hdp1,
				bm.hdp2,
				bm.odds,
				bm.betteam,
				bm.livehomescore,
				bm.liveawayscore,
				bm.liveindicator,
				bm.statusID,
				ISNULL(bm.transdesc, '') AS transdesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo AND bm.custid = @CustId
			) AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 WITH (NOLOCK)
				WHERE refno = @RefNo AND custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			b.betcheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyCode AS Currency,
			m.matchid,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS Hdp1,
			CONVERT(FLOAT, b.hdp2) AS Hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.statusID,
			b.transdesc
		FROM (
			SELECT
				bm.transid,
				CASE WHEN bm.betcheck = '' THEN NULL ELSE betcheck END AS betcheck,
				bm.stake,
				bm.matchid,
				bm.bettype,
				bm.hdp1,
				bm.hdp2,
				bm.odds,
				bm.betteam,
				bm.livehomescore,
				bm.liveawayscore,
				bm.liveindicator,
				bm.statusID,
				ISNULL(bm.transdesc, '') AS transdesc
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo AND bm.custid = @CustId
			) AS b
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	IF EXISTS (	SELECT 1
				FROM DBACC.bodb_Archive.dbo.bettransm WITH (NOLOCK)
				WHERE refno = @RefNo )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			b.betcheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyCode AS Currency,
			m.matchid,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS Hdp1,
			CONVERT(FLOAT, b.hdp2) AS Hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.statusID,
			b.transdesc
		FROM (
			SELECT
				bm.transid,
				CASE WHEN bm.betcheck = '' THEN NULL ELSE betcheck END AS betcheck,
				bm.stake,
				bm.matchid,
				bm.bettype,
				bm.hdp1,
				bm.hdp2,
				bm.odds,
				bm.betteam,
				bm.livehomescore,
				bm.liveawayscore,
				bm.liveindicator,
				bm.statusID,
				ISNULL(bm.transdesc, '') AS transdesc
			FROM DBACC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE bm.refno = @RefNo AND bm.custid = @CustId
			) AS b
		INNER JOIN DBACC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
	END

	SELECT *
	FROM @tmpParlay
	ORDER BY TransId DESC
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelParlayDetail] TO [vnteam]