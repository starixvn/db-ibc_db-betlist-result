/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_Parlay_Match3rd]
	@RefNo	BIGINT
AS

/*
	Created: 20240812@Kos
	Task: Get Parlay ticket result of Match3rd
	DB: DBACC.bodb02

	Revisions:
		- 20240812@Kos: Support Virtual Sports 5 [Redmine: #207582]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook and Virtual Sports 2 only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE EventType = 5 AND ProductID <> 69

	DECLARE @Match TABLE (
		Match3rdId		INT,
		MatchCode		NVARCHAR(50),
		League3rdId		INT,
		SportType		SMALLINT,
		EventDate		DATETIME,
		BetStatus		VARCHAR(50),
		EventStatus		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		HtHomeScore		INT,
		HtAwayScore		INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT
	)

	-- Bettrans range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @Match
		SELECT
			m.Match3rdId,
			m.matchcode,
			m.League3rdId,
			m.SportType,
			m.StartTime AS EventDate,
			ISNULL(m.BetStatus, '') AS BetStatus,
			m.EventStatus,
			m.HomeId,
			m.AwayId,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON m.Match3rdId = bm.matchid
		WHERE bm.refno = @RefNo
	END

	-- Bettrans14 range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @Match
		SELECT
			m.Match3rdId,
			m.matchcode,
			m.League3rdId,
			m.SportType,
			m.StartTime AS EventDate,
			ISNULL(m.BetStatus, '') AS BetStatus,
			m.EventStatus,
			m.HomeId,
			m.AwayId,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON m.Match3rdId = bm.matchid
		WHERE bm.refno = @RefNo
			AND NOT EXISTS (SELECT 1 FROM @Match WHERE matchid = bm.matchid )
	END

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @Match
		SELECT
			m.Match3rdId,
			m.matchcode,
			m.League3rdId,
			m.SportType,
			m.StartTime AS EventDate,
			ISNULL(m.BetStatus, '') AS BetStatus,
			m.EventStatus,
			m.HomeId,
			m.AwayId,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN bodb_Archive.dbo.Match3rd_bk AS m WITH (NOLOCK) ON m.Match3rdId = bm.matchid
		WHERE bm.refno = @RefNo
			AND NOT EXISTS (SELECT 1 FROM @Match WHERE matchid = bm.matchid )
	END

	SELECT DISTINCT * FROM @Match
	ORDER BY EventDate ASC
END
GO
