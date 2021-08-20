/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

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
		EventDate			DATETIME,
		EventStatus			NVARCHAR(50))

	INSERT INTO #Match
	SELECT
		m.sporttype,
		ISNULL(m.betstatus, ''),
		m.league3rdid,
		m.match3rdid,
		m.endtime,
		m.eventstatus
	FROM
		dbo.league3rd AS l WITH (NOLOCK)
		INNER JOIN
			( SELECT sporttype, betstatus, match3rdid, league3rdid, endtime, eventstatus
			FROM dbo.match3rd WITH (NOLOCK)
			UNION ALL
			SELECT sporttype, betstatus, match3rdid, league3rdid, endtime, eventstatus
			FROM dbo.match3rd14 WITH (NOLOCK)
			) AS m ON m.league3rdid = l.league3rdid
	WHERE (l.league3rdid = @LeagueId OR @LeagueId = 0)
		AND DATEDIFF(DAY, m.endtime, @EventDate) = 0
		AND m.eventstatus IN ('completed')

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
