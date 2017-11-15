ALTER PROCEDURE [dbo].[Age_Result_MatchSelNumberGameByLeague]
	@FromDate	DATETIME,
	@LeagueId	INT,
	@Language	NVARCHAR(2)	= 'E',
	@SportType	SMALLINT	= 0,
	@IsShowAll	BIT			= 1		-- 1: Show All; 0: NOT show Test
AS

/*
	Created: 20100908@Jacob
	Task: Get Number Game result by league
	DB: DBAGE.bodb02
	Original: Age_Result_LeagueSelByDate

	Revisions:
		- 20101207@Viet: Change the condition to select never-open-game as well
		- 20101217@Viet: Change the condition back (remove never-open-game) for agentsite to use
		- 20101229@Simon: Show All League or only show Live belong to @isShowAll
		- 20110901@Jamie: Get Refund Result
		- 20151014@Sophia: Show internal match [#45531]
		- 20170525@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171115@Kos: Add new param SportType to separate Lucky 3 and Number Game match [#Redmine: 86655]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	SELECT DISTINCT
		m.betstatus,
		m.leagueid,
		m.matchid,
		m.matchcode,
		m.livehomescore,
		m.liveawayscore,
		m.finalhomescore,
		m.eventdate,
		m.kickofftime,
		m.homeid,
		CASE
			WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
			WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
			WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
			ELSE m.eventstatus
		END AS EventStatus,
		CASE
			WHEN m.betstatus LIKE 'Refund' THEN 1
			ELSE 0
		END AS IsRefund,
		b.Seq,
		b.Number
	FROM (
			SELECT
				betstatus,
				matchid,
				matchcode,
				leagueid,
				eventdate,
				eventstatus,
				kickofftime,
				homeid,
				livehomescore,
				liveawayscore,
				finalhomescore
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
				homeid,
				livehomescore,
				liveawayscore,
				finalhomescore
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
			) AS b ON b.Matchid = m.matchid
		LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
		INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE (m.eventstatus NOT IN ('running')
			OR (m.eventstatus = 'running' AND mr.IsHTCal = 1))
		AND l.isTest = ISNULL(@IsShowAll, l.isTest)
END



GRANT EXECUTE ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_MatchSelNumberGameByLeague] TO [vnteam]
GO
