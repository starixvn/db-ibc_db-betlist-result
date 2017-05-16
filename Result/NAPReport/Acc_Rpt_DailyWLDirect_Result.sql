ALTER PROCEDURE [dbo].[Acc_Rpt_DailyWLDirect_Result]
	@MatchId	INT,
	@BetType	INT,
	@TraderName	NVARCHAR(100) OUTPUT
AS

/*
	Created: Elodie
	Task: Get result in report 2h
	DB: DBACC.bodb02
	Original: Acc_BetList_SelMatchResult

	Revisions:
		- 20141021@Sophia: Get data of ResultDetail (Sporting Solution)
		- 20140414@Sophia: Support Bet Radar
		- 20170123@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70731]
		- 20170209@Kos: Don't support result detail anymore [#Redmine: 70731]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportType TINYINT

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)		-- Bettrans range
	BEGIN
		-- Get match info and result
		SELECT
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
			m.leagueid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
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
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		SELECT @TraderName = c.username
		FROM dbo.Dot_Admin_Assignment_Operator AS o WITH (NOLOCK)
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON o.OperatorID = c.custid
		WHERE o.matchid = @MatchId
			AND @Bettype = CASE
								WHEN bettype IN (1, 5) AND OperatorType = 1 THEN 1
								WHEN bettype = 1 AND OperatorType = 2 THEN 7
								WHEN bettype = 2 AND OperatorType = 1 THEN 3
								WHEN bettype = 2 AND OperatorType = 2 THEN 8
								WHEN bettype = 3 AND OperatorType = 1 THEN 5
								WHEN bettype = 3 AND OperatorType = 2 THEN 15
								WHEN bettype = 4 AND OperatorType = 1 THEN 2
								WHEN bettype = 4 AND OperatorType = 2 THEN 12
							END

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball and Tennis main result only
		SELECT
			MatchID,
			ResourceID,
			HomeValue,
			AwayValue,
			ResultStatusID,
			SettlementStatusID,
			OtherInfo
		FROM dbo.ResultDetail WITH (NOLOCK)
		WHERE MatchID = @MatchId
			AND LEN(ResourceID) = 2
			AND (@SportType = 2
				OR (@SportType = 5 AND SettlementStatusID > 0))
		ORDER BY ResourceID
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)	-- Bettrans14 range
	BEGIN
		-- Get match info and result
		SELECT
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
			m.leagueid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
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
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			m.showtime
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		SELECT @TraderName = c.username
		FROM DBARC.bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS o WITH (NOLOCK)
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON o.OperatorID = c.custid
		WHERE o.matchid = @MatchId
			AND @Bettype = CASE
								WHEN bettype IN (1, 5) AND OperatorType = 1 THEN 1
								WHEN bettype = 1 AND OperatorType = 2 THEN 7
								WHEN bettype = 2 AND OperatorType = 1 THEN 3
								WHEN bettype = 2 AND OperatorType = 2 THEN 8
								WHEN bettype = 3 AND OperatorType = 1 THEN 5
								WHEN bettype = 3 AND OperatorType = 2 THEN 15
								WHEN bettype = 4 AND OperatorType = 1 THEN 2
								WHEN bettype = 4 AND OperatorType = 2 THEN 12
							END

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball and Tennis main result only
		SELECT
			MatchID,
			ResourceID,
			HomeValue,
			AwayValue,
			ResultStatusID,
			SettlementStatusID,
			OtherInfo
		FROM dbo.ResultDetail14 WITH (NOLOCK)
		WHERE MatchID = @MatchId
			AND LEN(ResourceID) = 2
			AND (@SportType = 2
				OR (@SportType = 5 AND SettlementStatusID > 0))
		ORDER BY ResourceID
	END
END

GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_DailyWLDirect_Result] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_DailyWLDirect_Result] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_Rpt_DailyWLDirect_Result] TO [vnteam]