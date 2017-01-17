USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelByLeague_Detail]
	@MatchId INT
AS

/*
	Created: 20141021@Jim
	Task: Retrieve result detail of a match
	DB: DBEXT.bodb02
	Original: [Age_Result_MatchSelResultDetail]
	Revisions:
		- 20150407@Sophia: Support to get BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]

	-------
	EXEC Lrf_Result_MatchSelByLeague_Detail_xtest
		@MatchId = 10860032
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype TINYINT

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype NOT IN (162, 161, 180, 186) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END AS KickOffTime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE
					CASE
						WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
						WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
						WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
						WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
						ELSE m.eventstatus
					END
			END AS eventstatus,
			m.showtime,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2, 0) AS homeid2, 
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.MatchId = @MatchId

		SELECT @Sporttype = Sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId
		
		SELECT
			MatchId,
			ResourceId,
			HomeValue,
			AwayValue,
			ResultStatusID,
			SettlementStatusID,
			OtherInfo
		FROM dbo.ResultDetail WITH (NOLOCK)
		WHERE MatchID = @MatchId
			AND SettlementStatusID > 0
			AND ((@Sporttype = 1
					AND ResourceID NOT IN ('00', '01', '08')
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%')
				OR @Sporttype = 5)
		ORDER BY MatchID,
			ResourceID
	END 
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype NOT IN (162, 161, 180, 186) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund' 
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END 
				ELSE
					CASE
						WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
						WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
						WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
						WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
						ELSE m.eventstatus
					END
			END AS eventstatus,
			m.showtime,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.matchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @Sporttype = Sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE MatchId = @MatchId

		SELECT
			MatchId,
			ResourceId,
			HomeValue,
			AwayValue,
			ResultStatusID,
			SettlementStatusID,
			OtherInfo
		FROM dbo.ResultDetail14 WITH (NOLOCK)
		WHERE MatchID = @MatchId
			AND SettlementStatusID > 0
			AND ((@Sporttype = 1
					AND ResourceID NOT IN ('00', '01', '08')
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%')
				OR @Sporttype = 5)
		ORDER BY MatchID,
			ResourceID
	END
END


GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelByLeague_Detail] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_MatchSelByLeague_Detail] TO [vnteam] 