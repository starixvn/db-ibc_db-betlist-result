ALTER PROCEDURE [dbo].[Age_Result_MatchSelResultDetail]
	@MatchId INT
AS

/*
	Created: 20141016@Sophia
	Task: Get ResultDetail of a match
	DB: DBAGE.bodb02
	Revisions:
		- 20141218@Sophia: Not to use Betstatus to get REFUND status of Tennis anymore
		- 20150324@Sophia: Support to get BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype TINYINT

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @matchid)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype = 162 THEN m.kickofftime
				ELSE m.GlobalShowTime
			END AS kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.sporttype
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
			END AS EventStatus,
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
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
					AND (ResourceId NOT IN ('00', '01', '08')
						OR (ResourceId = '08'
							AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%')
				OR @Sporttype = 5 )
		ORDER BY MatchID,
			ResourceId
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
				WHEN m.sporttype = 162 THEN m.kickofftime
				ELSE m.globalshowtime
			END AS kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.sporttype
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
			END AS EventStatus,
			m.showtime,
			isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.matchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @Sporttype = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

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
					AND (ResourceId NOT IN ('00', '01', '08')
						OR (ResourceId = '08'
							AND (HomeValue LIKE '%a%' OR HomeValue LIKE '%h%')))
					AND ResourceID NOT LIKE '217%'
					AND ResourceID NOT LIKE '216%'
					AND ResourceID NOT LIKE '221%'
					AND ResourceID NOT LIKE '222%'
					AND ResourceID NOT LIKE '223%'
					AND ResourceID NOT LIKE '224%'
					AND ResourceID NOT LIKE '225%')
				OR @Sporttype = 5)
		ORDER BY MatchID,
			ResourceId
	END
END



GO 
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_MatchSelResultDetail] TO [bodbDownlineNetView] AS [dbo]
GO