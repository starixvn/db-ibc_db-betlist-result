/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_Match3rdSelByLeague]
	@LeagueId		INT,
	@Date			DATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20210914@Kos
	Task: LAP/LRF Result Report - Load match 3rd list by league
	DB: DBEXT.bodb02

	Revisions:
		- 20210914@Kos: Support Bitcoin [Redmine: #160160]
		- 20241028@Kos: Support Betby Virtual Sports 6 [Redmine: #212446]
		- 20241216@Kos: Support Virtual Sports 5 [Redmine: #207582]
		- 20251008@Kelvin: Virtual Sports 6 - Betby - Add new eSoccer sport and new bet types [Redmine: #240929]
		- 20251008@Kelvin: Virtual Sports 6 - Betby - Add new E-Volleyball sport and new bet types [Redmine: #241527]
*/

BEGIN
	SET NOCOUNT ON

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

	DECLARE @Detail TABLE (
		Match3rdId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		GameResult			VARCHAR(50),
		SettlementStatusID	TINYINT,
		ResourceId			VARCHAR(20)
	)

	IF @Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Match
		(
			Match3rdId,
			MatchCode,
			League3rdId,
			SportType,
			EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			HtHomeScore,
			HtAwayScore,
			FinalHomeScore,
			FinalAwayScore
		)
		SELECT
			m.Match3rdId,
			m.matchcode,
			m.League3rdId,
			m.SportType,
			CASE
				WHEN m.SportType = 175 THEN m.EndTime
				ELSE m.StartTime
			END AS EventDate,
			ISNULL(m.BetStatus, '') AS BetStatus,
			m.EventStatus,
			m.HomeId,
			m.AwayId,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore
		FROM dbo.Match3rd AS m WITH (NOLOCK)
			LEFT JOIN dbo.ResultDetail3rd AS r WITH (NOLOCK)
				ON r.MatchID = m.Match3rdId
				AND m.SportType IN (114, 116, 134)
				AND r.SettlementStatusID > 0
		WHERE m.League3rdId = @LeagueId
			AND m.EventDate = @Date
			AND 1 = CASE
						WHEN m.EventStatus = 'completed' THEN 1
						WHEN m.SportType IN (114, 116, 134)
							AND m.EventStatus IN ('Running', 'Ended')
							AND ISNULL(r.MatchID, 0) <> 0 THEN 1
						WHEN m.SportType = 147
							AND m.EventStatus IN ('Suspend', 'Running')
							AND (m.hthomescore IS NOT NULL OR m.htawayscore IS NOT NULL) THEN 1
						ELSE 0
					END

		INSERT INTO @Detail
		(
			Match3rdId,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		)
		SELECT
			MatchId,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM @Match)
			AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		INSERT INTO @Match
		(
			Match3rdId,
			MatchCode,
			League3rdId,
			SportType,
			EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			HtHomeScore,
			HtAwayScore,
			FinalHomeScore,
			FinalAwayScore
		)
		SELECT
			m.Match3rdId,
			m.matchcode,
			m.League3rdId,
			m.SportType,
			CASE
				WHEN m.SportType = 175 THEN m.EndTime
				ELSE m.StartTime
			END AS EventDate,
			ISNULL(m.BetStatus, '') AS BetStatus,
			m.EventStatus,
			m.HomeId,
			m.AwayId,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore
		FROM dbo.Match3rd14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.ResultDetail3rd14 AS r WITH (NOLOCK)
				ON r.MatchID = m.Match3rdId
				AND m.SportType IN (114, 116, 134)
				AND r.SettlementStatusID > 0
		WHERE m.League3rdId = @LeagueId
			AND m.EventDate = @Date
			AND 1 = CASE
						WHEN m.EventStatus = 'completed' THEN 1
						WHEN m.SportType IN (114, 116, 134)
								AND m.EventStatus IN ('Running', 'Ended')
								AND ISNULL(r.MatchID, 0) <> 0 THEN 1
						ELSE 0
					END

		INSERT INTO @Detail
		(
			Match3rdId,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		)
		SELECT
			MatchId,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM @Match)
			AND SettlementStatusID > 0
	END

	-- Return result
	SELECT DISTINCT 
			Match3rdId,
			MatchCode,
			League3rdId,
			SportType,
			EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			HtHomeScore,
			HtAwayScore,
			FinalHomeScore,
			FinalAwayScore
	FROM @Match
	ORDER BY EventDate ASC

	SELECT 
		Match3rdId,
		Custom1,
		Custom2,
		GameResult,
		SettlementStatusID,
		ResourceId 
	FROM @Detail
END
GO
