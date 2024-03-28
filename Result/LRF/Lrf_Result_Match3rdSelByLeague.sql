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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Match TABLE (
		Match3rdId	INT,
		League3rdId	INT,
		SportType	SMALLINT,
		EventDate	DATETIME,
		BetStatus	VARCHAR(50),
		EventStatus	VARCHAR(50)
	)

	DECLARE @Detail TABLE (
		Match3rdId	INT,
		GameResult	VARCHAR(50)
	)

	IF @Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Match
		SELECT
			m.Match3rdId,
			m.League3rdId,
			m.SportType,
			m.EndTime AS EventDate,
			ISNULL(m.BetStatus, ''),
			m.EventStatus
		FROM dbo.Match3rd AS m WITH (NOLOCK)
			INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
		WHERE (l.League3rdId = @LeagueId OR @LeagueId = 0)
			AND m.EventDate = @Date
			AND m.EventStatus IN ('completed')

		INSERT INTO @Detail
		SELECT
			MatchId,
			GameResult
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM @Match)
			AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		INSERT INTO @Match
		SELECT
			m.Match3rdId,
			m.League3rdId,
			m.SportType,
			m.EndTime AS EventDate,
			ISNULL(m.BetStatus, ''),
			m.EventStatus
		FROM dbo.Match3rd14 AS m WITH (NOLOCK)
			INNER JOIN dbo.League3rd AS l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
		WHERE (l.League3rdId = @LeagueId OR @LeagueId = 0)
			AND m.EventDate = @Date
			AND m.EventStatus IN ('completed')

		INSERT INTO @Detail
		SELECT
			MatchId,
			GameResult
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM @Match)
			AND SettlementStatusID > 0
	END

	-- Return result
	SELECT *
	FROM (SELECT DISTINCT * FROM @Match) AS m
	ORDER BY EventDate

	SELECT * FROM @Detail
END
GO
