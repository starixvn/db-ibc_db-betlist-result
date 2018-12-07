/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelNumberGameByLeague]
	@FromDate	DATETIME,
	@LeagueId	INT,
	@IsShowAll	BIT			= 1,	-- 1: Show All; 0: NOT show Test
	@SportType	SMALLINT	= 0
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
		- 20170531@Kos: Prevent data duplication during Move Bet process [Redmine: #77065]
		- 20181207@Kos: Add new param SportType to separate Happy 5 and Number Game match [Redmine: #103698]
					- Remove param @Langkey, @ToDate
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

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
		ISNULL(b.Seq, 0) AS seq,
		ISNULL(b.Number, 0) AS number
	FROM
		(
			SELECT
				betstatus,
				matchid,
				matchcode,
				leagueid,
				eventdate,
				eventstatus,
				kickofftime,
				homeid
			FROM dbo.match WITH (NOLOCK)
			WHERE eventdate = @FromDate
				AND sporttype = @SportType
				AND (@LeagueId = 0 OR leagueid = @LeagueId)
			UNION ALL
			SELECT
				betstatus,
				matchid,
				matchcode,
				leagueid,
				eventdate,
				eventstatus,
				kickofftime,
				homeid
			FROM dbo.match14 WITH (NOLOCK)
			WHERE eventdate = @FromDate
				AND sporttype = @SportType
				AND (@LeagueId = 0 OR leagueid = @LeagueId)
		) AS m
		LEFT JOIN (
			SELECT
				Matchid,
				Seq,
				Number
			FROM dbo.bingoball WITH (NOLOCK)
			UNION ALL
			SELECT
				Matchid,
				Seq,
				Number
			FROM dbo.bingoball14 WITH (NOLOCK)
		) AS b ON b.matchid = m.matchid
		LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid  
		INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE
		(m.eventstatus NOT IN ('internal', 'running')
			OR (m.eventstatus = 'running' AND mr.IsHTCal = 1))
		AND l.isTest = ISNULL(@IsShowAll, l.isTest)
END


GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelNumberGameByLeague] TO [bodbLicenseeNet]
GO
