USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_BetList_SelMatchResult]    Script Date: 10/17/2014 8:31:58 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelMatchResult]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL,
	@RaceNo		VARCHAR(50)	= NULL
AS

/*
	Created:20141017@Bobby
	Task: Get Result Page
	DB: DBEXT.bodb02
	Orgiginal: DBEXT/bodb02.dbo.Age_BetList_SelMatchResult

	Revisions:
		- 20141017@Bobby: Initial SP & Get the detail information of Tennis sport
		- 20141229@Bobby: Add more homeid2 & awayid2 column
		- 20150302@Bobby: Support for showing Virtual Horse Racing bettype
		- 20150415@Bobby: Support for new 60 bettypes betradar
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161027@Kos: Support Fast Market [#Redmine: 56589]
		- 20161031@Kos: Support live score [#Redmine: 66447]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170120@Kos: Get result detail of bet type 221 in case of 225 [#Redmine: 56589]
		- 20170419@Kos: Support Basketball AIO [#Redmine: 73033]
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId VARCHAR(20),
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
				END AS PlayTime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END AS KickOffTime,
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
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.GoalRecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime,
				m.homeid2,
				m.awayid2
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
			WHERE d.MatchID = @MatchId
				AND ((@SportType = 5						-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType NOT IN (1324) THEN 2
								ELSE CASE
										WHEN @BetType IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceId))
					OR (@SportType = 1						-- Soccer
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
					OR (@SportType = 2						-- Basketball
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
				END AS PlayTime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END AS KickOffTime,
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
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.GoalRecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime,
				m.homeid2,
				m.awayid2
			FROM dbo.match14 AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK)
					ON d.MatchID = m.matchid AND d.ResourceId = '00'
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
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5						-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType NOT IN (1324) THEN 2
								ELSE CASE
										WHEN @BetType IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceId))
					OR (@SportType = 1						-- Soccer
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
					OR (@SportType = 2						-- Basketball
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
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END AS PlayTime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
				m.matchcode,
				m.eventdate,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE ISNULL(m.GlobalShowTime, m.kickofftime)
				END AS KickOffTime,
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
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime,
				m.homeid2,
				m.awayid2
			FROM DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
					ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- Get sport type
			SELECT @SportType = sporttype
			FROM DBARC.bodb_Archive.dbo.match_bk WITH(NOLOCK) 
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
			FROM DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5						-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType NOT IN (1324) THEN 2
								ELSE CASE
										WHEN @BetType IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceId))
					OR (@SportType = 1						-- Soccer
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
					OR (@SportType = 2						-- Basketball
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
			@EventDate		DATETIME;

		CREATE TABLE #tmpresult (
			HorseNo		VARCHAR(50),
			KickOffTime	DATETIME,
			RaceName	VARCHAR(50),
			Place		TINYINT,
			SportType	INT,
			HorseId		INT,
			Odds		SMALLMONEY,
			PlaceOdds	SMALLMONEY,
			MeetingId	INT,
			OddsStatus	VARCHAR(10),
			IsFavor		VARCHAR(10),
			IsSCR		BIT,
			FOddsStatus	VARCHAR(10)
		);

		-- Horse Racing
		IF EXISTS (SELECT 1 FROM dbo.outright WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL AS KickoffTime,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(o.Placing, 5) END AS place,
				l.sporttype,
				o.teamid AS horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS [status],
				CONVERT(VARCHAR(10), o.IsFavor) AS IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.outright14 WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL AS KickoffTime,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.Placing = 0 THEN 5 ELSE ISNULL(o.Placing, 5) END AS place,
				l.sporttype,
				o.teamid AS horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS status,
				CONVERT(VARCHAR(10), o.IsFavor) AS IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS( SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate 
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @MatchId
			
			INSERT INTO #tmpresult
			SELECT
				matchcode AS horseNo,
				NULL AS KickoffTime,
				CAST(bk.groupmatch AS INT) AS racename,
				CASE WHEN placing = 0 THEN 5 ELSE ISNULL(placing,5) END AS place,
				l.sporttype,
				teamid horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus [status],
				CONVERT(VARCHAR(10),IsFavor) AS IsFavor,
				bk.IsSCR,
				bk.FOddsStatus
			FROM DBARC.bodb_Archive.dbo.Outright_bk AS bk WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @LeagueId
				AND groupmatch = @RaceNo
				AND eventdate = @EventDate
				AND (ISNULL(placing, 0)<> 0 OR isScr = 1)
			ORDER BY placing
		END

		-- Virtual Horse Racing
		IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus AS Status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus AS status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus AS status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END

		IF EXISTS (SELECT 1 FROM #tmpresult WHERE SportType IN (151, 152, 153))
		BEGIN 
			WITH DataSUM AS (
				SELECT MeetingId,
					RaceName,
					COUNT(Place) AS rc
				FROM #tmpresult
				WHERE Place < 5
				GROUP BY MeetingId,
					RaceName
			), DataTmp AS (
			SELECT d.meetingid,
				d.racename,
				temp.results AS TF,
				temp2.results2 AS SCR
			FROM #tmpresult AS d
				INNER JOIN DataSUM AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(d.HorseNo AS VARCHAR(10)) + ','
						FROM #tmpresult AS d
						WHERE d.MeetingId = d2.meetingid
							AND d.RaceName = d2.racename
							AND d.IsFavor <> '0'
						FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)')
						, 1, 2, '')
					)temp(results)
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(d.HorseNo AS VARCHAR(10)) + ','
						FROM #tmpresult AS d
						WHERE d.MeetingId = d2.meetingid
							AND d.RaceName = d2.racename
							AND d.IsSCR <> 0
						FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)')
						, 1, 2,'')
					)temp2(results2)
			)

			SELECT DISTINCT
				d.*,
				d3.TF,
				d3.SCR,
				d2.rc AS [RowCount]
			FROm #tmpresult AS d
				INNER JOIN DataSum AS d2 ON d.MeetingId = d2.meetingid AND d.RaceName = d2.racename
				INNER JOIN DataTmp AS d3 ON d.MeetingId = d3.meetingid AND d.RaceName = d3.racename
			WHERE d.Place < 5
			ORDER BY d.MeetingId,
				d.RaceName,
				d.Place
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #tmpresult WHERE SportType IN (181, 182, 183, 184, 185))
		BEGIN
			WITH DataSUMVHR AS (
				SELECT KickOffTime,
					COUNT(Place) AS rc
				FROM #tmpresult
				GROUP BY KickOffTime
			)
			SELECT
				d.HorseNo,
				d.KickOffTime,
				d.RaceName,
				d.Place,
				d.SportType,
				d.HorseId,
				CASE d.SportType * d.Place --check whether the sport is Virtual Cycling & get the place
					WHEN 0 THEN 0		-- 0 * 185
					WHEN 370 THEN 0		-- 2 * 185
					WHEN 555 THEN 0		-- 3 * 185
					WHEN 740 THEN 0		-- 4 * 185
					ELSE d.Odds
				END AS odds,
				CASE d.SportType --check whether the sport is Virtual Speedway or not
					WHEN 183 THEN 0
					ELSE d.PlaceOdds
				END AS PlaceOdds,
				d.MeetingId,
				d.OddsStatus,
				d.IsFavor,
				d.IsSCR,
				d.FOddsStatus,
				'' AS TF,
				'' AS SCR,
				d2.rc AS [RowCount]
			FROm #tmpresult AS d
				INNER JOIN DataSUMVHR AS d2 ON d.KickOffTime = d2.kickofftime
			WHERE (d.place < 5 AND d.SportType <> 183) 
				OR (d.place < 2 AND d.SportType = 183)
			ORDER BY d.MeetingId,
				d.KickOffTime,
				d.Place
		END
		ELSE
		BEGIN
			SELECT * FROM #tmpresult
		END

		DROP TABLE #tmpresult
	END
	RETURN;
END


GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResult] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResult] TO [bodbDownlineNet] AS [dbo]
GO
