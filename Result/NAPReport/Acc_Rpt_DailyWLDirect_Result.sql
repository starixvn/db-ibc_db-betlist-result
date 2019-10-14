/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_Rpt_DailyWLDirect_Result]
	@MatchId		INT,
	@BetType		INT,
	@LiveIndicator	TINYINT = 2,
	@TraderName		NVARCHAR(100) OUTPUT
AS

/*
	Created: Elodie
	Task: Get result in report 2h
	DB: DBACC.bodb02
	Original: Acc_BetList_SelMatchResult

	Param's Explanation:
		+ @LiveIndicator:
			0: Non-live
			1: Live
			2: All (Live & non-live)

	Revisions:
		- 20141021@Sophia: Get data of ResultDetail (Sporting Solution)
		- 20140414@Sophia: Support Bet Radar
		- 20170123@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70731]
		- 20170209@Kos: Don't support result detail anymore [#Redmine: 70731]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171004@Kos: Use table TradingBettypeMapping instead of hardcode [Redmine: #83679]
		- 20181108@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 104013]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181025@Kos: Support E-Sports 2 [Redmine: #100635]
		- 20191014@Kos: Support new table Trader [Redmine: #120746]
					- Add new param @LiveIndicator
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT

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
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		SELECT TOP(1) @TraderName = c.username
		FROM dbo.Dot_Admin_Assignment_Trader AS t WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON t.TraderID = c.custid
		WHERE t.matchid = @MatchId
			AND t.bettype = @BetType
			AND (@LiveIndicator = 2 OR t.liveindicator = @LiveIndicator)
		ORDER BY
			t.UpdatedTime DESC,
			t.ID DESC

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball, Tennis, E-Sports main result only
		IF @SportType IN (2, 5)
		BEGIN
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
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES WITH (NOLOCK)
			WHERE MatchID = @MatchId AND LEN(ResourceID) = 2
			ORDER BY ResourceID
		END
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
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			0 AS SettlementStatus,
			m.showtime
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		SELECT TOP(1) @TraderName = c.username
		FROM dbo.Dot_Admin_Assignment_Trader AS t WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON t.TraderID = c.custid
		WHERE t.matchid = @MatchId
			AND t.bettype = @BetType
			AND (@LiveIndicator = 2 OR t.liveindicator = @LiveIndicator)
		ORDER BY
			t.UpdatedTime DESC,
			t.ID DESC

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball, Tennis, E-Sports main result only
		IF @SportType IN (2, 5)
		BEGIN
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
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES14 WITH (NOLOCK)
			WHERE MatchID = @MatchId AND LEN(ResourceID) = 2
			ORDER BY ResourceID
		END
	END
END
GO


GRANT EXECUTE ON [dbo].[Acc_Rpt_DailyWLDirect_Result] TO [bodbAdminNet]
GO
