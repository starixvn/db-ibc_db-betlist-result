USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResult]
	@LicenseeId	INT,
	@UserId		INT,
	@MatchId	INT,
	@RaceNo		VARCHAR(50)	= NULL,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL
AS

/*
	Created: Henry@20101210
	Task: Get Result of match
	DB: DBEXT.bodb02

	Revisions: 
		- 20110308@Henry: get more sporttype (152,153)
		- 20110907@Sophia: Add column IsHTCal, calculate for pending result
		- 20110926@Henry: Add column kickofftime,IsPending , add more columns for HR
		- 20120817@Henry: Add Showtime for Table - hand - Shoe of Live Casino
		- 20120911@Henry: Add homeid2 for Roulettle
		- 20130403@Jim: support base currency USD 
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130722@Jim: support Virtual Horse Racing
		- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
		- 20131129@Jim: support 182 – Virtual Greyhounds, 184 – Virtual Motor Racing
		- 20140428@Hannah: support 183 - Virtual Speedway, 185 - Virtual Cycling
		- 20141021@Jim: support to show Sportting Solution data detail 
		- 20140403@Sophia: Support BetRadar
		- 20160504@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161031@Kos: Support live score [#Redmine: 66447]

		*******************
		sample test case:
			exec Lrf_BetList_SelMatchResult_xtest @MatchID=10514601, @RaceNo=default, @Bettype = 1324,
				@Betid='801', @LicenseeID=1, @UserID=10
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@Sporttype		TINYINT

		SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '' ), 2)

		IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype NOT IN (162, 161) THEN DATEDIFF(MINUTE, GlobalShowTime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, kickofftime, CURRENT_TIMESTAMP)
				END playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype NOT IN (162, 161) THEN m.GlobalShowTime
					ELSE m.kickofftime
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
							WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
							WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
							WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
							ELSE m.eventstatus
						END
				END AS eventstatus,
				ISNULL(mr.refund, 0) IsRefund,
				ISNULL(mr.calrefund, 0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime,'') AS showtime,
				m.homeid2
			FROM dbo.match AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @MatchId

			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE
				d.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
									CASE WHEN @Bettype IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0 END END = LEN(d.ResourceId)
							)
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE F.ResourceID))
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
					WHEN m.sporttype NOT IN (162,161) THEN DATEDIFF(MINUTE, GlobalShowTime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, kickofftime, CURRENT_TIMESTAMP)
				END playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype NOT IN (162, 161) THEN m.GlobalShowTime
					ELSE m.kickofftime
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
							WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
							WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
							WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
							ELSE m.eventstatus
						END 
				END AS eventstatus,
				ISNULL(mr.refund, 0) IsRefund, 
				ISNULL(mr.calrefund, 0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM dbo.match14 AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId

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
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchID = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
									CASE WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4 
										ELSE 0 END END = LEN(d.ResourceId)	)
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE f.ResourceID ))
			ORDER BY ResourceId

			RETURN
		END
		ELSE
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype NOT IN (162, 161) THEN DATEDIFF(MINUTE, GlobalShowTime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, kickofftime, CURRENT_TIMESTAMP)
				END playtime,
				m.LeagueID,
				m.matchid, 
				m.homeID,
				m.awayID,
				m.matchcode,
				m.eventdate,
				CASE
					WHEN m.sporttype NOT IN (162,161) THEN m.GlobalShowTime
					ELSE m.kickofftime
				END kickofftime,
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
							WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
							WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
							WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
							ELSE m.eventstatus
						END
				END AS eventstatus,
				ISNULL(mr.refund, 0) IsRefund,
				ISNULL(mr.calrefund, 0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM DBARC.bodb_archive.dbo.Match_BK AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM DBARC.bodb_archive.dbo.match_BK WITH (NOLOCK)
			WHERE matchid = @MatchId

			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND ((@Sporttype = 5
						AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
								CASE WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4 
								ELSE 0 END END = LEN(d.ResourceId))
					OR 
					(@Sporttype = 1
						AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
						AND d.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId
		END
	END
	ELSE
	BEGIN
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
			FOddsStatus	VARCHAR(10))

		DECLARE @leagueid	INT,
			@eventdate		DATETIME

		IF EXISTS (SELECT 1 FROM dbo.outright WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL,
				CAST(o.groupmatch AS INT)
				AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(placing,5) END place, 
				l.sporttype,
				o.teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				CONVERT(VARCHAR(10), o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @leagueid
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @eventdate
				AND (ISNULL(placing, 0) <> 0 OR isScr = 1)
			ORDER BY placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.Outright14 WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE orid = @MatchId 

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(placing,5) END place,
				l.sporttype,
				o.teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				CONVERT(VARCHAR(10),o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing, 0) <> 0  OR isScr = 1)
			ORDER BY placing
		END
		ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @MatchId 

			INSERT INTO #tmpresult
			SELECT
				matchcode AS horseNo, 
				NULL,
				CAST(bk.groupmatch AS INT) AS racename,
				CASE WHEN placing = 0 THEN 5 ELSE ISNULL(placing,5) END place, 
				l.sporttype, 
				teamid horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus status,
				CONVERT(VARCHAR(10),IsFavor),
				bk.IsSCR,
				bk.FOddsStatus
			FROM DBARC.bodb_Archive.dbo.Outright_bk AS bk WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing, 0)<> 0  OR isScr = 1)
			ORDER BY placing
		END 

		-- Virtual Horse Racing
		IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				placing AS place,
				r.SportType,
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus status,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing, 0) <> 0)
			ORDER BY placing
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				placing AS place,
				r.SportType,
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus status,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing, 0) <> 0)
			ORDER BY placing
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
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus status,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing, 0) <> 0)
			ORDER BY placing
		END

		IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (151, 152, 153))
		BEGIN
			SELECT meetingid,
				racename,
				COUNT(place) rc INTO #DataSUM
			FROM #tmpresult
			WHERE place < 5
			GROUP BY meetingid, racename

			SELECT
				d.meetingid,
				d.racename,
				temp.results AS TF,
				temp2.results2 AS SCR
			INTO #tmp
			FROM #tmpresult AS d
				INNER JOIN #DataSum AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(horseNo AS VARCHAR(10)) + ','
						FROM #tmpresult d
						WHERE d.meetingid = d2.meetingid
							AND d.racename = d2.racename
							AND d.IsFavor <> '0' 
						FOR XML PATH(''), type).value('.','VARCHAR(max)')
						,1,2,''
						)
					)temp(results)
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(horseNo AS VARCHAR(10)) + ',' 
						FROM #tmpresult d
						WHERE d.meetingid = d2.meetingid
							AND  d.racename = d2.racename
							AND d.IsSCR <> 0
						FOR XML PATH(''), type).value('.','VARCHAR(max)')
						,1,2,''
						)
					)temp2(results2)
			ORDER BY d.meetingid,
				d.racename,
				d.place

			SELECT DISTINCT
				d.*,
				d3.TF,
				d3.SCR,
				d2.rc AS [RowCount]
			FROM #tmpresult AS d
				INNER JOIN #DataSum AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				INNER JOIN #tmp AS d3 ON d.meetingid = d3.meetingid AND d.racename = d3.racename
			WHERE d.place < 5
			ORDER BY d.meetingid,
				d.racename,
				d.place

			DROP TABLE #DataSum 
			DROP TABLE #tmp
		END
		ELSE IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (181, 182, 183, 184, 185))
		BEGIN 
			SELECT kickofftime,
				COUNT(place) rc
			INTO #DataSUMVHR
			FROM #tmpresult
			GROUP BY kickofftime

			SELECT
				d.horseNo,
				d.KickoffTime,
				d.racename,
				d.place,
				d.sporttype,
				d.horseid,
				CASE d.sporttype * d.place --check whether the sport is Virtual Cycling & get the place
					WHEN 0 THEN 0   --0*185
					WHEN 370 THEN 0	-- 2* 185
					WHEN 555 THEN 0 -- 3*185
					WHEN 740 THEN 0 -- 4*185
					ELSE d.odds
				END AS odds,
				CASE d.sporttype --check whether the sport is Virtual Speedway or not
					WHEN 183 THEN 0
					ELSE d.PlaceOdds
				END AS PlaceOdds,
				d.meetingid,
				d.oddsstatus,
				d.IsFavor,
				d.IsSCR,
				d.FOddsStatus,
				'' TF,
				'' SCR,
				d2.rc AS [RowCount]
			FROM #tmpresult AS d
				INNER JOIN #DataSumVHR AS d2 ON d.kickofftime = d2.kickofftime 
			WHERE (d.place < 5 AND d.sporttype <> 183)
				OR (d.place < 2 AND d.sporttype = 183)
			ORDER BY meetingid,
				kickofftime,
				place

			DROP TABLE #DataSumVHR
		END
		ELSE
		BEGIN
			SELECT * FROM #tmpresult
		END

		DROP TABLE #tmpresult
	END
END


 
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResult] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResult] TO [vnteam]