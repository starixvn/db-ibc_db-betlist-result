/*<info serverAlias="DBACC-bodb02" executers="wsv_nap, wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelMatch3rdResultParlay]
	@RefNo	BIGINT
AS

/*
	Created: Razor@07242024
	Task: Select MixParlay for 3rd Table result
	DB: DBACC.bodb02
	Original: Age_BetList_SelMatch3rdResultParlay
	Revisions:
		- 07242024@Razor: Init for VS 5 product (#207589)
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support VS 5)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (88)

	DECLARE @tmpParlay TABLE(
		SportType			INT,
		LeagueId			INT,
		MatchId				INT,
		HomeId				INT,
		AwayId				INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		EventDate			DATETIME,
		BetStatus			VARCHAR(50),
		EventStatus			VARCHAR(15),
		MatchCode			VARCHAR(50)
	)

	-- Bettrans range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.league3rdid,
			m.match3rdid,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			m.StartTime,
			m.betstatus,
			m.eventstatus,
			m.matchcode
		FROM
			dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON bm.matchid = m.match3rdid
		WHERE bm.refno = @RefNo
	END

	-- Bettrans14 range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.league3rdid,
			m.match3rdid,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			m.StartTime,
			m.betstatus,
			m.eventstatus,
			m.matchcode
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.match3rd14 AS m WITH (NOLOCK) ON bm.matchid = m.match3rdid
		WHERE bm.refno = @RefNo
	END

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.league3rdid,
			m.match3rdid,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			m.StartTime,
			m.betstatus,
			m.eventstatus,
			m.matchcode
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN bodb_Archive.dbo.match3rd_bk AS m WITH (NOLOCK) ON bm.matchid = m.match3rdid
		WHERE bm.refno = @RefNo
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY LeagueId ASC,
		EventDate ASC,
		MatchCode ASC
END
GO
