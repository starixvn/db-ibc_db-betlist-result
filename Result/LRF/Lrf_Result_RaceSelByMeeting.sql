USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Result_RaceSelByMeeting]    Script Date: 02/21/2014 00:20:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_Result_RaceSelByMeeting    Script Date: 12/12/2013 3:38:52 AM ******/
/****** Object:  Stored Procedure dbo.Lrf_Result_RaceSelByMeeting    Script Date: 12/10/2013 4:57:39 PM ******/


ALTER PROCEDURE [dbo].[Lrf_Result_RaceSelByMeeting]
	@FromDate	DATETIME,
	@LeagueId	INT			= 0,
	@SportType	SMALLINT	= 151,
	@IsShowAll	BIT			= 1		-- 1: Show All; 0: is NOT show Test
AS

/*
	Created: 20101201@Jacob
	DB: DBEXT.bodb02
	Original: Age_Result_RaceSelByMeeting
	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_RaceSelByMeeting
		- 20110308@Henry: include Greyhound, Harness racing sports (152,153) - add param @sporttype
		- 20110524@Henry: fix Show All/is not show test
		- 20130722@Jim: Support Virtual Horse Racing
		- 20131129@Jim: Support 182 – Virtual Greyhounds, 184 – Virtual Motor Racing
		- 20140506@Hannah: Support 183 - Virtual Speedway, 185 - Virtual Cycling
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data (
		MeetingId	INT,
		EventDate	DATETIME,
		KickOffTime	DATETIME,
		LColor		NVARCHAR(50),
		RaceName	VARCHAR(20),
		Place		INT,
		HorseNo		VARCHAR(20),
		HorseId		INT,
		Odds		MONEY,
		PlaceOdds	MONEY,
		Status		VARCHAR(20),
		IsFavor		VARCHAR(20),
		IsSCR		BIT,
		FOddsStatus	VARCHAR(20),
		SportType	INT
	)

	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

	-- Horse Racing
	IF @SportType IN (151, 152, 153)
	BEGIN
		INSERT INTO #Data
		SELECT
			o.leagueid meetingid,
			o.eventdate,
			o.kickofftime,
			l.lcolor,
			o.groupmatch AS racename,
			CASE WHEN CONVERT(INT,o.placing) = 0 THEN 5 ELSE ISNULL(CONVERT(INT,o.Placing),5) END place,
			o.matchcode horseNo,
			o.teamid Horseid,
			o.odds,
			o.placeodds,
			o.oddsstatus status,
			CONVERT(VARCHAR(20), o.IsFavor),
			o.IsSCR,
			o.FOddsStatus,
			l.sporttype
		FROM 
			(	SELECT
					leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds,
					IsFavor, IsSCR, FOddsStatus
				FROM dbo.outright WITH (NOLOCK)
				WHERE eventdate = @FromDate
				UNION 
				SELECT
					leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds,
					IsFavor, IsSCR, 'completed' FOddsStatus
				FROM dbo.outright14 WITH (NOLOCK)
				WHERE eventdate = @FromDate
				UNION 
				SELECT
					leagueid, teamid, eventdate, kickofftime, groupmatch, matchcode, placing, oddsstatus, odds, placeodds,
					IsFavor, IsSCR, 'completed' FOddsStatus
				FROM DBARC.bodb_Archive.dbo.outright_bk WITH (NOLOCK)
				WHERE eventdate = @FromDate
			 ) o 
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
		WHERE l.sporttype =  @SportType
			AND o.leagueid = CASE WHEN @leagueid = 0 THEN o.leagueid ELSE @leagueid END
			AND (oddsstatus = 'completed' OR FoddsStatus = 'completed')
			AND l.isTest = ISNULL(@isShowAll, l.isTest)
			--AND o.placing<5
			--AND ISNULL( o.placing,0)<>0
		ORDER BY o.leagueid,
			CAST(o.groupmatch AS INT),
			o.placing

		SELECT meetingid,
			racename,
			COUNT(place) rc
		INTO #DataSUM
		FROM #Data
		WHERE place < 5
		GROUP BY meetingid,
			racename

		SELECT
			d.meetingid,
			d.racename,
			temp.results AS TF,
			temp2.results2 AS SCR
		INTO #tmp
		FROm #Data d
			INNER JOIN #DataSum d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
			CROSS APPLY (
				SELECT STUFF (
								(
								SELECT CAST(horseNo AS VARCHAR(10)) +  ','
								FROM #Data d
								WHERE d.meetingid = d2.meetingid
									AND d.racename = d2.racename
									AND d.IsFavor <> '0'
								FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)')
								,1,2,''
								)
				) temp(results)
			CROSS APPLY (
				SELECT STUFF (
								(
								SELECT CAST(horseNo AS VARCHAR(10)) + ',' 
								FROM #Data d
								WHERE d.meetingid = d2.meetingid
									AND d.racename = d2.racename
									AND d.IsSCR <> 0
								FOR XML PATH(''), TYPE).value('.','VARCHAR(MAX)')
								,1,2,''
								)
				) temp2(results2)
		ORDER BY d.meetingid,
			d.racename,
			d.place

		SELECT DISTINCT
			d.*,
			d3.TF,
			d3.SCR,
			d2.rc AS [RowCount]
		FROm #Data AS d
			INNER JOIN #DataSum AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
			INNER JOIN #tmp AS d3 ON d.meetingid = d3.meetingid AND d.racename = d3.racename
		WHERE d.place < 5
		ORDER BY d.meetingid,
			d.racename,
			d.place

		DROP TABLE #DataSum
		DROP TABLE #tmp
	END

	-- Virtual Sports
	IF @SportType IN (181, 182, 183, 184, 185)
	BEGIN
		INSERT INTO #Data
		SELECT
			o.leagueid meetingid,
			o.eventdate,
			o.kickofftime,
			o.lcolor,
			o.groupmatch AS racename,
			CASE WHEN CONVERT(INT,o.placing) = 0 THEN 5 ELSE isnull(CONVERT(INT,placing),5) END place,
			o.matchcode horseNo,
			o.teamid Horseid,
			o.odds,
			o.placeodds,
			o.oddsstatus status,
			o.IsFavor,
			o.IsSCR,
			o.FOddsStatus,
			l.sporttype
		FROM
			(
			SELECT
				vsr.leagueid,
				vso.RacerID teamid,
				vso.Colours lcolor,
				vso.EventDate,
				vsr.EventTime kickofftime,
				NULL groupmatch,
				CONVERT(VARCHAR(20), vso.RacerNum)  matchcode,
				vso.placing,
				vsr.EventStatus oddsstatus,
				vso.Winodds odds,
				vso.PlaceOdds,
				CONVERT(VARCHAR(20),vso.IsFavor) IsFavor,
				NULL IsSCR,
				'' FOddsStatus
			FROM dbo.VSOutright AS vso WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
			WHERE vso.EventDate = @FromDate 
				AND vsr.LeagueID = CASE WHEN @leagueid = 0 THEN leagueid ELSE @leagueid END
				AND vso.Placing < 5
				AND ISNULL(vso.Placing, 0) <> 0
				AND vsr.SportType = @SportType
				AND vsr.EventStatus ='completed'
			UNION ALL
			SELECT
				vsr.leagueid,
				vso14.RacerID teamid,
				vso14.Colours lcolor,
				vso14.EventDate,
				vsr.EventTime kickofftime,
				NULL groupmatch,
				CONVERT(VARCHAR(20),vso14.RacerNum) matchcode,
				vso14.placing,
				vsr.EventStatus  oddsstatus,
				vso14.Winodds odds,
				vso14.PlaceOdds,
				CONVERT(VARCHAR(20),vso14.IsFavor) IsFavor,
				NULL IsSCR,
				'' FOddsStatus
			FROM dbo.VSOutright14 AS vso14 WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso14.EventID = vsr.EventID
			WHERE vso14.EventDate = @FromDate
				AND vsr.LeagueID = CASE WHEN @leagueid = 0 THEN leagueid ELSE @leagueid END
				AND vso14.Placing < 5
				AND ISNULL(vso14.Placing, 0) <> 0
				AND vsr.SportType = @SportType
				AND vsr.EventStatus = 'completed'
			UNION ALL
			SELECT
				vsr.leagueid,
				bk.RacerID teamid,
				'' AS  lcolor,
				bk.EventDate,
				vsr.EventTime kickofftime,
				NULL groupmatch,
				CONVERT(VARCHAR(20),bk.RacerNum) matchcode,
				bk.placing,
				vsr.EventStatus  oddsstatus,
				bk.Winodds odds,
				bk.PlaceOdds,
				CONVERT(VARCHAR(20),bk.IsFavor) IsFavor,
				NULL IsSCR,
				'' FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS bk WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON bk.EventID = vsr.EventID
				WHERE eventdate = @FromDate
					AND leagueid = CASE WHEN @leagueid = 0 THEN leagueid  ELSE @leagueid END 
					AND placing < 5
					AND ISNULL(placing, 0) <> 0
					AND vsr.SportType = @SportType
					AND vsr.EventStatus ='completed'
			 ) o 
			INNER JOIN dbo.HRCode AS c WITH (NOLOCK) ON c.CodeID = o.teamid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.LeagueID = l.leagueid
			--WHERE	c.CodeType=11
			ORDER BY o.leagueid, o.kickofftime

		SELECT KickOffTime,
			COUNT(place) rc
		INTO #DataSUMVHR
		FROM #Data
		GROUP BY kickofftime

		SELECT DISTINCT
			d.meetingid,
			d.eventdate,
			d.kickofftime,
			d.lcolor,
			d.racename,
			d.place,
			d.horseNo,
			d.Horseid,
			CASE d.sporttype * d.place --check whether the sport is Virtual Cycling & get the place
				WHEN 0 THEN 0		-- 0 * 185
				WHEN 370 THEN 0		-- 2 * 185
				WHEN 555 THEN 0		-- 3 * 185
				WHEN 740 THEN 0		-- 4 * 185
				ELSE d.odds
			END AS odds,
			CASE d.sporttype --check whether the sport is Virtual Speedway or not
				WHEN 183 THEN 0
				ELSE d.PlaceOdds
			END AS PlaceOdds,
			d.status,
			d.IsFavor,
			d.IsSCR,
			d.FOddsStatus,
			'' TF,
			'' SCR,
			d2.rc AS [RowCount]
		FROm #Data AS d
			INNER JOIN #DataSumVHR AS d2 ON d.kickofftime = d2.kickofftime
		WHERE (d.place < 5 AND d.sporttype <> 183)
			OR (d.place < 2 AND d.sporttype = 183)
		ORDER BY meetingid,
			kickofftime,
			place
		DROP TABLE #DataSumVHR
	END

	DROP TABLE #Data
 END

 
GO 
 GRANT EXECUTE ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [vnteam]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_Result_RaceSelByMeeting] TO [bodbLicenseeNet]
GO
