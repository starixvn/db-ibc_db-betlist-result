USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelNumberGameByLeague]
	@FromDate	DATETIME,
	@ToDate		DATETIME		= NULL,
	@LeagueId	INT,
	@IsShowAll	BIT				= 1,	-- 1: Show All; 0: is NOT show Test
	@Langkey	NVARCHAR(10)	= 'en-US' 
AS

/*
	Created: 20101201@Jacob
	Task: Get Number Game result by league
	DB: DBEXT.bodb02
	Original: Age_Result_MatchSelNumberGameByLeague

	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_MatchSelNumberGameByLeague
		- 20110524@Henry: fix Show All/is not show test
		- 20110927@Henry: retrieve all matches including Refund match
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

	IF @ToDate IS NULL
	BEGIN
		SELECT @ToDate = DATEADD(s, -1, DATEADD(d, 1, @FromDate))
	END

	SELECT DISTINCT
		m.betstatus,
		m.leagueid,
		m.matchid,
		m.matchcode,
		m.eventdate,
		m.kickofftime,
		m.homeid,
		CASE
			WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
			WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
			WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
			ELSE m.eventstatus
		END AS eventstatus,
		CASE
			WHEN m.betstatus LIKE 'Refund' THEN 1
			ELSE 0
		END AS IsRefund,
		ISNULL(b.seq, 0) AS seq,
		ISNULL(b.number, 0) AS number
	FROM
		(
			SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime, homeid
			FROM dbo.match WITH (NOLOCK)
			WHERE eventdate BETWEEN @FromDate AND @ToDate
				AND sporttype = 161
				AND (@LeagueID = 0 OR leagueid = @LeagueID)
			UNION ALL
			SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime, homeid
			FROM dbo.match14 WITH (NOLOCK)
			WHERE eventdate BETWEEN @FromDate AND @ToDate
				AND sporttype = 161
				AND (@LeagueID = 0 OR leagueid = @LeagueID)
		) AS m
		LEFT JOIN (
			SELECT matchid, seq, number
			FROM dbo.bingoball WITH (NOLOCK)
			UNION ALL
			SELECT matchid, seq, number
			FROM dbo.bingoball14 WITH (NOLOCK)
		) AS b ON b.matchid = m.matchid
		LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid  
		INNER JOIN dbo.league WITH (NOLOCK) ON m.leagueid = league.leagueid
	WHERE
		(m.eventstatus NOT IN ('internal','running')
			OR (m.eventstatus = 'running' AND mr.ishtcal = 1))
		AND league.isTest = ISNULL(@isShowAll, league.isTest)
END


GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelNumberGameByLeague] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelNumberGameByLeague] TO [vnteam]
GO
