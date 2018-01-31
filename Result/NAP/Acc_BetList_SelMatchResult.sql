ALTER PROCEDURE [dbo].[Acc_BetList_SelMatchResult]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL
AS

/*
	Created:
	Task: Get ticket result
	DB: DBAGE.bodb02
	Original: Age_BetList_SelMatchResult

	Revisions:
		- 20091104@Jamie: Show the results of FOdds HR
		- 20091130@Terry: Show the SCR info of FOdds HR
		- 20091130@Jamie: Get the HR results history (archive)
		- 20100123@Henry: Grant execute to Accounting site
		- 20100730@Henry: Grant execute to bodbExtAccNet
		- 20110307@Lukas: Get more sporttype (152,153) & change column name (horseid -> runnerid)
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status. Edit eventstatus
		- 20111003@Sophia: Add column IsPending Pending Status
		- 20120130@Sopghia: Add Showtime for Table - hand - Shoe of Live Casino
		- 20120921@Elodie: Get kickofftime field
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20130226@Elodie: Show the results of Virtual HR
		- 20140930@Sophia: Get the detail information of Tennis sport
		- 20140414@Sophia: Support Bet Radar
		- 20160504@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161031@Kos: Support live score [#Redmine: 66447]
		- 20170116@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170120@Kos: Get result detail of bet type 221 in case of 225 [#Redmine: 56589]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180201@Kos: Don't support Racing and Virtual Horse Racing anymore [#Redmine: 86086]
					- Remove param @RaceNo
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ResourceId	VARCHAR(20),
		@SportType		SMALLINT

	-- Get result detail of bet type 221 in case of 225
	IF @BetType = 225
		SET @BetType = 221

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS playtime,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
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
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

		-- Get result detail
		SELECT
			d.MatchId,
			d.ResourceId,
			d.HomeValue,
			d.AwayValue,
			d.ResultStatusID,
			d.SettlementStatusID,
			d.OtherInfo
		FROM dbo.ResultDetail AS d WITH (NOLOCK)
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
				ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
		WHERE d.MatchId = @MatchId
			AND ((@SportType = 5
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN @BetType <> 1324 THEN 2
							ELSE
								CASE
									WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (@SportType = 1
					AND (d.SettlementStatusID > 0
						OR d.ResourceID LIKE '221%'
						OR d.ResourceID LIKE '222%'
						OR d.ResourceID LIKE '223%'
						OR d.ResourceID LIKE '224%'
						OR d.ResourceID LIKE '225%')
					AND (d.ResourceID <> '08'
						OR d.HomeValue LIKE '%a%'		-- Return '08' - Goal Sequence only if at least a goal scored
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID)
				OR (@SportType = 2
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + @ResourceId)))))
		ORDER BY d.ResourceID
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS playtime,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
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
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			m.showtime
		FROM dbo.match14 AS m WITH(NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

		-- Get result detail
		SELECT
			d.MatchID,
			d.ResourceID,
			d.HomeValue,
			d.AwayValue,
			d.ResultStatusID,
			d.SettlementStatusID,
			d.OtherInfo
		FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
				ON f.Bettype = @BetType AND d.ResourceID LIKE f.ResourceID
		WHERE d.MatchId = @MatchId
			AND ((@SportType = 5
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN @BetType <> 1324 THEN 2
							ELSE
								CASE
									WHEN @BetType = 1324 AND LEFT(d.ResourceID, 2) = @ResourceId THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceID))
				OR (@SportType = 1
					AND (d.SettlementStatusID > 0
						OR d.ResourceID LIKE '221%'
						OR d.ResourceID LIKE '222%'
						OR d.ResourceID LIKE '223%'
						OR d.ResourceID LIKE '224%'
						OR d.ResourceID LIKE '225%')
					AND (d.ResourceID <> '08'
						OR d.HomeValue LIKE '%a%'		-- Return '08' - Goal Sequence only if at least a goal scored
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceID LIKE f.ResourceID)
				OR (@SportType = 2
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + @ResourceId)))))
		ORDER BY d.ResourceID
	END
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) playtime,
			m.LeagueID,
			m.matchid,
			m.homeID,
			m.awayID,
			m.matchcode,
			m.kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
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
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			m.showtime
		FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
			LEFT OUTER JOIN DBARC.bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_bk AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		SELECT @SportType = Sporttype
		FROM DBARC.bodb_archive.dbo.match_BK WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

		SELECT
			d.MatchId,
			d.ResourceId,
			d.HomeValue,
			d.AwayValue,
			d.ResultStatusID,
			d.SettlementStatusID,
			d.OtherInfo
		FROM DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
				ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
		WHERE d.MatchId = @MatchId
			AND ((@SportType = 5
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN @BetType <> 1324 THEN 2
							ELSE
								CASE
									WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (@SportType = 1
					AND (d.SettlementStatusID > 0
						OR d.ResourceID LIKE '221%'
						OR d.ResourceID LIKE '222%'
						OR d.ResourceID LIKE '223%'
						OR d.ResourceID LIKE '224%'
						OR d.ResourceID LIKE '225%')
					AND (d.ResourceID <> '08'
						OR d.HomeValue LIKE '%a%'		-- Return '08' - Goal Sequence only if at least a goal scored
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID)
				OR (@SportType = 2
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + @ResourceId)))))
		ORDER BY d.ResourceId
	END
END







GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResult] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResult] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelMatchResult] TO [vnteam]
GO
