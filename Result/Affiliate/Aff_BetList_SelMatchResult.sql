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
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId VARCHAR(20)
			, @Sporttype 	TINYINT

		SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20),@BetId), '8', '' ),2)

		IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END playtime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
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
							WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
							WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
							WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
							ELSE m.eventstatus
						END
				END AS eventstatus,
				ISNULL(mr.refund, 0) IsRefund,
				ISNULL(mr.calrefund, 0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
				,m.homeid2
				,m.awayid2
			FROM dbo.match AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) 
					ON d.MatchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- set sporttype
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
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS F
					ON	F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchID = @MatchId
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
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END playtime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
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
						CASE ISNULL(d.SettlementStatusID,0)
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
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
			ORDER BY m.eventdate
				, m.matchcode
			
			-- set sporttype
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
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE D.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
									CASE WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4 
										ELSE 0 END END = LEN(d.ResourceId))
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE F.ResourceID))
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
					ELSE ISNULL(m.GlobalShowTime, m.kickofftime)
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
							WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
							WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
							WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
							ELSE m.eventstatus
						END
				END AS eventstatus,
				ISNULL(mr.refund,0) IsRefund,
				ISNULL(mr.calrefund,0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal,0) AS IsHTCal,
				ISNULL(mr.calculate,0) AS calculate,
				ISNULL(mr.IsPending,0) AS IsPending,
				m.showtime 
				,m.homeid2
				,m.awayid2
			FROM DBARC.bodb_archive.dbo.Match_BK AS m WITH(NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
					ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate
				, m.matchcode

			-- set sporttype
			SELECT @Sporttype = Sporttype
			FROM DBARC.bodb_archive.dbo.Match_BK WITH(NOLOCK) 
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
					OR (@Sporttype = 1
						AND (d.ResourceId NOT IN ('00', '01', '08')
							OR (d.ResourceId = '08'
								AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
						AND d.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId
		END
	END
	ELSE
	BEGIN
		DECLARE @leagueid	INT
			, @eventdate	DATETIME;
			
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

		IF EXISTS (SELECT 1 FROM dbo.outright WITH(NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo, 
				NULL AS KickoffTime,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(placing,5) END AS place, 
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
			WHERE o.leagueid = @leagueid
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate
				AND (ISNULL(placing,0) <> 0 OR isScr = 1)
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
				matchcode AS horseNo, 
				NULL AS KickoffTime,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN placing = 0 THEN 5 ELSE ISNULL(placing,5) END AS place, 
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				CONVERT(VARCHAR(10),IsFavor) AS IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.Outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH(NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing,0) <> 0  OR isScr = 1)
			ORDER BY placing
		END 
		ELSE IF EXISTS( SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
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
			WHERE bk.leagueid = @leagueid
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate
				AND (ISNULL(placing, 0)<> 0 OR isScr = 1)
			ORDER BY placing
		END
		-------------------Start Virtual Horse Racing -----------------------------------
		IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			-- Virtual HR
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
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			-- Virtual HR 
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
			WHERE o.EventID = @MatchID AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
		END
		ELSE
		BEGIN
			-- Virtual HR 
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
			WHERE o.EventID = @MatchID AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
		END
		-------------------End Virtual Horse Racing -----------------------------------
		IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (151, 152, 153))
		BEGIN 
			WITH DataSUM AS (
				SELECT meetingid
					,racename
					,COUNT(place) rc 
				FROM #tmpresult
				WHERE place < 5
				GROUP BY meetingid
					,racename
			), DataTmp AS (
			SELECT d.meetingid
				,d.racename
				,temp.results AS TF
				,temp2.results2 AS SCR
				FROM #tmpresult d
					INNER JOIN DataSUM d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
					CROSS APPLY (
						SELECT STUFF (
							(
							SELECT CAST(horseNo AS VARCHAR(10)) + ',' 
							FROM #tmpresult d
							WHERE d.meetingid = d2.meetingid
								AND  d.racename = d2.racename
								AND d.IsFavor <> '0'
							for xml path(''), type).value('.','VARCHAR(MAX)')
							, 1, 2, '')
						)temp(results)
					CROSS APPLY (
						SELECT STUFF (
							(
							SELECT CAST(horseNo AS VARCHAR(10))+ ',' 
							FROM #tmpresult d
							WHERE d.meetingid = d2.meetingid
								AND d.racename = d2.racename
								AND d.IsSCR <> 0
							for xml path(''), type).value('.','VARCHAR(MAX)')
							, 1, 2,'')
						)temp2(results2)
			)

			SELECT DISTINCT
				d.*
				,d3.TF
				,d3.SCR
				,d2.rc AS [RowCount]
			FROm #tmpresult d
				INNER JOIN DataSum d2
					ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				INNER JOIN DataTmp d3 
					ON d.meetingid = d3.meetingid AND d.racename = d3.racename
			WHERE d.place < 5
			ORDER BY d.meetingid
				,d.racename
				,d.place
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #tmpresult WHERE sporttype IN (181, 182, 183, 184, 185))
		BEGIN 
			WITH DataSUMVHR AS (
				SELECT kickofftime
					, COUNT(place) rc 
				FROM #tmpresult
				GROUP BY  kickofftime
			)
			SELECT
				d.horseNo,
				d.KickOffTime,
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
				d.oddsstatus
				,d.IsFavor
				,d.IsSCR
				,d.FOddsStatus
				,'' TF
				,'' SCR
				, d2.rc AS [RowCount]
			FROm #tmpresult AS d
				INNER JOIN DataSUMVHR AS d2 ON d.kickofftime = d2.kickofftime 
			WHERE (d.place < 5 AND d.sporttype <> 183) 
				OR (d.place < 2 AND d.sporttype = 183)
			ORDER BY meetingid
				, kickofftime
				, place
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
