/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_Match3rdSelByLeague]
	@FromDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LeagueId		INT
AS

/*
	Task: Alpha Result Report - Load match list
	DB: DBAGE.bodb02
	Original: Age_Result_Match3rdSelByLeague
	Revisions:
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20240723@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @EventDate DATETIME

	SELECT @EventDate = @FromDate

	CREATE TABLE #Match (
		SportType			SMALLINT,
		BetStatus			NVARCHAR(50),
		League3rdId			INT,
		Match3rdId			INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		HtHomeScore			INT,
		HtAwayScore			INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		HomeId				INT,
		AwayId				INT,
		EventStatus			NVARCHAR(50))

	INSERT INTO #Match
	SELECT
		m.sporttype,
		ISNULL(m.betstatus, ''),
		m.league3rdid,
		m.match3rdid,
		m.MatchCode,
		CASE WHEN m.SportType IN (175) THEN m.endtime ELSE m.StartTime END,
		m.HtHomeScore,
		m.HtAwayScore,
		m.FinalHomeScore,
		m.FinalAwayScore,
		m.HomeId,
		m.AwayId,
		m.eventstatus
	FROM
		dbo.league3rd AS l WITH (NOLOCK)
		INNER JOIN
			( SELECT sporttype, betstatus, match3rdid, league3rdid, MatchCode, endtime, StartTime, HtHomeScore, 
				HtAwayScore, FinalHomeScore, FinalAwayScore, eventstatus, HomeId, AwayId, EventDate
			FROM dbo.match3rd WITH (NOLOCK)
			UNION ALL
			SELECT sporttype, betstatus, match3rdid, league3rdid, MatchCode, endtime, StartTime, HtHomeScore, 
				HtAwayScore, FinalHomeScore, FinalAwayScore, eventstatus, HomeId, AwayId, EventDate
			FROM dbo.match3rd14 WITH (NOLOCK)
			) AS m ON m.league3rdid = l.league3rdid
	WHERE (l.league3rdid = @LeagueId OR @LeagueId = 0)
		AND 1 = CASE 
					WHEN m.SportType IN (175) AND DATEDIFF(DAY, m.endtime, @EventDate) = 0 THEN 1
					WHEN m.SPortType IN (147) AND DATEDIFF(DAY, m.EventDate, @EventDate) = 0 THEN 1
					ELSE 0
				END
		AND 1 = CASE
					WHEN m.SportType IN (147, 175) AND m.EventStatus = 'completed' THEN 1
					WHEN m.SportType = 147 
						AND m.EventStatus IN ('suspend', 'running')
						AND (m.hthomescore IS NOT NULL OR m.htawayscore IS NOT NULL) THEN 1
					ELSE 0
				END

	-- Get data
	SELECT *
	FROM (SELECT DISTINCT * FROM #Match) AS m
	ORDER BY EventDate 

	-- Get result detail
	DECLARE @Detail TABLE (
		Match3rdId				INT,
		GameResult			VARCHAR(50)
	)

	IF @EventDate > @MoveBetsDay
	BEGIN
		INSERT INTO @Detail
		SELECT
			MatchId,
			GameResult
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM #Match)
			AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		INSERT INTO @Detail
		SELECT
			MatchId,
			GameResult
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID IN (SELECT MatchId FROM #Match)
			AND SettlementStatusID > 0
	END

	SELECT * FROM @Detail

	DROP TABLE #Match
END
GO
