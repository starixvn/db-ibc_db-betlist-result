/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_RaceSelByMeeting]
	@FromDate		DATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LeagueId		INT			= 0,
	@SportType		SMALLINT	= 151,
	@IsShowAll		BIT			= 1		-- 1: Show All; 0: is NOT show Test
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
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
					- Add new param @MoveBetsDay SMALLDATETIME
					- Clean unused code
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

	-- Virtual Sports
	IF @SportType IN (181, 182, 183, 184, 185)
	BEGIN
		IF @FromDate > @MoveBetsDay
		BEGIN
			INSERT INTO #Data
			SELECT
				vsr.leagueid meetingid,
				vso.EventDate,
				vsr.EventTime kickofftime,
				vso.Colours lcolor,
				NULL AS racename,
				CASE WHEN CONVERT(INT,vso.placing) = 0 THEN 5 ELSE ISNULL(CONVERT(INT,vso.Placing),5) END place,
				CONVERT(VARCHAR(20), vso.RacerNum) horseNo,
				vso.RacerID Horseid,
				vso.Winodds AS Odds,
				vso.PlaceOdds,
				vsr.EventStatus status,
				vso.IsFavor,
				NULL AS IsSCR,
				'' AS FOddsStatus,
				l.sporttype
			FROM dbo.VSOutright AS vso WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON vsr.leagueid = l.leagueid
			WHERE vso.EventDate = @FromDate
				AND vsr.LeagueID = CASE WHEN @LeagueId = 0 THEN vsr.LeagueID ELSE @LeagueId END
				AND vso.Placing < 5
				AND ISNULL(vso.Placing, 0) <> 0
				AND vsr.SportType = @SportType
				AND vsr.EventStatus = 'completed'
		END
		ELSE
		BEGIN
			INSERT INTO #Data
			SELECT
				vsr.leagueid meetingid,
				vso.EventDate,
				vsr.EventTime kickofftime,
				vso.Colours lcolor,
				NULL AS racename,
				CASE WHEN CONVERT(INT,vso.placing) = 0 THEN 5 ELSE ISNULL(CONVERT(INT,vso.Placing),5) END place,
				CONVERT(VARCHAR(20), vso.RacerNum) horseNo,
				vso.RacerID Horseid,
				vso.Winodds AS Odds,
				vso.PlaceOdds,
				vsr.EventStatus status,
				vso.IsFavor,
				NULL AS IsSCR,
				'' AS FOddsStatus,
				l.sporttype
			FROM dbo.VSOutright14 AS vso WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON vsr.leagueid = l.leagueid
			WHERE vso.EventDate = @FromDate
				AND vsr.LeagueID = CASE WHEN @LeagueId = 0 THEN vsr.LeagueID ELSE @LeagueId END
				AND vso.Placing < 5
				AND ISNULL(vso.Placing, 0) <> 0
				AND vsr.SportType = @SportType
				AND vsr.EventStatus = 'completed'
		END

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
		ORDER BY d.MeetingId ASC,
			d.KickOffTime ASC,
			d.Place ASC

		DROP TABLE #DataSumVHR
	END

	DROP TABLE #Data
END
GO
