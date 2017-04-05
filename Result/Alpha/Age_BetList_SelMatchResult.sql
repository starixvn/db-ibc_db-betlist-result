ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResult]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL,
	@RaceNo		VARCHAR(50)	= NULL
AS

/*
	Created:
	Task: Get Result
	DB: DBAGE.bodb02

	Revisions:
		- 20091104@Jamie: Show the results of FOdds HR
		- 20091130@Terry: Show the SCR info of FOdds HR
		- 20091130@Jamie: Get the HR results history (archive)
		- 20100123@Henry: Grant execute to Accounting site
		- 20100730@Henry: Grant execute to bodbExtAccNet
		- 20110307@Lukas: get more sporttype (152,153) & change column name (horseid -> runnerid)
		- 20110721@Johnson: get more columns for HR
		- 20110825@Johnson: get info horses scratched
		- 20110831@Johnson: correct event status when refund ticket
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status
		- 20111003@Sophia: Add column IsPending Pending Status
		- 20120119@Sophia: Add Showtime for Table - hand - Shoe of Live Casino
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130226@Elodie: Show the results of Virtual HR
		- 20130826@Kathy: change Status column name
		- 20130925@Lukas: revert column alias eventstatus -> status for horse racing product
		- 20131010@Kathy: Turn to use GlobalShowTime for display the Kick-off-Time [redmine:#6076] (exclusive LiveCasino)
		- 20140930@Sophia: Get the detail information of Tennis sport
		- 20140403@Sophia: Support BetRadar
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161031@Kos: Support live score [#Redmine: 66447]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170120@Kos: Support Fast Market, get result detail of bet type 221 in case of 225 [#Redmine: 56589]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@SportType		TINYINT

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
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END AS playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END AS kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
				CASE m.Sporttype
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
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
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
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
								CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceId))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%')
						AND (d.ResourceId NOT IN ('00', '01', '08')
							OR (d.ResourceId = '08'
								AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
						AND d.ResourceId LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
			ORDER BY ResourceId

			RETURN
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
				CASE m.Sporttype
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
				ISNULL(mr.refund,0) AS IsRefund,
				ISNULL(mr.calrefund,0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
			FROM dbo.match14 AS m WITH(NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
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
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
								CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceId))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%')
						AND (d.ResourceId NOT IN ('00', '01', '08')
							OR (d.ResourceId = '08'
								AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
						AND d.ResourceId LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
			ORDER BY ResourceId

			RETURN
		END
		ELSE
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime ,CURRENT_TIMESTAMP) 
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime ,CURRENT_TIMESTAMP) 
				END playtime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
				m.matchcode,
				m.eventdate,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END kickofftime,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
				CASE m.Sporttype
					WHEN 5 THEN
						CASE ISNULL(d.SettlementStatusID,0)
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
						ELSE m.eventstatus END
					END AS eventstatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime 
			FROM DBARC.bodb_archive.dbo.Match_BK AS m WITH(NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- Get sport type
			SELECT @SportType = Sporttype
			FROM DBARC.bodb_archive.dbo.match_bk WITH (NOLOCK)
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
			FROM DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
								CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceId))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%')
						AND (d.ResourceId NOT IN ('00', '01', '08')
							OR (d.ResourceId = '08'
								AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
						AND d.ResourceId LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
			ORDER BY ResourceId
		END
	END
	ELSE
	BEGIN
		DECLARE @LeagueId	INT,
			@EventDate		DATETIME 

		-- Horse Racing
		IF EXISTS (SELECT 1 FROM dbo.outright WITH(NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @MatchId

			SELECT
				o.matchcode AS horseNo,
				CAST(o.groupmatch AS INT) AS racename,
				o.Placing AS place,
				l.sporttype,
				o.teamid AS horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS status,
				o.IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.Outright AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND ( ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.Outright14 WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.Outright14 WITH (NOLOCK)
			WHERE orid = @MatchId

			SELECT
				o.matchcode AS horseNo,
				CAST(o.groupmatch AS INT) AS racename,
				o.Placing AS place,
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS status,
				o.IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.Outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END 
		ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @MatchId

			SELECT
				matchcode AS horseNo,
				CAST(bk.groupmatch AS INT) AS racename,
				placing AS place,
				l.sporttype,
				teamid AS horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus status,
				bk.IsFavor,
				bk.IsSCR,
				bk.FOddsStatus
			FROM DBARC.bodb_Archive.dbo.Outright_bk AS bk WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH(NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @LeagueId
				AND groupmatch = @RaceNo
				AND eventdate = @EventDate
				AND (ISNULL(placing, 0) <> 0 OR isScr = 1)
			ORDER BY placing
		END
		-- Virtual Horse Racing
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus eventstatus,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus eventstatus,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE
		BEGIN
			SELECT
				RacerNum AS horseNo,
				r.EventTime AS racename,
				placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchId AND (ISNULL(placing, 0) <> 0)
			ORDER BY placing
		END
	END
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResult] TO [vnteam]